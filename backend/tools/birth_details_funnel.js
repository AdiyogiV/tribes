/**
 * Funnel: how many users logged in but never entered birth details?
 * Usage: node tools/birth_details_funnel.js
 *
 * "Logged in"       = has a Firebase Auth record.
 * "Entered details" = Firestore user doc has astrologyData with a birthday.
 */
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serviceAccount = JSON.parse(
    readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const auth = getAuth();

const hasBirthDetails = (d) => {
    const a = d && d.astrologyData;
    if (!a || typeof a !== "object") return false;
    // birthday can live under a few keys depending on write path
    return Boolean(a.birthday || a.birthDate || a.dateOfBirth || a.dob);
};

async function run() {
    // ---- All Auth users (definition of "logged in") ----
    const authUsers = [];
    let pageToken;
    do {
        const res = await auth.listUsers(1000, pageToken);
        authUsers.push(...res.users);
        pageToken = res.pageToken;
    } while (pageToken);

    // ---- All Firestore user docs, keyed by uid ----
    const snap = await db.collection("users").get();
    const docs = new Map();
    snap.docs.forEach((d) => docs.set(d.id, d.data()));

    let completed = 0;
    let skippedWithDoc = 0;   // logged in, has doc, no birthday
    let noDocAtAll = 0;       // logged in, but no Firestore doc (bailed mid-signup)
    let repeatSkippers = 0;   // skipped AND signed in more than once

    for (const u of authUsers) {
        const doc = docs.get(u.uid);
        if (!doc) {
            noDocAtAll++;
            continue;
        }
        if (hasBirthDetails(doc)) {
            completed++;
        } else {
            skippedWithDoc++;
            const created = u.metadata.creationTime;
            const lastSignIn = u.metadata.lastSignInTime;
            if (created && lastSignIn && new Date(lastSignIn) - new Date(created) > 60000) {
                repeatSkippers++;
            }
        }
    }

    const total = authUsers.length;
    const skippedTotal = skippedWithDoc + noDocAtAll;
    const pct = (n) => ((n / total) * 100).toFixed(1) + "%";

    console.log("=".repeat(60));
    console.log(" BIRTH-DETAILS FUNNEL");
    console.log("=".repeat(60));
    console.log(`Logged-in users (Auth records):      ${total}`);
    console.log(`   Completed birth details:         ${completed}  (${pct(completed)})`);
    console.log(`   Logged in, NO birth details:     ${skippedTotal}  (${pct(skippedTotal)})`);
    console.log(`     ├─ has profile doc, no birthday: ${skippedWithDoc}`);
    console.log(`     └─ no Firestore doc (bailed):    ${noDocAtAll}`);
    console.log(`   Repeat visitors still skipping:  ${repeatSkippers}`);
    console.log("=".repeat(60));
}

run().then(() => process.exit(0)).catch((e) => {
    console.error("Error:", e);
    process.exit(1);
});
