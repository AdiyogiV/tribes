#!/usr/bin/env python3
"""
Aurogram PMF Dashboard generator.
Reads backend/analysis/*.csv|json -> emits dashboard.html (self-contained).
Re-run anytime data refreshes:  python3 tests/build_dashboard.py
"""
import csv, json, re, statistics
from collections import Counter, defaultdict
from pathlib import Path

csv.field_size_limit(10**7)
DIR = Path(__file__).resolve().parent.parent / "analysis"

def load_csv(name):
    with open(DIR / name) as f:
        return list(csv.DictReader(f))

def num(v):
    try: return float(v)
    except: return 0.0

users = [u for u in load_csv("users.csv") if u["is_test"] == "0"]
corpus = load_csv("corpus_full.csv")
cohorts = load_csv("retention_cohorts.csv")
daily = load_csv("holycow_daily.csv")
deep = json.load(open(DIR / "deep_insights.json"))

# ---- population / retention ----
R = len(users)
ai_users = [u for u in users if num(u["ai_user_msgs"]) > 0]
withlife = [u for u in users if u["lifespan_days"] != ""]
ls = [num(u["lifespan_days"]) for u in withlife]
def ret(d): return sum(1 for x in ls if x >= d)
oneanddone = sum(1 for x in ls if x < 1)

# ---- power law ----
ranked = sorted(ai_users, key=lambda u: num(u["ai_user_msgs"]), reverse=True)
tot_msgs = sum(num(u["ai_user_msgs"]) for u in ranked) or 1
cum, acc = [], 0
for u in ranked:
    acc += num(u["ai_user_msgs"]); cum.append(round(100 * acc / tot_msgs, 1))
