/**
 * Quick smoke test: verify gemini-2.5-flash produces full-length output
 * after removing the maxOutputTokens cap.
 *
 * Run: node tests/test_token_fix.js
 *
 * Requires GEMINI_API_KEY env var (or uses the secret manager value via firebase).
 */

import { GoogleGenerativeAI } from "@google/generative-ai";

// Try env var first, fallback to hardcoded test key placeholder
const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
    console.error("❌ Set GEMINI_API_KEY env var first:\n  export GEMINI_API_KEY=<your key>");
    process.exit(1);
}

const genAI = new GoogleGenerativeAI(apiKey);

// ── Test 1: First Reading (was maxOutputTokens: 600, now uses default 65536) ──
async function testFirstReading() {
    console.log("\n🧪 Test 1: First Reading (was capped at 600 tokens)\n");

    const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: { temperature: 0.95, maxOutputTokens: 65536 },
    });

    const system = `You are a bold, insightful astrologer who creates readings that feel deeply personal and transformative. You make specific, confident claims. Output valid markdown with **bold**, *italics*, ### headings, and - bullet lists.`;

    const user = `Write a bold, personalized BIRTH CHART reading.
Focus ONLY on personality, identity, core gifts. No predictions or timing.

CHART:
- Sun: Taurus (core identity)
- Moon: Sagittarius (emotional nature)
- Rising: Gemini (how they appear)

STRUCTURE (150-180 words):
1. Opening: One bold claim about who they are.
2. ### Your Inner Architecture — 2-3 bullet points on core gift.
3. ### How You Move Through the World — 2-3 sentences.
4. ### A Hidden Strength — one short paragraph.

Write the reading now:`;

    const start = Date.now();
    const result = await model.generateContent([{ text: system }, { text: user }]);
    const text = result.response.text()?.trim();
    const ms = Date.now() - start;

    console.log(`  Output length: ${text.length} chars (~${text.split(/\s+/).length} words)`);
    console.log(`  Latency: ${ms}ms`);
    console.log(`  Preview:\n    ${text.substring(0, 300).replace(/\n/g, "\n    ")}...`);
    console.log();

    if (text.length < 200) {
        console.log("  ❌ FAIL — still truncated! Output too short.");
        return false;
    }
    console.log("  ✅ PASS — full-length output");
    return true;
}

// ── Test 2: House Interpretations (was maxOutputTokens: 4000, now 65536) ──
async function testHouseInterpretations() {
    console.log("\n🧪 Test 2: House Interpretations (was capped at 4000 tokens)\n");

    const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: { temperature: 0.7, maxOutputTokens: 65536 },
    });

    const system = `You are a masterful Vedic astrologer who synthesizes chart factors into profound, specific insights.`;

    const user = `CHART: Gemini Rising | Jupiter Mahadasha | Aries Moon

Write ONE flowing paragraph (2-3 sentences) per house.

OUTPUT FORMAT:
---HOUSE 1---
[paragraph]
---HOUSE 2---
[paragraph]
...through all 12 houses

HOUSE DATA:
---
HOUSE 1 (Lagna): Sign: Gemini (Lord: Mercury). Mercury in House 10.
---
HOUSE 2 (Wealth): Sign: Cancer (Lord: Moon). Moon in House 11.
---
HOUSE 3 (Siblings): Sign: Leo (Lord: Sun). Sun in House 9.
---
HOUSE 4 (Home): Sign: Virgo (Lord: Mercury). Mercury in House 10.
---
HOUSE 5 (Children): Sign: Libra (Lord: Venus). Venus in House 7.
---
HOUSE 6 (Health): Sign: Scorpio (Lord: Mars). Mars in House 8.
---
HOUSE 7 (Marriage): Sign: Sagittarius (Lord: Jupiter). Jupiter in House 1.
---
HOUSE 8 (Transformation): Sign: Capricorn (Lord: Saturn). Saturn in House 3.
---
HOUSE 9 (Fortune): Sign: Aquarius (Lord: Saturn). Saturn in House 3.
---
HOUSE 10 (Career): Sign: Pisces (Lord: Jupiter). Jupiter in House 1.
---
HOUSE 11 (Gains): Sign: Aries (Lord: Mars). Mars in House 8.
---
HOUSE 12 (Liberation): Sign: Taurus (Lord: Venus). Venus in House 7.

Write all 12 house interpretations now:`;

    const start = Date.now();
    const result = await model.generateContent([{ text: system }, { text: user }]);
    const text = result.response.text()?.trim();
    const ms = Date.now() - start;

    // Count how many houses got text
    let housesFound = 0;
    for (let h = 1; h <= 12; h++) {
        const regex = new RegExp(`---HOUSE ${h}---([\\s\\S]*?)(?=---HOUSE \\d+---|$)`, "i");
        const match = text.match(regex);
        const interp = match ? match[1].trim() : "";
        if (interp.length >= 20) housesFound++;
    }

    console.log(`  Output length: ${text.length} chars`);
    console.log(`  Latency: ${ms}ms`);
    console.log(`  Houses with content (>=20 chars): ${housesFound}/12`);
    console.log();

    if (housesFound < 12) {
        console.log(`  ❌ FAIL — only ${housesFound}/12 houses populated`);
        return false;
    }
    console.log("  ✅ PASS — all 12 houses populated");
    return true;
}

// ── Retry wrapper ──
async function withRetry(fn, name, maxAttempts = 4) {
    for (let i = 0; i < maxAttempts; i++) {
        try {
            return await fn();
        } catch (e) {
            const status = e.status || 0;
            if ((status === 429 || status === 503) && i < maxAttempts - 1) {
                const wait = (i + 1) * 15;
                console.log(`  ⏳ ${name}: ${status} — retrying in ${wait}s (attempt ${i + 2}/${maxAttempts})`);
                await new Promise(r => setTimeout(r, wait * 1000));
            } else {
                console.log(`  ❌ ${name}: ${e.message?.substring(0, 120)}`);
                return false;
            }
        }
    }
}

// ── Run ──
console.log("=" .repeat(60));
console.log("Token Cap Fix Verification — gemini-2.5-flash");
console.log("=" .repeat(60));

const r1 = await withRetry(testFirstReading, "First Reading");
const r2 = await withRetry(testHouseInterpretations, "House Interpretations");

console.log("\n" + "=".repeat(60));
console.log(r1 && r2 ? "✅ ALL TESTS PASSED" : "❌ SOME TESTS FAILED");
console.log("=".repeat(60));

process.exit(r1 && r2 ? 0 : 1);
