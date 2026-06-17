#!/usr/bin/env python3
"""
Voice Messages Browser — see exactly what was said in every voice message, by whom.
Reads corpus_full.csv + users.csv -> voice_messages.html (searchable/filterable).
Re-run: python3 tests/build_voice_browser.py
"""
import csv, json
from collections import Counter, defaultdict
from pathlib import Path

csv.field_size_limit(10**7)
DIR = Path(__file__).resolve().parent.parent / "analysis"

def load_csv(name):
    with open(DIR / name) as f:
        return list(csv.DictReader(f))

users = {u["uid"]: u for u in load_csv("users.csv")}
corpus = load_csv("corpus_full.csv")

langnames = {"hi":"Hindi","en":"English","ml":"Malayalam","ur":"Urdu","ru":"Russian",
             "pt":"Portuguese","es":"Spanish","ja":"Japanese","ta":"Tamil","de":"German",
             "el":"Greek","mi":"Maori","fr":"French","ar":"Arabic","bn":"Bengali",
             "te":"Telugu","mr":"Marathi","gu":"Gujarati","kn":"Kannada","pa":"Punjabi","ne":"Nepali"}

# all voice messages (real transcribed ones)
voice = [r for r in corpus if r["source"] == "voice"]
rows = []
for r in voice:
    uid = r["sender"]
    u = users.get(uid, {})
    name = u.get("name") or "Unknown"
    content = r["content"].strip()
    failed = content.startswith("[voice")
    mid = r["msg_id"]
    has_audio = (DIR / "voice_mp3" / f"{mid}.mp3").exists()
    rows.append({
        "name": name,
        "uid": uid[:8],
        "mid": mid,
        "audio": has_audio,
        "lang": langnames.get(r["lang"], r["lang"] or "?"),
        "langcode": r["lang"] or "",
        "time": r["timestamp"][:16].replace("T", " ") if r["timestamp"] else "",
        "len": int(r["char_len"]) if r["char_len"] else 0,
        "text": content,
        "failed": failed,
    })
# newest first
rows.sort(key=lambda x: x["time"], reverse=True)

# stats for filter chips
ok_rows = [r for r in rows if not r["failed"]]
lang_counts = Counter(r["lang"] for r in ok_rows)
user_counts = Counter(r["name"] for r in ok_rows)
top_users = user_counts.most_common(15)

stats = {
    "total": len(rows),
    "transcribed": len(ok_rows),
    "failed": len(rows) - len(ok_rows),
    "users": len(set(r["uid"] for r in ok_rows)),
    "langs": len(lang_counts),
    "with_audio": sum(1 for r in rows if r["audio"]),
}

