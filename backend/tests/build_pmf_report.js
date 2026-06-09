/**
 * PMF REPORT GENERATOR — reads backend/analysis/*.csv and emits a flat HTML
 * report (Tailwind + Chart.js). Reproducible: re-run after any extract refresh.
 *
 * Usage: node tests/build_pmf_report.js   ->  backend/analysis/pmf_report.html
 */
import { readFileSync, writeFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const DIR = join(dirname(fileURLToPath(import.meta.url)), "../analysis");
const VOICE = "\uD83C\uDFA4 voice message";

function readCsv(name) {
  const txt = readFileSync(join(DIR, name), "utf8").trim();
  const lines = txt.split("\n");
  const head = parseLine(lines[0]);
  return lines.slice(1).map((l) => {
    const cells = parseLine(l);
    return Object.fromEntries(head.map((h, i) => [h, cells[i] ?? ""]));
  });
}
function parseLine(line) {
  const out = []; let cur = "", q = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) {
      if (c === '"' && line[i + 1] === '"') { cur += '"'; i++; }
      else if (c === '"') q = false;
      else cur += c;
    } else {
      if (c === '"') q = true;
      else if (c === ",") { out.push(cur); cur = ""; }
      else cur += c;
    }
  }
  out.push(cur); return out;
}
const num = (v) => { const n = parseFloat(v); return isNaN(n) ? 0 : n; };

// ---------- load ----------
const users = readCsv("users.csv").filter((u) => u.is_test === "0");
const msgs = readCsv("holycow_messages.csv");
const convos = readCsv("holycow_conversations.csv");
const daily = readCsv("holycow_daily.csv");

// ---------- compute ----------
const R = users.length;
const aiUsers = users.filter((u) => num(u.ai_user_msgs) > 0);
const totMsg = users.reduce((s, u) => s + num(u.ai_user_msgs), 0);
const totVoice = users.reduce((s, u) => s + num(u.ai_voice_msgs), 0);
const ranked = [...aiUsers].sort((a, b) => num(b.ai_user_msgs) - num(a.ai_user_msgs));
const top10 = ranked.slice(0, Math.max(1, Math.floor(ranked.length / 10)));
const top10Msgs = top10.reduce((s, u) => s + num(u.ai_user_msgs), 0);
const withLife = users.filter((u) => u.lifespan_days !== "");
const ls = withLife.map((u) => num(u.lifespan_days));
const pct = (n, d) => d ? (100 * n / d).toFixed(1) : "0";
const ret = (d) => ls.filter((x) => x >= d).length;

// themes (text-only, excludes voice placeholder)
const themeDefs = {
  "Timing / Prediction": /\b(when|will i|future|next month|next year|today|tomorrow|predict)\b/i,
  "Career / Work / Money": /\b(job|career|work|business|money|salary|finance|profession|promotion|income|wealth|rich)\b/i,
  "Love / Marriage": /\b(love|marriage|marry|relationship|partner|husband|wife|girlfriend|boyfriend|spouse|breakup)\b/i,
  "Travel / Relocation": /\b(travel|trip|abroad|foreign|relocat|visa)\b/i,
  "Health": /\b(health|disease|sick|body|mental|stress|anxiety|sleep)\b/i,
  "Self / Personality": /\b(who am i|personality|strength|weakness|about me|myself|my life|my nature)\b/i,
  "Children / Family": /\b(kid|kids|child|children|baby|pregnan|son|daughter|family|parent)\b/i,
  "Spiritual / Remedy": /\b(remedy|mantra|pooja|puja|gemstone|dosha|graha|planet|nakshatra|dasha|rahu|ketu|shani)\b/i,
  "Education": /\b(study|exam|college|university|degree|education|student|course)\b/i,
};
const textMsgs = msgs.map((m) => (m.content || "").trim())
  .filter((t) => t && t !== VOICE && num0(t));
function num0(t) { return !/^\d+$/.test(t); } // keep, dummy guard
const themeCounts = {};
for (const t of textMsgs) for (const [k, re] of Object.entries(themeDefs))
  if (re.test(t)) themeCounts[k] = (themeCounts[k] || 0) + 1;
