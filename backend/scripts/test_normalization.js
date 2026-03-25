// Test nakshatra normalization
import { normalizeNakshatra, NAKSHATRA_GANA } from "../lib/vedic_compatibility.js";

// Test cases from actual API responses
const testCases = [
    { input: "Sravanam", expected: "Shravana" },
    { input: "Makha", expected: "Magha" },
    { input: "Pushyami", expected: "Pushya" },
    { input: "Poorvaabhadra", expected: "Purva Bhadrapada" },
    { input: "Aswini", expected: "Ashwini" },
    { input: "Aaslesha", expected: "Ashlesha" },
    { input: "Poorvaashaada", expected: "Purva Ashadha" },
    { input: "Aardra", expected: "Ardra" },
    { input: "Visakha", expected: "Vishakha" },
    { input: "Jyeshta", expected: "Jyeshtha" },
    { input: "Satabisha", expected: "Shatabhisha" },
    { input: "Poorva Phalguni(Pubba)", expected: "Purva Phalguni" },
    // Standard names should pass through
    { input: "Ashwini", expected: "Ashwini" },
    { input: "Rohini", expected: "Rohini" },
    { input: "Hasta", expected: "Hasta" },
    { input: "Krittika", expected: "Krittika" },
];

console.log("Testing nakshatra normalization...\n");

let passed = 0;
let failed = 0;

for (const { input, expected } of testCases) {
    const result = normalizeNakshatra(input);
    const gana = NAKSHATRA_GANA[result];
    
    if (result === expected && gana) {
        console.log(`✅ "${input}" → "${result}" (Gana: ${gana})`);
        passed++;
    } else {
        console.log(`❌ "${input}" → "${result}" (expected: "${expected}", Gana: ${gana || "NOT FOUND"})`);
        failed++;
    }
}

console.log(`\n${"=".repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);

if (failed > 0) {
    process.exit(1);
}




