// One-off: ground-truth check whether per-house biweekly readings exist.
// Reads users with astrology enabled and reports who has skyHouseReadings.
import admin from "firebase-admin";
import { readFile } from "fs/promises";

const serviceAccount = JSON.parse(
    await readFile("./serviceAccountKey.json", "utf-8")
);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const snap = await db.collection("users")
    .where("astrologyData.isEnabled", "==", true)
    .limit(20)
    .get();

console.log(`\nChecking ${snap.size} astrology-enabled users for skyHouseReadings:\n`);
console.log("=".repeat(78));

let withReadings = 0;
let without = 0;
for (const doc of snap.docs) {
    const data = doc.data();
    const astro = data.astrologyData || {};
    const shr = astro.skyHouseReadings;
    const hi = astro.houseInterpretations;

    const name = (data.name || data.displayName || "").slice(0, 18).padEnd(18);
    const uid = doc.id.slice(0, 12);

    if (shr && shr.houses) {
        withReadings++;
        const houseCount = Object.keys(shr.houses).length;
        const cycleEnd = shr.cycleEndDate || "?";
        const generatedAt = shr.generatedAt
            ? new Date(shr.generatedAt._seconds * 1000).toISOString().slice(0, 16)
            : "?";
        console.log(`✅ ${uid} ${name} | ${houseCount} houses | cycle→${cycleEnd} | gen ${generatedAt}`);
    } else {
        without++;
        const hiCount = hi ? Object.keys(hi).length : 0;
        console.log(`❌ ${uid} ${name} | NO skyHouseReadings | natal houses: ${hiCount}`);
    }
}

console.log("=".repeat(78));
console.log(`\nSummary: ${withReadings} have readings, ${without} don't (of ${snap.size} checked)\n`);

process.exit(0);
