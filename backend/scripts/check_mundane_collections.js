import { fileURLToPath } from "url";
import { dirname, join } from "path";
const __dirname = dirname(fileURLToPath(import.meta.url));
process.env.GOOGLE_APPLICATION_CREDENTIALS = join(__dirname, "../serviceAccountKey.json");
const { db } = await import("../lib/firebase.js");

const cols = ["mundane_forecasts", "mundane_predictions", "mundane_confidence",
              "mundane_validations", "cosmic_daily_output"];
for (const c of cols) {
  const snap = await db.collection(c).limit(3).get();
  console.log(`${c.padEnd(28)} → ${snap.size} docs (ids: ${snap.docs.map(d=>d.id).join(", ")})`);
}
process.exit(0);
