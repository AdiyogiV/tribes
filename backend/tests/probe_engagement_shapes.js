/**
 * Tiny read-only shape probe for engagement collections.
 * Samples a few docs from each so we learn exact field names before the
 * full engagement extract. Touches nothing.
 */
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serviceAccount = JSON.parse(
  readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const COLLECTIONS = ["posts", "calls", "spaces", "globalFeed", "reposts", "notifications"];

function describe(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return `array[${v.length}]`;
  if (v && v.toMillis) return "timestamp";
  if (v && v._seconds) return "timestamp";
  if (typeof v === "object") return `object{${Object.keys(v).slice(0, 6).join(",")}}`;
  if (typeof v === "string") return `string(${v.slice(0, 40)})`;
  return typeof v;
}

async function main() {
  for (const col of COLLECTIONS) {
    console.log("\n" + "=".repeat(60));
    console.log("COLLECTION:", col);
    console.log("=".repeat(60));
    const snap = await db.collection(col).limit(3).get();
    console.log("sampled", snap.size, "docs");
    snap.docs.forEach((d, i) => {
      const data = d.data();
      console.log(`\n  doc[${i}] id=${d.id}`);
      Object.keys(data).sort().forEach((k) => {
        console.log(`    ${k}: ${describe(data[k])}`);
      });
    });
  }
  console.log("\nshape probe done");
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
