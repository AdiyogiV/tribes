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
    console.log("📋 All users in Firestore:\n");
    console.log("=".repeat(70));
    
    const usersSnapshot = await db.collection("users").get();
    
    usersSnapshot.docs.forEach((doc, index) => {
        const data = doc.data();
        console.log(`${index + 1}. ${data.name || '(no name)'}`);
        console.log(`   UID: ${doc.id}`);
        if (data.phoneNumber) console.log(`   Phone: ${data.phoneNumber}`);
        if (data.email) console.log(`   Email: ${data.email}`);
        console.log();
    });
    
    console.log(`\nTotal users in Firestore: ${usersSnapshot.size}`);
    
    // Also check Firebase Auth
    console.log("\n\n📱 Firebase Auth users:\n");
    console.log("=".repeat(70));
    
    const authUsers = await auth.listUsers(1000);
    authUsers.users.forEach((user, index) => {
        console.log(`${index + 1}. ${user.displayName || '(no name)'}`);
        console.log(`   UID: ${user.uid}`);
        if (user.phoneNumber) console.log(`   Phone: ${user.phoneNumber}`);
        if (user.email) console.log(`   Email: ${user.email}`);
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


