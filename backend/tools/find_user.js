/**
 * One-off: look up a user by (partial, case-insensitive) name.
 * Usage: node tools/find_user.js kanisha
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

const needle = (process.argv[2] || "").toLowerCase();
if (!needle) {
    console.error("Give me a name to search for, e.g. node tools/find_user.js kanisha");
    process.exit(1);
}

const fmt = (ts) => {
    if (!ts) return "N/A";
    try {
        if (typeof ts.toDate === "function") return ts.toDate().toISOString();
        if (typeof ts === "number") return new Date(ts).toISOString();
        return new Date(ts).toISOString();
    } catch {
        return String(ts);
    }
};

async function run() {
    console.log(` Searching for users matching "${needle}"\n${"=".repeat(70)}\n`);

    // ---- Firestore ----
    const snap = await db.collection("users").get();
    const matches = snap.docs.filter((d) => {
        const x = d.data();
        return [x.name, x.displayName, x.username, x.handle, x.email]
            .filter(Boolean)
            .some((v) => String(v).toLowerCase().includes(needle));
    });

    if (matches.length === 0) {
        console.log("No Firestore user docs matched.\n");
    } else {
        for (const doc of matches) {
            const d = doc.data();
            console.log(` Firestore user: ${doc.id}`);
            console.log(`   name: ${d.name || d.displayName || "(none)"}`);
            console.log(`   createdAt: ${fmt(d.createdAt)}`);
            console.log(`   joinedAt: ${fmt(d.joinedAt)}`);
            console.log(`   updatedAt: ${fmt(d.updatedAt)}`);
            console.log(`   lastActive: ${fmt(d.lastActive || d.lastSeen)}`);
            console.log(`   --- full document ---`);
            console.log(JSON.stringify(d, null, 2));
            console.log();

            // Try to pair with the Auth record for the real signup date.
            try {
                const u = await auth.getUser(doc.id);
                console.log(`    Auth record for ${doc.id}:`);
                console.log(`      createdAt (signup): ${fmt(u.metadata.creationTime)}`);
                console.log(`      lastSignIn: ${fmt(u.metadata.lastSignInTime)}`);
                console.log(`      phone: ${u.phoneNumber || "N/A"} | email: ${u.email || "N/A"}`);
                console.log(`      providers: ${u.providerData.map((p) => p.providerId).join(", ") || "none"}`);
                console.log();
            } catch (e) {
                console.log(`    No matching Auth record (${e.code || e.message})\n`);
            }
        }
    }

    // ---- Firebase Auth direct scan (in case there's no Firestore doc) ----
    console.log(`${"=".repeat(70)}\n Scanning Firebase Auth directly...\n`);
    let authMatches = 0;
    let pageToken;
    do {
        const res = await auth.listUsers(1000, pageToken);
        for (const u of res.users) {
            const hit = [u.displayName, u.email, u.phoneNumber]
                .filter(Boolean)
                .some((v) => String(v).toLowerCase().includes(needle));
            if (hit) {
                authMatches++;
                console.log(`   ${u.displayName || "(no name)"} | uid: ${u.uid}`);
                console.log(`      signup: ${fmt(u.metadata.creationTime)} | lastSignIn: ${fmt(u.metadata.lastSignInTime)}`);
                console.log(`      phone: ${u.phoneNumber || "N/A"} | email: ${u.email || "N/A"}\n`);
            }
        }
        pageToken = res.pageToken;
    } while (pageToken);

    if (authMatches === 0) console.log("   No Auth users matched.\n");
    console.log(" Done.");
}

run().then(() => process.exit(0)).catch((e) => {
    console.error("Error:", e);
    process.exit(1);
});
