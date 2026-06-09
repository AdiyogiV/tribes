#!/usr/bin/env python3
"""
Aurogram PMF Dashboard generator.
Reads the analysis CSVs and emits a single self-contained dashboard.html
(Chart.js + Tailwind via CDN). Cosmic / astrology theme.

Usage: python3 build_dashboard.py
"""
import csv
import json
import os
import re
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))


def read_csv(path):
    p = os.path.join(HERE, path)
    if not os.path.exists(p):
        return []
    with open(p, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(v, d=0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def i(v, d=0):
    return int(num(v, d))


# ------------------------------------------------------------------ load
users = read_csv("user_research/summary.json") and None  # noop guard
research = json.load(open(os.path.join(HERE, "user_research/summary.json")))
engagement = json.load(open(os.path.join(HERE, "engagement/summary.json")))
pmf = json.load(open(os.path.join(HERE, "summary.json")))

eng_rows = read_csv("engagement/real_users_engagement.csv")
daily = read_csv("holycow_daily.csv")
messages = read_csv("holycow_messages.csv")
lb_followers = read_csv("engagement/leaderboard_followers.csv")
lb_engagement = read_csv("engagement/leaderboard_engagement.csv")
lb_creators = read_csv("engagement/leaderboard_creators.csv")
lb_ai = read_csv("engagement/leaderboard_ai_users.csv")
lb_callers = read_csv("engagement/leaderboard_callers.csv")

# ------------------------------------------------------------- categorize
THEMES = [
    ("Career & Work", [
        "career", "job", " jab", "naukri", "promotion", "business", "work",
        "profession", "salary", "interview", "office", "kaam", "kaaj",
    ]),
    ("Marriage & Love", [
        "marriage", "shaadi", "shadi", "vivah", "spouse", "husband", "wife",
        "partner", "relationship", "kundli", "milan", "match", "pati ",
        "divorce", "girlfriend", "boyfriend", "love", "rishta",
    ]),
    ("Children & Family", [
        "bete", "beti", "son", "daughter", "child", "kids", "baby", "pregnan",
        "family", "parents", "mother", "father", "maa ", "pita",
    ]),
    ("Health & Wellbeing", [
        "health", "accident", "injury", "illness", "disease", "bimari",
        "sehat", "body", "pain", "operation", "surgery", "hospital",
    ]),
    ("Money & Wealth", [
        "money", "wealth", "paisa", "dhan", "finance", "property", "loan",
        "debt", "rich", "income", "invest",
    ]),
    ("Astrology Concepts", [
        "yog", "dasha", "mahadasha", "graha", "planet", "horoscope", "rashi",
        "zodiac", "mangal", "shani", "saturn", "ketu", "rahu", "remedy",
        "upay", "puja", "mantra", "sade sati", "nakshatra", "amala",
    ]),
    ("Travel & Lifestyle", [
        "travel", "trip", "ghoom", "eat", "food", "cook", "restaurant",
        "cafe", "place", "visit", "vacation", "manali", "delhi",
    ]),
]
TIMING = ["kab", "when", "date", "future", "today", "aaj", "next month",
          "next", "samay", "kab tak"]
GREET = ["hi", "hello", "ok", "okay", "yes", "no", "more", "namaste", "thanks",
         "thank you", "haan", "ji", "aur", "now"]


def classify(text):
    t = (text or "").lower().strip()
    if not t or t == " voice message" or "voice message" in t:
        return None  # skip voice placeholders
    for name, kws in THEMES:
        if any(k in t for k in kws):
            return name
    if any(t == g or t.startswith(g + " ") for g in GREET) or len(t) <= 3:
        return "Greetings & Follow-ups"
    if any(k in t for k in TIMING):
        return "Timing & Predictions"
    return "Other / General"


theme_counts = Counter()
typed = 0
for m in messages:
    if i(m.get("is_voice")):
        continue
    c = classify(m.get("content"))
    if c:
        theme_counts[c] += 1
        typed += 1

# order themes by count; exclude non-actionable buckets from the viz
_HIDE = {"Other / General", "Greetings & Follow-ups"}
theme_sorted = [(k, v) for k, v in theme_counts.most_common() if k not in _HIDE]

# ------------------------------------------------------------- daily series
daily_sorted = sorted(daily, key=lambda r: r["day"])
# keep last ~120 days of activity for readability
daily_recent = daily_sorted[-120:]
daily_labels = [r["day"] for r in daily_recent]
daily_msgs = [i(r["user_msgs"]) for r in daily_recent]
daily_users = [i(r["active_users"]) for r in daily_recent]

# monthly aggregation
monthly = defaultdict(lambda: {"msgs": 0, "users": set()})
for r in daily_sorted:
    mo = r["day"][:7]
    monthly[mo]["msgs"] += i(r["user_msgs"])
    monthly[mo]["users"].add(r["day"])  # placeholder; active users per day
mo_labels = sorted(monthly.keys())
mo_msgs = [monthly[m]["msgs"] for m in mo_labels]

# voice vs text overall
voice_msgs = i(pmf["holycow"]["voiceMessages"])
total_msgs = i(pmf["holycow"]["aiUserMessages"])
text_msgs = max(total_msgs - voice_msgs, 0)

# activity segments
act = research["realUserActivity"]
seg_labels = ["Active 7d", "Active 8-30d", "Dormant >30d", "Never returned"]
active7 = i(act["active_last_7d"])
active30 = i(act["active_last_30d"])
seg_vals = [active7, max(active30 - active7, 0),
            i(act["dormant_over_30d"]),
            i(act["one_and_done_neverReturned"])]

# activation funnel
acn = research["realUserActivation"]
funnel_labels = ["Real users", "Profile complete", "Has astrology",
                 "Has ayurveda", "FTUE completed"]
funnel_vals = [i(research["classification"]["realUsers"]),
               i(acn["profileComplete"]), i(acn["hasAstrologyData"]),
               i(acn["hasAyurvedaData"]), i(acn["ftueCompleted"])]

# population ladder
pop = research["populationStory"]
ladder = [
    ("Ever registered", i(pop["everRegistered_phoneIndex"])),
    ("Loginable (Auth)", i(pop["currentlyLoginable_auth"])),
    ("Real users", i(research["classification"]["realUsers"])),
    ("Active (30d)", active30),
    ("Active (7d)", active7),
]


def table(rows, cols, headers, limit=12):
    out = ["<table class='w-full text-sm'><thead><tr class='text-left text-violet-300/70 border-b border-white/10'>"]
    for h in headers:
        out.append(f"<th class='py-2 pr-3 font-medium'>{h}</th>")
    out.append("</tr></thead><tbody>")
    for r in rows[:limit]:
        out.append("<tr class='border-b border-white/5 hover:bg-white/5'>")
        for c in cols:
            v = r.get(c, "")
            out.append(f"<td class='py-2 pr-3'>{v if v != '' else '—'}</td>")
        out.append("</tr>")
    out.append("</tbody></table>")
    return "".join(out)


lb_followers_tbl = table(lb_followers, ["name", "followers", "following", "total_engagement"],
                         ["Name", "Followers", "Following", "Eng. score"])
lb_creators_tbl = table(lb_creators, ["name", "posts_total", "posts_original", "replies_received"],
                        ["Name", "Posts", "Original", "Replies recv"])
lb_ai_tbl = table(lb_ai, ["name", "ai_convos", "ai_last_activity_days", "has_astro", "aura_score"],
                  ["Name", "AI convos", "Last seen (d)", "Astro", "Aura"])
lb_callers_tbl = table(lb_callers, ["name", "calls_made", "calls_answered", "talk_time_sec"],
                       ["Name", "Calls made", "Answered", "Talk sec"])

# spotlight user
dossier = json.load(open(os.path.join(HERE, "dossiers/w1kggZXNjTWEM7xdrzU0wVBLJUC2.json")))

KPIS = [
    ("Ever registered", i(pop["everRegistered_phoneIndex"]), "phone numbers seen"),
    ("Real users", i(research["classification"]["realUsers"]), "non-test, non-bot"),
    ("Active (30d)", active30, f"{act['pct_active_30d']}% of real"),
    ("Active (7d)", active7, "weekly actives"),
    ("Never returned", i(act["one_and_done_neverReturned"]), f"{act['pct_one_and_done']}% one-and-done"),
    ("AI conversations", i(pmf["holycow"]["aiConversations"]), "vs 131 human DMs"),
    ("AI messages", total_msgs, f"{voice_msgs} voice"),
    ("Avg msgs / active user", pmf["holycow"]["avgMsgsPerActiveUser"], "depth among adopters"),
]

DATA = dict(
    kpis=KPIS, ladder=ladder,
    seg_labels=seg_labels, seg_vals=seg_vals,
    funnel_labels=funnel_labels, funnel_vals=funnel_vals,
    daily_labels=daily_labels, daily_msgs=daily_msgs, daily_users=daily_users,
    mo_labels=mo_labels, mo_msgs=mo_msgs,
    theme_labels=[t[0] for t in theme_sorted], theme_vals=[t[1] for t in theme_sorted],
    voice=voice_msgs, text=text_msgs,
)

# ------------------------------------------------------------------ render
def render():
    j = json.dumps
    kpi_cards = "".join(
        f"""<div class="rounded-2xl bg-white/5 backdrop-blur border border-white/10 p-5">
          <div class="text-3xl font-bold text-white">{v:,}</div>
          <div class="mt-1 text-sm font-medium text-violet-200">{k}</div>
          <div class="text-xs text-violet-300/60">{sub}</div></div>"""
        if isinstance(v, int) else
        f"""<div class="rounded-2xl bg-white/5 backdrop-blur border border-white/10 p-5">
          <div class="text-3xl font-bold text-white">{v}</div>
          <div class="mt-1 text-sm font-medium text-violet-200">{k}</div>
          <div class="text-xs text-violet-300/60">{sub}</div></div>"""
        for k, v, sub in KPIS)

    spotlight_q = "".join(
        f"<li class='py-1 border-b border-white/5'>{q['q'][:120]}</li>"
        for q in [x for x in dossier['questions'] if not x['voice'] and x['q'].strip()][:14])

    return TEMPLATE.format(
        kpi_cards=kpi_cards,
        data=j(DATA),
        lb_followers=lb_followers_tbl,
        lb_creators=lb_creators_tbl,
        lb_ai=lb_ai_tbl,
        lb_callers=lb_callers_tbl,
        spotlight_q=spotlight_q,
        spotlight_phone=dossier["auth"]["phone"],
        spotlight_created=dossier["auth"]["created"],
        spotlight_last=dossier["auth"]["lastSignIn"],
        ai_convos=dossier["aiConversations"],
        total_q=len([x for x in dossier["questions"]]),
    )


TEMPLATE = r"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aurogram — PMF Intelligence Dashboard</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
  body{{background:radial-gradient(1200px 600px at 20% -10%,#3b1d6e33,transparent),
        radial-gradient(1000px 500px at 90% 10%,#1d4e6e33,transparent),#0b0b15;}}
  .glow{{text-shadow:0 0 24px #a78bfa66;}}
  .card{{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);
         border-radius:1rem;padding:1.25rem;}}
  .chartbox{{position:relative;height:300px;}}
  .chartbox-sm{{position:relative;height:240px;}}
</style></head>
<body class="text-violet-100 font-sans">
<div class="max-w-7xl mx-auto px-5 py-8">

  <header class="mb-8">
    <div class="text-violet-300/70 text-sm tracking-widest uppercase">Aurogram · HolyCow Analytics</div>
    <h1 class="text-4xl md:text-5xl font-extrabold text-white glow">PMF Intelligence Dashboard</h1>
    <p class="mt-2 text-violet-300/70 max-w-3xl">A full read of every user, their engagement, and what they
       actually ask the AI astrologer. Read-only snapshot from Firestore.</p>
  </header>

  <!-- Executive insights TOP -->
  <section class="card mb-8 border-amber-300/20 bg-amber-300/5">
    <h2 class="text-lg font-bold text-amber-200 mb-2">Executive Summary</h2>
    <ul class="grid md:grid-cols-2 gap-x-8 gap-y-1 text-sm text-violet-100/90 list-disc pl-5">
      <li><b>HolyCow IS the product</b> — ~85% of all conversations are with the AI, not other humans.</li>
      <li><b>Retention is the wound</b> — ~78% of real users never returned after day one; only a handful are weekly-active.</li>
      <li><b>The hook works, the habit doesn't</b> — adopters who stayed average ~51 messages each; most never start.</li>
      <li><b>Voice-first</b> — ~41% of all AI messages are voice notes; this is a spoken product.</li>
      <li><b>Top intents:</b> Career, Marriage/Kundli, Children, Health/transits, Timing ("kab?").</li>
      <li><b>Power user persona is real</b> — see spotlight: a Delhi woman, 100+ days active, asking about son's
          marriage, promotion, sade sati, even an accident.</li>
    </ul>
  </section>

  <!-- KPIs -->
  <section class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">{kpi_cards}</section>

  <!-- charts row 1 -->
  <section class="grid lg:grid-cols-2 gap-6 mb-6">
    <div class="card"><h3 class="font-semibold text-white mb-2">User funnel: registered → active</h3>
      <div class="chartbox"><canvas id="ladder"></canvas></div></div>
    <div class="card"><h3 class="font-semibold text-white mb-2">Activity segments (real users)</h3>
      <div class="chartbox"><canvas id="segments"></canvas></div></div>
  </section>

  <!-- charts row 2 -->
  <section class="grid lg:grid-cols-2 gap-6 mb-6">
    <div class="card"><h3 class="font-semibold text-white mb-2">What people ask HolyCow (themes)</h3>
      <div class="chartbox"><canvas id="themes"></canvas></div></div>
    <div class="card"><h3 class="font-semibold text-white mb-2">Activation funnel</h3>
      <div class="chartbox"><canvas id="funnel"></canvas></div></div>
  </section>

  <!-- charts row 3 -->
  <section class="grid lg:grid-cols-3 gap-6 mb-6">
    <div class="card lg:col-span-2"><h3 class="font-semibold text-white mb-2">Daily HolyCow activity (last 120 active days)</h3>
      <div class="chartbox"><canvas id="daily"></canvas></div></div>
    <div class="card"><h3 class="font-semibold text-white mb-2">Voice vs typed</h3>
      <div class="chartbox-sm"><canvas id="voice"></canvas></div></div>
  </section>

  <!-- monthly -->
  <section class="card mb-8"><h3 class="font-semibold text-white mb-2">Monthly message volume</h3>
    <div class="chartbox"><canvas id="monthly"></canvas></div></section>

  <!-- spotlight -->
  <section class="card mb-8 border-fuchsia-400/20 bg-fuchsia-500/5">
    <h2 class="text-lg font-bold text-fuchsia-200 mb-1">Power-user spotlight · "59029414"</h2>
    <p class="text-sm text-violet-300/70 mb-3">Phone {spotlight_phone} · joined {spotlight_created} ·
       last seen {spotlight_last} · {ai_convos} AI conversations · {total_q} messages</p>
    <div class="grid md:grid-cols-2 gap-6">
      <div class="text-sm text-violet-100/90">
        <p class="mb-2">A real, deeply-engaged Indian woman (Vata prakriti on file, Asia/Kolkata).
        Over 100+ active days she treats HolyCow like a personal jyotish — career, her son's marriage,
        astrological transits, and life events. <b>This is the ideal customer profile.</b></p>
        <p class="text-violet-300/70">If we can make 50 more of her, the retention problem is solved.</p>
      </div>
      <div><div class="text-violet-300/70 text-xs uppercase mb-1">Sample real questions</div>
        <ul class="text-sm text-violet-100/90">{spotlight_q}</ul></div>
    </div>
  </section>

  <!-- leaderboards -->
  <section class="grid lg:grid-cols-2 gap-6 mb-6">
    <div class="card"><h3 class="font-semibold text-white mb-3">Top by followers</h3>{lb_followers}</div>
    <div class="card"><h3 class="font-semibold text-white mb-3">Top content creators</h3>{lb_creators}</div>
  </section>
  <section class="grid lg:grid-cols-2 gap-6 mb-8">
    <div class="card"><h3 class="font-semibold text-white mb-3">Top AI users</h3>{lb_ai}</div>
    <div class="card"><h3 class="font-semibold text-white mb-3">Top callers (Agora)</h3>{lb_callers}</div>
  </section>

  <!-- Executive insights BOTTOM -->
  <section class="card mb-10 border-emerald-300/20 bg-emerald-300/5">
    <h2 class="text-lg font-bold text-emerald-200 mb-2">So what should we do?</h2>
    <ol class="space-y-1 text-sm text-violet-100/90 list-decimal pl-5">
      <li><b>Fix the day-2 return.</b> 78% never come back. Ship a daily proactive insight push (60% have push enabled).</li>
      <li><b>Lean into voice.</b> 41% of messages are voice — make voice the primary input, not a side feature.</li>
      <li><b>Answer the top intents brilliantly:</b> career timing, marriage/kundli matching, child/family events, health transits.</li>
      <li><b>Kill or hide the dead social layer.</b> Follow graph is flat (max ~3 followers ex-founder); reposts ~0.</li>
      <li><b>Find more "59029414"s.</b> Middle-aged Indian users asking real life questions in Hindi+English are the core.</li>
      <li><b>Repair onboarding.</b> Only 22% finish FTUE though 85% set a profile — the flow leaks mid-way.</li>
    </ol>
  </section>

  <footer class="text-center text-violet-400/40 text-xs pb-8">
    Generated from Firestore snapshot · Aurogram (ty-dev-516d7) · read-only analysis
  </footer>
</div>

<script>
const D = {data};
const grid = {{color:'rgba(255,255,255,.06)'}}, tick = {{color:'#c4b5fd99'}};
const baseOpts = {{responsive:true,maintainAspectRatio:false,
  plugins:{{legend:{{labels:{{color:'#ddd6fe'}}}}}},
  scales:{{x:{{grid,ticks:tick}},y:{{grid,ticks:tick,beginAtZero:true}}}}}};
const PUR='#a78bfa', FUS='#e879f9', CYA='#22d3ee', AMB='#fbbf24', EMR='#34d399', RED='#fb7185';
const PALETTE=[PUR,FUS,CYA,AMB,EMR,RED,'#60a5fa','#f472b6','#a3e635'];

new Chart(ladder,{{type:'bar',data:{{labels:D.ladder.map(x=>x[0]),
  datasets:[{{label:'users',data:D.ladder.map(x=>x[1]),backgroundColor:PUR,borderRadius:6}}]}},
  options:{{...baseOpts,indexAxis:'y',plugins:{{legend:{{display:false}}}}}}}});

new Chart(segments,{{type:'doughnut',data:{{labels:D.seg_labels,
  datasets:[{{data:D.seg_vals,backgroundColor:[EMR,CYA,AMB,RED]}}]}},
  options:{{responsive:true,maintainAspectRatio:false,
    plugins:{{legend:{{position:'right',labels:{{color:'#ddd6fe'}}}}}}}}}});

new Chart(themes,{{type:'bar',data:{{labels:D.theme_labels,
  datasets:[{{label:'questions',data:D.theme_vals,backgroundColor:FUS,borderRadius:6}}]}},
  options:{{...baseOpts,indexAxis:'y',plugins:{{legend:{{display:false}}}}}}}});

new Chart(funnel,{{type:'bar',data:{{labels:D.funnel_labels,
  datasets:[{{label:'users',data:D.funnel_vals,backgroundColor:CYA,borderRadius:6}}]}},
  options:{{...baseOpts,plugins:{{legend:{{display:false}}}}}}}});

new Chart(daily,{{type:'line',data:{{labels:D.daily_labels,
  datasets:[
    {{label:'messages',data:D.daily_msgs,borderColor:PUR,backgroundColor:'#a78bfa22',fill:true,tension:.3,pointRadius:0}},
    {{label:'active users',data:D.daily_users,borderColor:AMB,tension:.3,pointRadius:0,yAxisID:'y1'}}
  ]}},
  options:{{...baseOpts,scales:{{x:{{grid,ticks:{{...tick,maxTicksLimit:10}}}},
    y:{{grid,ticks:tick,beginAtZero:true}},
    y1:{{position:'right',grid:{{drawOnChartArea:false}},ticks:tick,beginAtZero:true}}}}}}}});

new Chart(voice,{{type:'doughnut',data:{{labels:['Voice','Typed'],
  datasets:[{{data:[D.voice,D.text],backgroundColor:[FUS,CYA]}}]}},
  options:{{responsive:true,maintainAspectRatio:false,
    plugins:{{legend:{{position:'bottom',labels:{{color:'#ddd6fe'}}}}}}}}}});

new Chart(monthly,{{type:'bar',data:{{labels:D.mo_labels,
  datasets:[{{label:'messages',data:D.mo_msgs,backgroundColor:EMR,borderRadius:6}}]}},
  options:{{...baseOpts,plugins:{{legend:{{display:false}}}}}}}});
</script>
</body></html>"""


if __name__ == "__main__":
    html = render()
    out = os.path.join(HERE, "dashboard.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    print("wrote", out, f"({len(html)} bytes)")
    print("themes:", theme_sorted)
    print("typed classified:", typed)
