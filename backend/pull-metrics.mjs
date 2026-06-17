/**
 * pull-metrics.mjs — read REAL per-request token averages from the live
 * `aiChatMetrics` collection (written by backend/functions/ai_telemetry.js).
 *
 * Run from a machine authenticated to project ty-dev-516d7:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json
 *   node pull-metrics.mjs [maxDocs]
 *
 * Paste the printed values into reports/unit-economics.html.
 */
import admin from "firebase-admin";

const LIMIT = parseInt(process.argv[2] || "5000", 10);

admin.initializeApp({ projectId: "ty-dev-516d7" });
const db = admin.firestore();

const snap = await db
  .collection("aiChatMetrics")
  .orderBy("createdAt", "desc")
  .limit(LIMIT)
  .get();

let n = 0, pIn = 0, pOut = 0, pTot = 0, pTh = 0, search = 0;
snap.forEach((d) => {
  const x = d.data();
  n++;
  pIn += x.promptTokens || 0;
  pOut += x.candidatesTokens || 0;
  pTot += x.totalTokens || 0;
  pTh += x.thoughtsTokens || 0;
  if (x.usedSearch) search++;
});

if (!n) {
  console.log("No aiChatMetrics docs found.");
  process.exit(0);
}

const r = (v) => Math.round(v);
console.log("\n=== Real aiChatMetrics averages (last " + n + " requests) ===");
console.log("Input tokens / msg  (inTok)      :", r(pIn / n));
console.log("Output tokens / msg (outTok)     :", r(pOut / n));
console.log("Thinking tokens / msg            :", r(pTh / n), "(should be ~0)");
console.log("Total tokens / msg               :", r(pTot / n));
console.log("Search rate % (searchRate)       :", ((search / n) * 100).toFixed(1));
console.log("\nPaste inTok / outTok / searchRate into reports/unit-economics.html\n");
process.exit(0);
