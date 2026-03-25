/**
 * Script to list all users in the database
 * Usage: node tests/list_all_users.js
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
    readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);

initializeApp({
    credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();

async function listAllUsers() {
    console.log("📋 All users in Firestore (ordered by latest joining):\n");
    console.log("=".repeat(70));

    const usersSnapshot = await db.collection("users").get();

    // Convert to array and sort by createdAt (most recent first)
    const users = usersSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
    }));

    // Sort by createdAt or metadata.creationTime (newest first)
    users.sort((a, b) => {
        const aTime = a.createdAt?.toMillis?.() || a.createdAt?.seconds * 1000 || 0;
        const bTime = b.createdAt?.toMillis?.() || b.createdAt?.seconds * 1000 || 0;
        return bTime - aTime; // Descending order (newest first)
    });

    users.forEach((user, index) => {
        console.log(`${index + 1}. ${user.name || '(no name)'}`);
        console.log(`   UID: ${user.id}`);
        if (user.phoneNumber) console.log(`   Phone: ${user.phoneNumber}`);
        if (user.email) console.log(`   Email: ${user.email}`);

        // Display join date if available
        if (user.createdAt) {
            const date = user.createdAt.toDate ? user.createdAt.toDate() : new Date(user.createdAt.seconds * 1000);
            console.log(`   Joined: ${date.toISOString().split('T')[0]} ${date.toLocaleTimeString()}`);
        }
        console.log();
    });

    console.log(`\nTotal users in Firestore: ${users.length}`);

    // Also check Firebase Auth
    console.log("\n\n📱 Firebase Auth users (ordered by creation):\n");
    console.log("=".repeat(70));

    const authUsers = await auth.listUsers(1000);

    // Sort by metadata.creationTime (newest first)
    const sortedAuthUsers = authUsers.users.sort((a, b) => {
        const aTime = new Date(a.metadata.creationTime).getTime();
        const bTime = new Date(b.metadata.creationTime).getTime();
        return bTime - aTime; // Descending order (newest first)
    });

    sortedAuthUsers.forEach((user, index) => {
        console.log(`${index + 1}. ${user.displayName || '(no name)'}`);
        console.log(`   UID: ${user.uid}`);
        if (user.phoneNumber) console.log(`   Phone: ${user.phoneNumber}`);
        if (user.email) console.log(`   Email: ${user.email}`);
        if (user.metadata.creationTime) console.log(`   Created: ${user.metadata.creationTime}`);
        console.log();
    });

    console.log(`\nTotal Auth users: ${authUsers.users.length}`);
}

listAllUsers()
    .then(() => {
        console.log("\n✅ Done!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("Error:", error);
        process.exit(1);
    });