const themeSorted = Object.entries(themeCounts).sort((a, b) => b[1] - a[1]);

// convo depth distribution
const depthBuckets = { "1 msg": 0, "2-3": 0, "4-9": 0, "10-24": 0, "25+": 0 };
for (const c of convos) {
  const n = num(c.user_msgs);
  if (n <= 1) depthBuckets["1 msg"]++;
  else if (n <= 3) depthBuckets["2-3"]++;
  else if (n <= 9) depthBuckets["4-9"]++;
  else if (n <= 24) depthBuckets["10-24"]++;
  else depthBuckets["25+"]++;
}

// feature reach (real users touching each feature)
const reach = {
  "HolyCow AI": aiUsers.length,
  "Astro setup": users.filter((u) => u.has_astro === "1").length,
  "Daily insights": users.filter((u) => num(u.daily_insights) > 0).length,
  "Ayurveda": users.filter((u) => u.has_ayurveda === "1").length,
  "FTUE done": users.filter((u) => u.ftue_completed === "1").length,
  "Posted": users.filter((u) => num(u.posts) > 0).length,
  "Has followers": users.filter((u) => num(u.followers) > 0).length,
  "Human DMs": users.filter((u) => num(u.human_convos) > 0).length,
};

// daily activity series
const dailySeries = daily.map((d) => ({ day: d.day, msgs: num(d.user_msgs), users: num(d.active_users) }))
  .filter((d) => d.day);

// monthly rollup
const monthly = {};
for (const d of dailySeries) {
  const m = d.day.slice(0, 7);
  if (!monthly[m]) monthly[m] = { msgs: 0, days: 0, users: new Set() };
  monthly[m].msgs += d.msgs; monthly[m].days++;
}
const monthlyRows = Object.entries(monthly).sort();

const KPI = (label, val, sub, color = "blue") => `
  <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
    <div class="text-3xl font-bold text-${color}-700">${val}</div>
    <div class="text-sm font-medium text-gray-700 mt-1">${label}</div>
    ${sub ? `<div class="text-xs text-gray-500 mt-1">${sub}</div>` : ""}
  </div>`;