HTML = """<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aurogram — Voice Messages Browser</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>body{font-family:ui-sans-serif,system-ui,-apple-system,sans-serif}
.card{background:#fff;border:1px solid #e5e7eb;border-radius:.6rem}
.chip{cursor:pointer;user-select:none}</style>
</head><body class="bg-gray-50 text-gray-900">
<div class="max-w-5xl mx-auto px-4 py-8">

<header class="mb-5">
  <h1 class="text-3xl font-bold">🎤 Voice Messages — what people actually said</h1>
  <p class="text-gray-500 mt-1">__TOTAL__ voice messages · __TX__ transcribed locally (whisper) · __NUSERS__ users · __NLANGS__ languages</p>
  <p class="text-xs text-gray-600 mt-1">Click any player to listen to the original recording (__NAUDIO__ playable).</p>
  <p class="text-xs text-amber-700 mt-1">⚠️ Transcribed with whisper <code>base</code> — English is accurate, Hindi/other is approximate (re-run with <code>small</code> for cleaner non-English text).</p>
</header>

<!-- controls -->
<div class="card p-4 mb-4 sticky top-2 z-10 shadow-sm">
  <input id="search" type="text" placeholder="🔍 Search text or name…"
    class="w-full border border-gray-300 rounded-lg px-3 py-2 mb-3 focus:outline-none focus:ring-2 focus:ring-blue-500">
  <div class="flex flex-wrap gap-2 items-center mb-2">
    <span class="text-xs font-semibold text-gray-500 mr-1">Language:</span>
    <span id="langchips"></span>
  </div>
  <div class="flex flex-wrap gap-2 items-center">
    <span class="text-xs font-semibold text-gray-500 mr-1">Top users:</span>
    <span id="userchips"></span>
  </div>
  <div class="text-xs text-gray-500 mt-2"><span id="count"></span> shown</div>
</div>

<div id="list" class="space-y-2"></div>
<button id="more" onclick="renderMore()" class="w-full mt-4 py-2 rounded-lg bg-gray-200 text-gray-700 hover:bg-gray-300 text-sm font-medium" style="display:none">Load more</button>

</div>
<script>
const ROWS = __ROWS__;
const LANGS = __LANGS__;     // [[label,count],...]
const USERS = __USERS__;     // [[name,count],...]
const LANGCOLOR = {Hindi:"#ea1100",English:"#0053e2",Malayalam:"#2a8703",Urdu:"#7c3aed",
  Russian:"#06b6d4",Tamil:"#f97316",German:"#b45309"};

let fLang = null, fUser = null, q = "";
let shown = 0, filtered = [];
const PAGE = 50;

function esc(s){return s.replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));}

function playInline(btn, mid){
  const a = document.createElement("audio");
  a.controls = true; a.autoplay = true; a.className = "w-full mt-2"; a.style.height = "34px";
  a.src = "voice_mp3/" + mid + ".mp3";
  btn.replaceWith(a);
}

function cardHTML(r){
  const c = LANGCOLOR[r.lang]||"#64748b";
  return `<div class="card p-3">
      <div class="flex items-center gap-2 mb-1 text-xs">
        <span class="font-semibold text-gray-800">${esc(r.name)}</span>
        <span class="text-gray-400">${r.uid}</span>
        <span class="px-1.5 py-0.5 rounded text-white" style="background:${c}">${r.lang}</span>
        <span class="text-gray-400 ml-auto">${r.time}</span>
      </div>
      <div class="text-sm text-gray-900">${esc(r.text)}</div>
      ${r.audio?`<button onclick="playInline(this,'${r.mid}')" class="mt-2 text-xs px-3 py-1 rounded-full bg-blue-600 text-white hover:bg-blue-700">play</button>`:`<div class="text-xs text-gray-300 mt-1">no audio</div>`}
    </div>`;
}

function renderMore(){
  const next = filtered.slice(shown, shown + PAGE);
  document.getElementById("list").insertAdjacentHTML("beforeend", next.map(cardHTML).join(""));
  shown += next.length;
  const more = document.getElementById("more");
  if(shown < filtered.length){ more.style.display="block"; more.textContent=`Load more (${(filtered.length-shown).toLocaleString()} remaining)`; }
  else { more.style.display="none"; }
}

function render(){
  const ql = q.toLowerCase();
  filtered = ROWS.filter(r=>{
    if(r.failed) return false;
    if(fLang && r.lang!==fLang) return false;
    if(fUser && r.name!==fUser) return false;
    if(ql && !(r.text.toLowerCase().includes(ql)||r.name.toLowerCase().includes(ql))) return false;
    return true;
  });
  document.getElementById("count").textContent = filtered.length.toLocaleString();
  shown = 0;
  document.getElementById("list").innerHTML = "";
  renderMore();
}

function chip(label,count,active,onClick){
  const el=document.createElement("span");
  el.className="chip inline-block px-2 py-1 rounded-full text-xs mr-1 mb-1 "+
    (active?"bg-blue-600 text-white":"bg-gray-100 text-gray-700 hover:bg-gray-200");
  el.textContent=`${label} (${count})`;
  el.onclick=onClick;
  return el;
}

function buildChips(){
  const lc=document.getElementById("langchips"); lc.innerHTML="";
  lc.appendChild(chip("All", ROWS.filter(r=>!r.failed).length, fLang===null, ()=>{fLang=null;buildChips();render();}));
  LANGS.forEach(([l,c])=> lc.appendChild(chip(l,c,fLang===l,()=>{fLang=(fLang===l?null:l);buildChips();render();})));
  const uc=document.getElementById("userchips"); uc.innerHTML="";
  uc.appendChild(chip("All", USERS.reduce((s,u)=>s+u[1],0), fUser===null, ()=>{fUser=null;buildChips();render();}));
  USERS.forEach(([n,c])=> uc.appendChild(chip(n,c,fUser===n,()=>{fUser=(fUser===n?null:n);buildChips();render();})));
}

document.getElementById("search").addEventListener("input",e=>{q=e.target.value;render();});
buildChips(); render();
</script>
</body></html>"""


html = HTML
html = html.replace("__ROWS__", json.dumps(rows))
html = html.replace("__LANGS__", json.dumps(lang_counts.most_common()))
html = html.replace("__USERS__", json.dumps(top_users))
html = html.replace("__TOTAL__", str(stats["total"]))
html = html.replace("__TX__", str(stats["transcribed"]))
html = html.replace("__NUSERS__", str(stats["users"]))
html = html.replace("__NLANGS__", str(stats["langs"]))
html = html.replace("__NAUDIO__", str(stats["with_audio"]))

out = DIR / "voice_messages.html"
out.write_text(html, encoding="utf-8")
print(f"wrote {out}")
print(f"  {stats['transcribed']} transcribed voice msgs, {stats['users']} users, "
      f"{stats['langs']} languages, {len(top_users)} top-user chips")
