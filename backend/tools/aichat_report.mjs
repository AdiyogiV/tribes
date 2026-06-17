/**
 * aiChat analytics report.
 *
 * Reads the flat `aiChatMetrics` collection (one doc per request, written by
 * functions/ai.js) and prints aggregates: success/error rates, search-hit
 * rate, latency percentiles, and token spend.
 *
 * Usage:  node tools/aichat_report.mjs [limit]   (default 500)
 * Requires backend/serviceAccountKey.json (admin access).
 */
import admin from "firebase-admin";

admin.initializeApp({ credential: admin.credential.cert("./serviceAccountKey.json") });
const db = admin.firestore();

const LIMIT = parseInt(process.argv[2] || "500", 10);
const pct = (arr, p) => {
    if (!arr.length) return null;
    const s = [...arr].sort((a, b) => a - b);
    return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
};
const stat = (arr) => arr.length ? {
    n: arr.length, min: Math.min(...arr), p50: pct(arr, 50),
    avg: Math.round(arr.reduce((a, b) => a + b, 0) / arr.length),
    p95: pct(arr, 95), max: Math.max(...arr),
} : { n: 0 };
const inc = (o, k) => { o[k] = (o[k] || 0) + 1; };

(async () => {
    const snap = await db.collection("aiChatMetrics")
        .orderBy("createdAt", "desc").limit(LIMIT).get();

    if (snap.empty) {
        console.log("No aiChatMetrics yet. (Deploy the new aiChat, then send a few messages.)");
        process.exit(0);
    }

    const completed = [], failed = [];
    const errorTypes = {}, queryTypes = {}, contextSources = {};
    const ttft = [], synth = [], prep = [], total = [];
    const promptTok = [], candTok = [], thoughtTok = [], totalTok = [];
    let searchHits = 0, authed = 0;
    let oldest = null, newest = null;

    snap.forEach((d) => {
        const m = d.data();
        const ts = m.createdAt?.toDate?.();
        if (ts) { if (!newest || ts > newest) newest = ts; if (!oldest || ts < oldest) oldest = ts; }
        if (m.status === "failed") { failed.push(m); inc(errorTypes, m.errorType || "other"); return; }
        completed.push(m);
        inc(queryTypes, m.queryType || "unknown");
        inc(contextSources, m.contextSource || "none");
        if (m.authed) authed++;
        if (m.usedSearch) searchHits++;
        if (m.ttft_ms != null) ttft.push(m.ttft_ms);
        if (m.synthesis_ms != null) synth.push(m.synthesis_ms);
        if (m.prep_ms != null) prep.push(m.prep_ms);
        if (m.total_ms != null) total.push(m.total_ms);
        if (m.promptTokens != null) promptTok.push(m.promptTokens);
        if (m.candidatesTokens != null) candTok.push(m.candidatesTokens);
        if (m.thoughtsTokens != null) thoughtTok.push(m.thoughtsTokens);
        if (m.totalTokens != null) totalTok.push(m.totalTokens);
    });

    const n = snap.size;
    console.log(JSON.stringify({
        window: { oldest: oldest?.toISOString(), newest: newest?.toISOString(), sampled: n },
        reliability: {
            total: n, completed: completed.length, failed: failed.length,
            error_rate_pct: +(100 * failed.length / n).toFixed(1),
            error_types: errorTypes,
        },
        search: {
            hit_rate_pct: completed.length ? +(100 * searchHits / completed.length).toFixed(1) : 0,
            requests_using_search: searchHits,
        },
        mix: { query_types: queryTypes, context_sources: contextSources, authed_share_pct: completed.length ? +(100 * authed / completed.length).toFixed(1) : 0 },
        latency_ms: { ttft: stat(ttft), synthesis: stat(synth), prep: stat(prep), total: stat(total) },
        tokens: { prompt: stat(promptTok), candidates: stat(candTok), thoughts: stat(thoughtTok), total: stat(totalTok) },
    }, null, 2));
    process.exit(0);
})().catch((e) => { console.error("ERR", String(e)); process.exit(1); });