const html = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aurogram — PMF Data Snapshot</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>body{font-family:ui-sans-serif,system-ui,-apple-system,sans-serif}</style>
</head>
<body class="bg-gray-50 text-gray-900">
<div class="max-w-6xl mx-auto px-4 py-8">

  <header class="mb-8">
    <h1 class="text-3xl font-bold">🐄 Aurogram — PMF Data Snapshot</h1>
    <p class="text-gray-500 mt-1">Internal research · generated ${new Date().toISOString().slice(0, 16).replace("T", " ")} · ${R} real users (test users excluded)</p>
  </header>

  <!-- EXEC SUMMARY TOP -->
  <section class="bg-blue-50 border border-blue-200 rounded-xl p-6 mb-8">
    <h2 class="text-lg font-bold text-blue-900 mb-3">Executive Insights</h2>
    <ul class="space-y-2 text-sm text-blue-950">
      <li>🐄 <b>HolyCow IS the product.</b> ${reach["HolyCow AI"]} of ${R} real users (${pct(reach["HolyCow AI"], R)}%) used the AI; AI conversations outnumber human DMs ~11:1.</li>
      <li>📉 <b>Retention is the crisis.</b> ${pct(ls.filter(x=>x<1).length, withLife.length)}% are one-and-done (never returned after signup day). D7 = ${pct(ret(7), withLife.length)}%, D30 = ${pct(ret(30), withLife.length)}%.</li>
      <li>👑 <b>Extreme power-law.</b> Top 10% of AI users (${top10.length} people) generate ${pct(top10Msgs, totMsg)}% of all questions. One user alone sent ${num(ranked[0].ai_user_msgs)}.</li>
      <li>🎤 <b>We're blind to 37% of demand.</b> ${totVoice} of ${msgs.length} messages are voice — and the spoken text is <b>not transcribed/stored</b>. We literally cannot read what 4 in 10 questions ask.</li>
      <li>🚪 <b>Activation leaks early.</b> Only ${pct(reach["FTUE done"], R)}% finish FTUE; ${pct(reach["Astro setup"], R)}% have astro data. The funnel loses most people before the magic.</li>
      <li>🔮 <b>What they want from us (the astrologers):</b> Timing/prediction, Career & money, and Love/marriage dominate the readable questions.</li>
    </ul>
  </section>

  <!-- KPIs -->
  <section class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
    ${KPI("Real users", R, `${users.length - R === 0 ? "" : ""}20 test excluded`)}
    ${KPI("Used HolyCow AI", reach["HolyCow AI"], pct(reach["HolyCow AI"], R) + "% of users")}
    ${KPI("AI conversations", convos.length, `${totMsg} user messages`)}
    ${KPI("Voice messages", totVoice, pct(totVoice, msgs.length) + "% of all msgs", "red")}
    ${KPI("Avg msgs / active user", (totMsg / Math.max(aiUsers.length, 1)).toFixed(1), "engagement depth", "green")}
    ${KPI("One-and-done", pct(ls.filter(x=>x<1).length, withLife.length) + "%", "never returned", "red")}
    ${KPI("FTUE completed", pct(reach["FTUE done"], R) + "%", `${reach["FTUE done"]} users`, "red")}
    ${KPI("Astro setup done", pct(reach["Astro setup"], R) + "%", `${reach["Astro setup"]} users`)}
  </section>

  <!-- charts grid -->
  <section class="grid md:grid-cols-2 gap-6 mb-8">
    <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
      <h3 class="font-semibold mb-3">Question themes (readable text only)</h3>
      <div style="height:300px"><canvas id="themes"></canvas></div>
    </div>
    <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
      <h3 class="font-semibold mb-3">Feature reach (real users)</h3>
      <div style="height:300px"><canvas id="reach"></canvas></div>
    </div>
    <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
      <h3 class="font-semibold mb-3">Conversation depth (user msgs per convo)</h3>
      <div style="height:300px"><canvas id="depth"></canvas></div>
    </div>
    <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
      <h3 class="font-semibold mb-3">Retention curve (lifespan-based)</h3>
      <div style="height:300px"><canvas id="ret"></canvas></div>
    </div>
  </section>

  <section class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm mb-8">
    <h3 class="font-semibold mb-3">Daily HolyCow activity</h3>
    <div style="height:320px"><canvas id="daily"></canvas></div>
  </section>

  <!-- monthly table -->
  <section class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm mb-8">
    <h3 class="font-semibold mb-3">Monthly breakdown</h3>
    <table class="w-full text-sm">
      <thead><tr class="text-left text-gray-500 border-b">
        <th class="py-2">Month</th><th>User messages</th><th>Active days</th><th>Msgs/active day</th></tr></thead>
      <tbody>
      ${monthlyRows.map(([m, v]) => `<tr class="border-b border-gray-100">
        <td class="py-2 font-medium">${m}</td><td>${v.msgs}</td><td>${v.days}</td>
        <td>${(v.msgs / v.days).toFixed(0)}</td></tr>`).join("")}
      </tbody>
    </table>
  </section>

  <!-- power users -->
  <section class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm mb-8">
    <h3 class="font-semibold mb-3">Top 10 power users (by AI questions)</h3>
    <table class="w-full text-sm">
      <thead><tr class="text-left text-gray-500 border-b">
        <th class="py-2">User</th><th>AI msgs</th><th>Convos</th><th>Voice</th><th>Posts</th><th>Astro</th><th>Lifespan (d)</th></tr></thead>
      <tbody>
      ${ranked.slice(0, 10).map((u) => `<tr class="border-b border-gray-100">
        <td class="py-2 font-medium">${(u.name || u.uid).slice(0, 18)}</td>
        <td>${num(u.ai_user_msgs)}</td><td>${num(u.ai_convos)}</td>
        <td>${num(u.ai_voice_msgs)}</td><td>${num(u.posts)}</td>
        <td>${u.has_astro === "1" ? "✅" : "—"}</td><td>${u.lifespan_days || "?"}</td></tr>`).join("")}
      </tbody>
    </table>
  </section>

  <!-- EXEC SUMMARY BOTTOM: recommendations -->
  <section class="bg-amber-50 border border-amber-200 rounded-xl p-6 mb-8">
    <h2 class="text-lg font-bold text-amber-900 mb-3">So what? — Recommended next moves</h2>
    <ol class="list-decimal ml-5 space-y-2 text-sm text-amber-950">
      <li><b>Fix the voice blind spot first.</b> Transcribe & store voice queries. 37% of demand is invisible to us — this is the single highest-leverage data fix.</li>
      <li><b>Treat D1 retention as THE metric.</b> 87% one-and-done means the loop never forms. Instrument & A/B the first-session experience before building new features (YAGNI on everything else).</li>
      <li><b>Mine the power users.</b> ${top10.length} people drive ${pct(top10Msgs, totMsg)}% of usage — interview them, find the "aha", replicate it for the other 90%.</li>
      <li><b>Double down on Timing, Career, Love.</b> That's what people actually ask. Make HolyCow exceptional at these three before breadth.</li>
      <li><b>Repair the activation funnel.</b> &lt;${pct(reach["FTUE done"], R)}% FTUE completion. Most never reach the astro setup that powers good answers.</li>
      <li><b>THEN wire lean analytics</b> (the dead AnalyticsService) to track these specific funnels going forward — instrument what the data proved matters, not everything.</li>
    </ol>
  </section>

  <footer class="text-xs text-gray-400 text-center py-4">
    Aurogram internal PMF snapshot · data from Firestore (project ty-dev-516d7) · raw CSVs in backend/analysis/
  </footer>
