// Debug script to check user astrology data in Firestore
import admin from "firebase-admin";
import { readFile } from "fs/promises";

// Initialize Firebase Admin
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
    "./serviceAccountKey.json";

const serviceAccount = JSON.parse(await readFile(serviceAccountPath, "utf-8"));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Check specific user or recent compatibility cache
async function debugUserAstro() {
    console.log("🔍 Debugging user astrology data...\n");
    
    // First check recent compatibility cache
    const cacheQuery = await db.collection("compatibilityScores")
        .orderBy("calculatedAt", "desc")
        .limit(5)
        .get();
    
    if (cacheQuery.empty) {
        console.log("No cached compatibility scores found.\n");
    } else {
        console.log(`Found ${cacheQuery.size} cached compatibility scores:\n`);
        for (const doc of cacheQuery.docs) {
            const data = doc.data();
            console.log(`Cache ID: ${doc.id}`);
            console.log(`  User1: ${data.user1Id}`);
            console.log(`  User2: ${data.user2Id}`);
            console.log(`  Cosmic Score: ${data.cosmicMatch?.score}`);
            console.log(`  Pillars:`, JSON.stringify(data.cosmicMatch?.pillars, null, 2));
            console.log("");
        }
    }
    
    // Get user IDs from cache or use known test users
    const userIds = new Set();
    cacheQuery.docs.forEach(doc => {
        const data = doc.data();
        if (data.user1Id) userIds.add(data.user1Id);
        if (data.user2Id) userIds.add(data.user2Id);
    });
    
    // Also add known problem users
    userIds.add("bx0Qq0iuPkavO8ypYePu2yIvh9h2");
    // Add current user (Abhinav) - check all users collection for recent
    const recentUsers = await db.collection("users")
        .where("astrologyData.isEnabled", "==", true)
        .limit(10)
        .get();
    recentUsers.docs.forEach(doc => userIds.add(doc.id));
    
    console.log("\n" + "=".repeat(60));
    console.log("CHECKING USER ASTROLOGY DATA:");
    console.log("=".repeat(60) + "\n");
    
    for (const userId of userIds) {
        try {
            const userDoc = await db.collection("users").doc(userId).get();
            if (!userDoc.exists) {
                console.log(`User ${userId}: NOT FOUND\n`);
                continue;
            }
            
            const userData = userDoc.data();
            const astroData = userData.astrologyData;
            
            console.log(`User: ${userId}`);
            console.log(`  Name: ${userData.name || userData.displayName || "N/A"}`);
            
            if (!astroData) {
                console.log(`  Astrology Data: NOT SET\n`);
                continue;
            }
            
            console.log(`  Astrology Enabled: ${astroData.isEnabled}`);
            console.log(`  Moon Sign: "${astroData.moonSign}"`);
            console.log(`  Nakshatra: "${astroData.nakshatra}"`);
            console.log(`  Moon Nakshatra: "${astroData.moonNakshatra}"`);
            console.log(`  Sun Sign: "${astroData.sunSign}"`);
            console.log(`  Ascendant: "${astroData.ascendant}"`);
            console.log(`  Lagna: "${astroData.lagna}"`);
            
            // Check all fields that might contain nakshatra
            const allKeys = Object.keys(astroData);
            const nakshatraFields = allKeys.filter(k => 
                k.toLowerCase().includes("nakshatra") || 
                k.toLowerCase().includes("star")
            );
            if (nakshatraFields.length > 0) {
                console.log(`  All Nakshatra-related fields:`);
                nakshatraFields.forEach(k => {
                    console.log(`    ${k}: "${astroData[k]}"`);
                });
            }
            
            console.log("");
        } catch (err) {
            console.log(`User ${userId}: ERROR - ${err.message}\n`);
        }
    }
    
    process.exit(0);
}

debugUserAstro().catch(console.error);

