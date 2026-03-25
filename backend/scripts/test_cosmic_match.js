// Test cosmic match calculation with real user data
import { calculateCosmicMatch, normalizeNakshatra, normalizeSign } from "../lib/vedic_compatibility.js";

// Test with actual user data from Firestore
// User 1: Abhinav (Poorvaabhadra nakshatra)
// User 2: Prerna Tyagi (Sravanam nakshatra)

const user1 = {
    moonSign: normalizeSign("Aquarius"),
    nakshatra: normalizeNakshatra("Poorvaabhadra"),
    sunSign: normalizeSign("Leo"),
    ascendant: normalizeSign("Gemini"),
};

const user2 = {
    moonSign: normalizeSign("Capricorn"),
    nakshatra: normalizeNakshatra("Sravanam"),
    sunSign: normalizeSign("Cancer"),
    ascendant: normalizeSign("Cancer"),
};

console.log("Testing Cosmic Match with real user data:");
console.log("\nUser 1 (Abhinav):");
console.log("  moonSign:", user1.moonSign);
console.log("  nakshatra:", user1.nakshatra);
console.log("  sunSign:", user1.sunSign);
console.log("  ascendant:", user1.ascendant);

console.log("\nUser 2 (Prerna):");
console.log("  moonSign:", user2.moonSign);
console.log("  nakshatra:", user2.nakshatra);
console.log("  sunSign:", user2.sunSign);
console.log("  ascendant:", user2.ascendant);

console.log("\n" + "=".repeat(60));
console.log("CALCULATING COSMIC MATCH...");
console.log("=".repeat(60) + "\n");

const result = calculateCosmicMatch(user1, user2);

console.log(`Overall Score: ${result.score}% (${result.label})`);
console.log(`Raw Score: ${result.rawScore}`);
console.log(`Insight: ${result.insight}`);
console.log(`Pillar Count: ${result.pillarCount}`);

console.log("\nPillar Breakdown:");
console.log("-".repeat(50));

for (const [key, pillar] of Object.entries(result.pillars)) {
    console.log(`  ${pillar.name}: ${pillar.score}%`);
    if (pillar.error) {
        console.log(`    ❌ ERROR: ${pillar.error}`);
    }
}

console.log("\n" + "=".repeat(60));

// Verify no errors in pillars
const errors = Object.entries(result.pillars)
    .filter(([key, p]) => p.error)
    .map(([key, p]) => `${key}: ${p.error}`);

if (errors.length > 0) {
    console.log("❌ ERRORS FOUND:");
    errors.forEach(e => console.log(`  - ${e}`));
    process.exit(1);
} else {
    console.log("✅ All calculations successful!");
}