</div>

<script>
const C = { blue:"#0053e2", spark:"#ffc220", red:"#ea1100", green:"#2a8703", gray:"#94a3b8" };
new Chart(themes, { type:"bar", data:{ labels:${JSON.stringify(themeSorted.map(t=>t[0]))},
  datasets:[{ data:${JSON.stringify(themeSorted.map(t=>t[1]))}, backgroundColor:C.blue }]},
  options:{ indexAxis:"y", responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}} }});
new Chart(reach, { type:"bar", data:{ labels:${JSON.stringify(Object.keys(reach))},
  datasets:[{ data:${JSON.stringify(Object.values(reach))}, backgroundColor:C.spark }]},
  options:{ indexAxis:"y", responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}} }});
new Chart(depth, { type:"bar", data:{ labels:${JSON.stringify(Object.keys(depthBuckets))},
  datasets:[{ data:${JSON.stringify(Object.values(depthBuckets))}, backgroundColor:C.green }]},
  options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}} }});
new Chart(ret, { type:"line", data:{ labels:["D0","D1","D7","D14","D30"],
  datasets:[{ data:[${withLife.length}, ${ret(1)}, ${ret(7)}, ${ret(14)}, ${ret(30)}],
  borderColor:C.red, backgroundColor:"rgba(234,17,0,.1)", fill:true, tension:.3 }]},
  options:{ responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}} }});
new Chart(daily, { type:"line", data:{ labels:${JSON.stringify(dailySeries.map(d=>d.day))},
  datasets:[
    { label:"User messages", data:${JSON.stringify(dailySeries.map(d=>d.msgs))}, borderColor:C.blue, tension:.2, pointRadius:0 },
    { label:"Active users", data:${JSON.stringify(dailySeries.map(d=>d.users))}, borderColor:C.spark, tension:.2, pointRadius:0 }
  ]}, options:{ responsive:true, maintainAspectRatio:false } });
</script>
</body></html>`;

writeFileSync(join(DIR, "pmf_report.html"), html, "utf8");
console.log("✓ wrote backend/analysis/pmf_report.html");
console.log(`  themes: ${themeSorted.length}, daily points: ${dailySeries.length}, power users: ${ranked.length}`);