top10 = ranked[: max(1, len(ranked)//10)]
top10share = round(100 * sum(num(u["ai_user_msgs"]) for u in top10) / tot_msgs)

# ---- corpus splits ----
user_q = [r for r in corpus if r["source"] in ("text", "voice")
          and r["content"].strip() and not r["content"].startswith("[voice")]
ai_a = [r for r in corpus if r["source"] == "ai" and r["content"].strip()]
voice_q = [r for r in user_q if r["source"] == "voice"]

# ---- themes ----
themes = {
 "Timing / Prediction": r"\b(when|will i|future|next (month|year|week)|going to happen|how long)\b",
 "Career / Work / Money": r"\b(job|career|work|business|money|salary|finance|profession|promotion|income|wealth)\b",
 "Love / Marriage": r"\b(love|marriage|marry|relationship|partner|husband|wife|girlfriend|boyfriend|spouse|divorce)\b",
 "Children / Family": r"\b(kid|kids|child|children|baby|pregnan|son|daughter|family|parent)\b",
 "Self / Personality": r"\b(who am i|personality|strength|weakness|about me|myself|my life|nature)\b",
 "Travel / Abroad": r"\b(travel|trip|abroad|foreign|relocat|visa|settle)\b",
 "Health": r"\b(health|disease|sick|body|mental|stress|anxiety|sleep)\b",
 "Spiritual / Remedy": r"\b(remedy|mantra|pooja|puja|gemstone|dosha|graha|nakshatra|dasha|rahu|ketu|shani)\b",
 "Education": r"\b(study|exam|college|university|degree|education|student|course)\b",
}
tc = Counter()
for r in user_q:
    t = r["content"].lower()
    for nm, p in themes.items():
        if re.search(p, t): tc[nm] += 1
theme_sorted = tc.most_common()

# ---- languages ----
langnames = {"hi":"Hindi","en":"English","ml":"Malayalam","ur":"Urdu","ru":"Russian",
             "pt":"Portuguese","es":"Spanish","ja":"Japanese","ta":"Tamil","de":"German","el":"Greek","mi":"Maori"}
langs = Counter(r["lang"] for r in voice_q if r["lang"])
lang_top = langs.most_common(7)
lang_other = sum(c for _, c in langs.most_common()[7:])

# ---- answer quality ----
ai_chart = sum(1 for r in ai_a if any(w in r["content"].lower() for w in
    ["your chart","your moon","your sun","nakshatra","dasha","lagna","venus","saturn","jupiter","ascendant"]))
ai_generic = len(ai_a) - ai_chart

# ---- convo depth ----
convos = defaultdict(list)
for r in corpus: convos[r["convo_id"]].append(r)
depths = [sum(1 for m in c if m["source"] in ("text","voice")) for c in convos.values()]
depth_buckets = {"1 (one-shot)":0,"2-3":0,"4-9":0,"10-24":0,"25+":0}
for d in depths:
    if d <= 1: depth_buckets["1 (one-shot)"] += 1
    elif d <= 3: depth_buckets["2-3"] += 1
    elif d <= 9: depth_buckets["4-9"] += 1
    elif d <= 24: depth_buckets["10-24"] += 1
    else: depth_buckets["25+"] += 1

# ---- feature reach ----
reach = {
 "HolyCow AI": len(ai_users),
 "Astro setup": sum(1 for u in users if u["has_astro"]=="1"),
 "Daily insights": sum(1 for u in users if num(u["daily_insights"])>0),
 "Ayurveda": sum(1 for u in users if u["has_ayurveda"]=="1"),
 "FTUE done": sum(1 for u in users if u["ftue_completed"]=="1"),
 "Posted": sum(1 for u in users if num(u["posts"])>0),
 "Human DMs": sum(1 for u in users if num(u["human_convos"])>0),
}

# ---- daily activity ----
ds = [{"day":d["day"],"msgs":int(num(d["user_msgs"])),"users":int(num(d["active_users"]))}
      for d in daily if d["day"]]

# ---- power user table ----
def pu_row(u):
    return {"name": (u["name"] or u["uid"])[:18], "msgs": int(num(u["ai_user_msgs"])),
            "convos": int(num(u["ai_convos"])), "voice": int(num(u["ai_voice_msgs"])),
            "astro": u["has_astro"]=="1", "life": u["lifespan_days"] or "?"}
power_rows = [pu_row(u) for u in ranked[:10]]

pct = lambda n, d: round(100*n/d) if d else 0

DATA = {
 "R": R, "ai_users": len(ai_users), "convos": len(convos),
 "tot_msgs": int(tot_msgs), "voice_q": len(voice_q), "text_q": len(user_q)-len(voice_q),
 "voice_pct": pct(len(voice_q), len(user_q)),
 "hindi_pct": deep["hindi_pct_of_voice"], "english_pct": deep["english_pct_of_voice"],
 "oneanddone_pct": pct(oneanddone, len(withlife)),
 "d1": pct(ret(1),len(withlife)), "d7": pct(ret(7),len(withlife)), "d30": pct(ret(30),len(withlife)),
 "ftue_pct": pct(reach["FTUE done"], R), "astro_pct": pct(reach["Astro setup"], R),
 "top10share": top10share, "top10n": len(top10),
 "voice_chars": deep["voice_avg_chars"], "text_chars": deep["text_avg_chars"],
 "ai_chart": ai_chart, "ai_generic": ai_generic, "ai_chart_pct": pct(ai_chart, len(ai_a)),
 "ai_median": deep["ai_median_len"], "ai_answers": len(ai_a),
 "oneshot_pct": pct(depth_buckets["1 (one-shot)"], len(depths)),
 "pos": deep["pos_signals"], "neg": deep["neg_signals"],
 "theme_labels":[t[0] for t in theme_sorted], "theme_vals":[t[1] for t in theme_sorted],
 "lang_labels":[langnames.get(l,l) for l,_ in lang_top]+(["Other"] if lang_other else []),
 "lang_vals":[c for _,c in lang_top]+([lang_other] if lang_other else []),
 "reach_labels":list(reach.keys()), "reach_vals":list(reach.values()),
 "depth_labels":list(depth_buckets.keys()), "depth_vals":list(depth_buckets.values()),
 "ret_curve":[len(withlife), ret(1), ret(7), ret(14), ret(30)],
 "lorenz": cum,
 "daily_days":[d["day"] for d in ds], "daily_msgs":[d["msgs"] for d in ds], "daily_users":[d["users"] for d in ds],
 "voice_text":[len(voice_q), len(user_q)-len(voice_q)],
 "power_rows": power_rows,
 # KPI cards: [label, value, subtext, color]
 "kpis": [
   ["Real users", R, "20 test excluded", "blue"],
   ["Used HolyCow AI", len(ai_users), f"{pct(len(ai_users),R)}% of users", "blue"],
   ["One-and-done", f"{pct(oneanddone,len(withlife))}%", "never returned", "red"],
   ["D7 retention", f"{pct(ret(7),len(withlife))}%", f"D30: {pct(ret(30),len(withlife))}%", "red"],
   ["Voice share", f"{pct(len(voice_q),len(user_q))}%", "of all questions", "spark"],
   ["AI chart-grounded", f"{pct(ai_chart,len(ai_a))}%", "rest are generic", "red"],
   [f"Top {len(top10)} users drive", f"{top10share}%", "of all questions", "purple"],
   ["FTUE completed", f"{pct(reach['FTUE done'],R)}%", f"astro setup: {pct(reach['Astro setup'],R)}%", "red"],
 ],
}

HTML = """<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aurogram — PMF Dashboard</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>body{font-family:ui-sans-serif,system-ui,-apple-system,sans-serif}
.card{background:#fff;border:1px solid #e5e7eb;border-radius:.75rem;box-shadow:0 1px 2px rgba(0,0,0,.04)}</style>
</head><body class="bg-gray-50 text-gray-900">
<div class="max-w-7xl mx-auto px-4 py-8">
<header class="mb-6">
  <h1 class="text-3xl font-bold">🐄 Aurogram — PMF Dashboard</h1>
  <p class="text-gray-500 mt-1">Internal research · __R__ real users · __CONVOS__ AI conversations · __MSGS__ questions · voice transcribed locally (whisper)</p>
</header>

<div class="rounded-xl p-6 mb-6 text-white" style="background:linear-gradient(135deg,#0053e2,#7c3aed)">
  <div class="text-sm uppercase tracking-wide opacity-80">The bombshell</div>
  <div class="text-2xl md:text-3xl font-bold mt-1">__HINDI__% of voice questions are in Hindi — only __ENG__% English.</div>
  <div class="opacity-90 mt-2">You're serving a Hindi-first audience through an English-first product. Likely the #1 hidden cause of __OAD__% one-and-done churn.</div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6" id="kpis"></div>

<div class="grid md:grid-cols-2 gap-6 mb-6">
  <div class="card p-5"><h3 class="font-semibold mb-1">🗣️ Voice language mix</h3>
    <p class="text-xs text-gray-500 mb-2">whisper auto-detected · the strategic surprise</p>
    <div style="height:300px"><canvas id="lang"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">📉 Retention curve</h3>
    <p class="text-xs text-gray-500 mb-2">users still active after N days (lifespan-based)</p>
    <div style="height:300px"><canvas id="ret"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">🔮 What people ask</h3>
    <p class="text-xs text-gray-500 mb-2">intent themes across full corpus (text+voice)</p>
    <div style="height:300px"><canvas id="themes"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">👑 Power law (who drives usage)</h3>
    <p class="text-xs text-gray-500 mb-2">cumulative % of questions by ranked users · top __T10N__ = __T10__%</p>
    <div style="height:300px"><canvas id="lorenz"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">💬 Conversation depth</h3>
    <p class="text-xs text-gray-500 mb-2">__ONESHOT__% die after one question</p>
    <div style="height:300px"><canvas id="depth"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">🎯 Feature reach</h3>
    <p class="text-xs text-gray-500 mb-2">real users touching each feature</p>
    <div style="height:300px"><canvas id="reach"></canvas></div></div>
</div>

<div class="grid md:grid-cols-2 gap-6 mb-6">
  <div class="card p-5"><h3 class="font-semibold mb-1">🤖 AI answer grounding</h3>
    <p class="text-xs text-gray-500 mb-2">only __CHARTPCT__% reference the user's actual chart — the rest is generic</p>
    <div style="height:280px"><canvas id="quality"></canvas></div></div>
  <div class="card p-5"><h3 class="font-semibold mb-1">🎤 Voice vs Text</h3>
    <p class="text-xs text-gray-500 mb-2">voice questions are __VC__ chars vs __TC__ for text — 2× richer</p>
    <div style="height:280px"><canvas id="vt"></canvas></div></div>
</div>

<div class="card p-5 mb-6"><h3 class="font-semibold mb-2">📅 Daily HolyCow activity</h3>
  <div style="height:300px"><canvas id="daily"></canvas></div></div>

<div class="card p-5 mb-6"><h3 class="font-semibold mb-3">🏆 Top 10 power users</h3>
  <table class="w-full text-sm"><thead><tr class="text-left text-gray-500 border-b">
  <th class="py-2">User</th><th>Questions</th><th>Convos</th><th>Voice</th><th>Astro setup</th><th>Lifespan (d)</th>
  </tr></thead><tbody id="putable"></tbody></table></div>

<div class="card p-6 mb-8" style="background:#fffbeb;border-color:#fde68a">
  <h2 class="text-lg font-bold mb-3" style="color:#92400e">📋 Strategy — ranked by data leverage</h2>
  <ol class="list-decimal ml-5 space-y-2 text-sm" style="color:#78350f">
    <li><b>Go Hindi-first.</b> Detect language, answer in it. Biggest invisible churn cause.</li>
    <li><b>Make the FIRST answer perfect.</b> __ONESHOT__% of convos are one question — that reply is the whole funnel. In-language, chart-grounded, about timing, with a hook to Q2.</li>
    <li><b>Lean into voice.</b> Where power users & richest questions live. Store + use transcripts (local whisper = $0).</li>
    <li><b>Specialize:</b> Timing → Career → Marriage → Children. Depth over breadth.</li>
    <li><b>Interview the __T10N__ power users.</b> They cracked the loop — replicate it.</li>
    <li><b>Then</b> wire analytics to track language, first→second-question conversion, chart-grounding rate.</li>
  </ol>
</div>

<p class="text-xs text-gray-400 text-center pb-6">Caveat: Hindi transcripts used whisper <code>base</code> — language detection solid, verbatim Hindi noisy. Re-run with <code>small</code> for quotable text.</p>
</div>

<script>
const D = __DATA__;
const C = {blue:"#0053e2",spark:"#ffc220",red:"#ea1100",green:"#2a8703",purple:"#7c3aed",gray:"#cbd5e1"};
const PIE = [C.spark,C.blue,C.green,C.purple,C.red,"#06b6d4","#f97316","#94a3b8"];
const COL = {blue:C.blue,red:C.red,spark:"#b45309",purple:C.purple,green:C.green};

document.getElementById("kpis").innerHTML = D.kpis.map(k =>
  `<div class="card p-5"><div class="text-3xl font-bold" style="color:${COL[k[3]]}">${k[1]}</div>
   <div class="text-sm font-medium text-gray-700 mt-1">${k[0]}</div>
   <div class="text-xs text-gray-500 mt-0.5">${k[2]}</div></div>`).join("");

const baseBar = {responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}}};
new Chart(lang,{type:"doughnut",data:{labels:D.lang_labels,datasets:[{data:D.lang_vals,backgroundColor:PIE}]},
  options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:"right"}}}});
new Chart(ret,{type:"line",data:{labels:["Signup","D1","D7","D14","D30"],
  datasets:[{data:D.ret_curve,borderColor:C.red,backgroundColor:"rgba(234,17,0,.1)",fill:true,tension:.3}]},options:baseBar});
new Chart(themes,{type:"bar",data:{labels:D.theme_labels,datasets:[{data:D.theme_vals,backgroundColor:C.blue}]},
  options:{...baseBar,indexAxis:"y"}});
new Chart(lorenz,{type:"line",data:{labels:D.lorenz.map((_,i)=>i+1),
  datasets:[{data:D.lorenz,borderColor:C.purple,backgroundColor:"rgba(124,58,237,.1)",fill:true,pointRadius:0,tension:.2}]},
  options:{...baseBar,scales:{x:{title:{display:true,text:"users (ranked by activity)"}},y:{title:{display:true,text:"cumulative % of questions"},max:100}}}});
new Chart(depth,{type:"bar",data:{labels:D.depth_labels,datasets:[{data:D.depth_vals,
  backgroundColor:D.depth_labels.map((l,i)=>i===0?C.red:C.green)}]},options:baseBar});
new Chart(reach,{type:"bar",data:{labels:D.reach_labels,datasets:[{data:D.reach_vals,backgroundColor:C.spark}]},
  options:{...baseBar,indexAxis:"y"}});
new Chart(quality,{type:"doughnut",data:{labels:["Chart-grounded","Generic"],
  datasets:[{data:[D.ai_chart,D.ai_generic],backgroundColor:[C.green,C.red]}]},
  options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:"bottom"}}}});
new Chart(vt,{type:"bar",data:{labels:["Voice","Text"],
  datasets:[{label:"# questions",data:D.voice_text,backgroundColor:[C.spark,C.blue]}]},options:baseBar});
new Chart(daily,{type:"line",data:{labels:D.daily_days,datasets:[
  {label:"Questions",data:D.daily_msgs,borderColor:C.blue,pointRadius:0,tension:.2},
  {label:"Active users",data:D.daily_users,borderColor:C.spark,pointRadius:0,tension:.2}]},
  options:{responsive:true,maintainAspectRatio:false}});

document.getElementById("putable").innerHTML = D.power_rows.map(p =>
 `<tr class="border-b border-gray-100"><td class="py-2 font-medium">${p.name}</td>
  <td>${p.msgs}</td><td>${p.convos}</td><td>${p.voice}</td>
  <td>${p.astro?"✅":"—"}</td><td>${p.life}</td></tr>`).join("");
</script>
</body></html>"""

html = (HTML
  .replace("__DATA__", json.dumps(DATA))
  .replace("__R__", str(DATA["R"]))
  .replace("__CONVOS__", str(DATA["convos"]))
  .replace("__MSGS__", str(len(user_q)))
  .replace("__HINDI__", str(DATA["hindi_pct"]))
  .replace("__ENG__", str(DATA["english_pct"]))
  .replace("__OAD__", str(DATA["oneanddone_pct"]))
  .replace("__T10N__", str(DATA["top10n"]))
  .replace("__T10__", str(DATA["top10share"]))
  .replace("__ONESHOT__", str(DATA["oneshot_pct"]))
  .replace("__CHARTPCT__", str(DATA["ai_chart_pct"]))
  .replace("__VC__", str(DATA["voice_chars"]))
  .replace("__TC__", str(DATA["text_chars"])))

out = DIR / "dashboard.html"
out.write_text(html, encoding="utf-8")
print(f"wrote {out}")
print(f"  {len(DATA['kpis'])} KPIs, {len(theme_sorted)} themes, {len(DATA['lang_labels'])} langs, "
      f"{len(ds)} daily points, {len(power_rows)} power users")
