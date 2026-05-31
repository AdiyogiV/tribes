#!/usr/bin/env node
/**
 * One-time backfill: populate 365 days of positions + panchang + muhurat
 * in Firestore (global_astro/sky_positions).
 *
 * Uses Firestore REST API + gcloud access token — no firebase-admin needed.
 * Runs locally with no timeout limits.
 *
 * Usage:
 *   node backfill-astro-365.mjs                         # dry-run (shows gaps)
 *   node backfill-astro-365.mjs --run                    # fetch & write
 *   node backfill-astro-365.mjs --run --concurrency=5    # faster parallel fetches
 */

import { execSync } from "child_process";

// ─── Config ──────────────────────────────────────────────────────────────────
const API_BASE = "https://json.freeastrologyapi.com";
const API_KEY = process.env.ASTRO_API_KEY || "6BdMjydKb81OU3mKbuPPB23ueB7XAhg02jbxDAXQ";
const PROJECT_ID = "ty-dev-516d7";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const DOC_PATH = "global_astro/sky_positions";
const DAYS_AHEAD = 365;

// Ujjain reference (same as sky_positions.js)
const DEFAULT_LAT = 23.1765;
const DEFAULT_LNG = 75.7885;
const DEFAULT_TZ = 5.5;

const TRACKED_PLANETS = [
    "Sun", "Moon", "Mars", "Mercury", "Jupiter",
    "Venus", "Saturn", "Rahu", "Ketu", "Uranus", "Neptune", "Pluto",
];

// ─── CLI args ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const DRY_RUN = !args.includes("--run");
const concurrencyArg = args.find(a => a.startsWith("--concurrency="));
const CONCURRENCY = concurrencyArg ? parseInt(concurrencyArg.split("=")[1], 10) : 3;
const THROTTLE_MS = 120;

// ─── Auth ────────────────────────────────────────────────────────────────────
function getAccessToken() {
    return execSync("gcloud auth print-access-token", { encoding: "utf-8" }).trim();
}

let accessToken = getAccessToken();

// Refresh token every 30 minutes (tokens last 60 min)
const TOKEN_REFRESH_MS = 30 * 60 * 1000;
let lastTokenTime = Date.now();
function freshToken() {
    if (Date.now() - lastTokenTime > TOKEN_REFRESH_MS) {
        accessToken = getAccessToken();
        lastTokenTime = Date.now();
        console.log("   🔑 Access token refreshed");
    }
    return accessToken;
}

// ─── Firestore REST helpers ──────────────────────────────────────────────────

/** Read the full sky_positions document from Firestore REST API. */
async function firestoreRead() {
    const res = await fetch(`${FIRESTORE_BASE}/${DOC_PATH}`, {
        headers: { Authorization: `Bearer ${freshToken()}` },
    });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`Firestore read ${res.status}: ${await res.text()}`);
    const doc = await res.json();
    return firestoreDocToJs(doc.fields || {});
}

/** Write the full document back via Firestore REST API (PATCH = upsert). */
async function firestoreWrite(data) {
    const firestoreFields = jsToFirestoreFields(data);
    const res = await fetch(`${FIRESTORE_BASE}/${DOC_PATH}`, {
        method: "PATCH",
        headers: {
            Authorization: `Bearer ${freshToken()}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ fields: firestoreFields }),
    });
    if (!res.ok) throw new Error(`Firestore write ${res.status}: ${await res.text()}`);
    return res.json();
}

/** Convert Firestore REST document fields → plain JS object. */
function firestoreDocToJs(fields) {
    const result = {};
    for (const [key, value] of Object.entries(fields)) {
        result[key] = firestoreValueToJs(value);
    }
    return result;
}

function firestoreValueToJs(value) {
    if (value.stringValue !== undefined) return value.stringValue;
    if (value.integerValue !== undefined) return Number(value.integerValue);
    if (value.doubleValue !== undefined) return value.doubleValue;
    if (value.booleanValue !== undefined) return value.booleanValue;
    if (value.nullValue !== undefined) return null;
    if (value.timestampValue !== undefined) return value.timestampValue;
    if (value.mapValue) return firestoreDocToJs(value.mapValue.fields || {});
    if (value.arrayValue) return (value.arrayValue.values || []).map(firestoreValueToJs);
    return null;
}

/** Convert plain JS object → Firestore REST fields format. */
function jsToFirestoreFields(obj) {
    const fields = {};
    for (const [key, value] of Object.entries(obj)) {
        const fv = jsToFirestoreValue(value);
        if (fv) fields[key] = fv;
    }
    return fields;
}

function jsToFirestoreValue(value) {
    if (value === null || value === undefined) return { nullValue: null };
    if (typeof value === "string") return { stringValue: value };
    if (typeof value === "boolean") return { booleanValue: value };
    if (typeof value === "number") {
        return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
    }
    if (Array.isArray(value)) {
        return { arrayValue: { values: value.map(jsToFirestoreValue).filter(Boolean) } };
    }
    if (typeof value === "object") {
        return { mapValue: { fields: jsToFirestoreFields(value) } };
    }
    return null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function dateKey(d) { return d.toISOString().split("T")[0]; }

function addDays(d, n) {
    const r = new Date(d);
    r.setUTCDate(r.getUTCDate() + n);
    return r;
}

function makePayload(date) {
    return {
        year: date.getUTCFullYear(),
        month: date.getUTCMonth() + 1,
        date: date.getUTCDate(),
        hours: 6, minutes: 0, seconds: 0,  // sunrise at Ujjain (~6 AM IST)
        latitude: DEFAULT_LAT, longitude: DEFAULT_LNG, timezone: DEFAULT_TZ,
        config: { observation_point: "geocentric", ayanamsha: "lahiri" },
    };
}

async function apiPost(endpoint, payload) {
    const res = await fetch(`${API_BASE}${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-api-key": API_KEY },
        body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(`${endpoint} ${res.status}: ${await res.text()}`);
    return res.json();
}

function extractApiOutput(response) {
    if (!response) return null;
    if (typeof response === "object" && !Array.isArray(response)) {
        if (response.output !== undefined) {
            const o = response.output;
            if (typeof o === "string") { try { return JSON.parse(o); } catch { return o; } }
            return o;
        }
        return response;
    }
    return response;
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ─── API fetch functions (mirrors sky_positions.js) ──────────────────────────

async function fetchPositions(date) {
    const raw = await apiPost("/planets", makePayload(date));
    const output = raw?.output;
    if (!output) return null;
    const planets = {};
    const planetsObj = Array.isArray(output) ? output[0] : output;
    for (const [key, data] of Object.entries(planetsObj)) {
        if (!data || typeof data !== "object") continue;
        const name = data.name || key;
        const planetName = TRACKED_PLANETS.find(p => name.includes(p) || key.includes(p));
        if (!planetName) continue;
        planets[planetName] = {
            longitude: data.fullDegree || data.longitude || data.full_degree,
            sign: data.sign || data.Sign,
            signDegree: data.normDegree || data.degree || (data.fullDegree ? data.fullDegree % 30 : null),
            isRetro: data.isRetro === true || data.is_retro === true,
            nakshatra: data.nakshatra || data.Nakshatra,
        };
    }
    return Object.keys(planets).length > 0 ? planets : null;
}

function parseApiTimeString(raw) {
    if (!raw) return null;
    if (typeof raw === "object") {
        return { starts_at: raw.start || raw.starts_at || raw.startsAt || null, ends_at: raw.end || raw.ends_at || raw.endsAt || null };
    }
    if (typeof raw === "string") {
        const parts = raw.split(/\s*[-–—to]+\s*/i);
        if (parts.length >= 2) return { starts_at: parts[0].trim(), ends_at: parts[1].trim() };
        return { starts_at: raw.trim(), ends_at: null };
    }
    return null;
}

async function fetchPanchang(date) {
    const payload = makePayload(date);
    const [samvatRes, lunarRes, tithiRes] = await Promise.all([
        apiPost("/samvatinfo", payload),
        apiPost("/lunarmonthinfo", payload),
        apiPost("/tithi-durations", payload),
    ]);
    const samvat = extractApiOutput(samvatRes) || {};
    const lunar = extractApiOutput(lunarRes) || {};
    const tithiRaw = extractApiOutput(tithiRes) || {};
    const tithi = (tithiRaw.tithi && typeof tithiRaw.tithi === "object") ? tithiRaw.tithi : tithiRaw;
    const tithiNum = tithi.number || tithi.tithi_number;
    const panchang = {
        vikram_chaitradi_number: samvat.vikram_chaitradi_number || samvat.vikramChaitradiNumber,
        vikram_chaitradi_year_name: samvat.vikram_chaitradi_year_name || samvat.vikramChaitradiYearName,
        saka_salivahana_number: samvat.saka_salivahana_number || samvat.sakaSalivahanaNumber,
        lunar_month_name: lunar.lunar_month_name || lunar.lunarMonthName,
        lunar_month_full_name: lunar.lunar_month_full_name || lunar.lunarMonthFullName,
        name: tithi.name || tithi.tithi_name || tithi.tithiName,
        number: tithiNum,
        tithi_number: tithiNum,
        paksha: tithi.paksha || tithi.tithi_paksha || tithi.tithiPaksha,
        karana: samvat.karana || samvat.Karana,
        yoga: samvat.yoga || samvat.Yoga,
        nakshatra: samvat.nakshatra || samvat.Nakshatra,
    };
    for (const k of Object.keys(panchang)) {
        if (panchang[k] === undefined || panchang[k] === null || panchang[k] === "") delete panchang[k];
    }
    return Object.keys(panchang).length > 0 ? panchang : null;
}

function parseMuhuratDay(parsed) {
    const day = {};
    if (parsed.sunrise) day.sunrise = parsed.sunrise;
    if (parsed.sunset) day.sunset = parsed.sunset;
    if (parsed.rahu_kaalam_data)    day.rahuKala = parseApiTimeString(parsed.rahu_kaalam_data);
    if (parsed.gulika_kalam_data)   day.gulikaKala = parseApiTimeString(parsed.gulika_kalam_data);
    if (parsed.yama_gandam_data)    day.yamaganda = parseApiTimeString(parsed.yama_gandam_data);
    if (parsed.varjyam_data)        day.varjyam = parseApiTimeString(parsed.varjyam_data);
    if (parsed.abhijit_data)        day.abhijit = parseApiTimeString(parsed.abhijit_data);
    if (parsed.amrit_kaal_data)     day.amrit = parseApiTimeString(parsed.amrit_kaal_data);
    if (parsed.brahma_muhurat_data) day.brahmaMuhurat = parseApiTimeString(parsed.brahma_muhurat_data);
    if (parsed.dur_muhurat_data)    day.durMuhurat = parseApiTimeString(parsed.dur_muhurat_data);
    return day;
}

async function fetchMuhurat(date) {
    const raw = await apiPost("/good-bad-times", makePayload(date));
    const parsed = extractApiOutput(raw);
    if (!parsed) return null;
    return parseMuhuratDay(parsed);
}

// ─── Fetch all 3 data types for one date ─────────────────────────────────────

async function fetchDate(date, needs) {
    const key = dateKey(date);
    const result = { key, positions: null, panchang: null, muhurat: null, errors: [] };

    if (needs.position) {
        try { result.positions = await fetchPositions(date); await sleep(THROTTLE_MS); }
        catch (e) { result.errors.push(`pos: ${e.message}`); }
    }
    if (needs.panchang) {
        try { result.panchang = await fetchPanchang(date); await sleep(THROTTLE_MS); }
        catch (e) { result.errors.push(`pan: ${e.message}`); }
    }
    if (needs.muhurat) {
        try { result.muhurat = await fetchMuhurat(date); await sleep(THROTTLE_MS); }
        catch (e) { result.errors.push(`muh: ${e.message}`); }
    }
    return result;
}

// ─── Chunked parallel runner ─────────────────────────────────────────────────

async function runInChunks(items, concurrency, fn) {
    const results = [];
    for (let i = 0; i < items.length; i += concurrency) {
        const chunk = items.slice(i, i + concurrency);
        results.push(...await Promise.all(chunk.map(fn)));
    }
    return results;
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
    console.log(`\n🔮 Astro 365-day backfill (${DRY_RUN ? "DRY RUN" : "LIVE"}, concurrency=${CONCURRENCY})\n`);

    // 1. Read existing data from Firestore
    console.log("📖 Reading existing Firestore data...");
    const existing = (await firestoreRead()) || {};
    const existingPositions = existing.positions || {};
    const existingPanchang = existing.panchang || {};
    const existingMuhurat = existing.muhurat || {};

    console.log(`   Existing: ${Object.keys(existingPositions).length} positions, ` +
        `${Object.keys(existingPanchang).length} panchang, ` +
        `${Object.keys(existingMuhurat).length} muhurat\n`);

    // 2. Build required date range (today → today+365)
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const requiredDates = [];
    for (let i = 0; i <= DAYS_AHEAD; i++) requiredDates.push(addDays(today, i));

    // 3. Find gaps
    const fetchList = [];
    for (const d of requiredDates) {
        const k = dateKey(d);
        const needsPos = !existingPositions[k] || (typeof existingPositions[k] === "object" && Object.keys(existingPositions[k]).length === 0);
        const needsPan = !existingPanchang[k] || (typeof existingPanchang[k] === "object" && Object.keys(existingPanchang[k]).length === 0);
        const needsMuh = !existingMuhurat[k] || (typeof existingMuhurat[k] === "object" && Object.keys(existingMuhurat[k]).length === 0);
        if (needsPos || needsPan || needsMuh) {
            fetchList.push({ date: d, needs: { position: needsPos, panchang: needsPan, muhurat: needsMuh } });
        }
    }

    const totalApiCalls = fetchList.reduce((sum, item) =>
        sum + (item.needs.position ? 1 : 0) + (item.needs.panchang ? 3 : 0) + (item.needs.muhurat ? 1 : 0), 0);

    console.log(`📊 Gaps found: ${fetchList.length} dates need data (${totalApiCalls} API calls)`);
    if (fetchList.length > 0) {
        const b = { pos: fetchList.filter(f => f.needs.position).length, pan: fetchList.filter(f => f.needs.panchang).length, muh: fetchList.filter(f => f.needs.muhurat).length };
        console.log(`   Breakdown: ${b.pos} positions, ${b.pan} panchang, ${b.muh} muhurat`);
        console.log(`   Date range: ${dateKey(fetchList[0].date)} → ${dateKey(fetchList[fetchList.length - 1].date)}\n`);
    }

    if (fetchList.length === 0) {
        console.log("✅ All 365 days already populated! Nothing to do.\n");
        process.exit(0);
    }

    if (DRY_RUN) {
        console.log("🏜️  Dry run — add --run to actually fetch & write.\n");
        process.exit(0);
    }

    // 4. Fetch everything from the API
    const startTime = Date.now();
    let completed = 0;
    let errors = 0;

    const newPositions = { ...existingPositions };
    const newPanchang = { ...existingPanchang };
    const newMuhurat = { ...existingMuhurat };

    const results = await runInChunks(fetchList, CONCURRENCY, async (item) => {
        const result = await fetchDate(item.date, item.needs);
        completed++;
        if (result.errors.length > 0) {
            errors += result.errors.length;
            console.log(`   ⚠️  ${result.key}: ${result.errors.join(", ")}`);
        }
        if (completed % 10 === 0 || completed === fetchList.length) {
            const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
            console.log(`   📡 ${completed}/${fetchList.length} (${elapsed}s)`);
        }
        return result;
    });

    // 5. Merge results
    for (const r of results) {
        if (r.positions) newPositions[r.key] = r.positions;
        if (r.panchang) newPanchang[r.key] = r.panchang;
        if (r.muhurat) newMuhurat[r.key] = r.muhurat;
    }

    // 6. Write to Firestore
    const sortedDates = Object.keys(newPositions).sort();
    const panchangDays = Object.keys(newPanchang).length;
    const muhuratDays = Object.keys(newMuhurat).length;

    console.log(`\n💾 Writing to Firestore...`);
    console.log(`   ${sortedDates.length} positions, ${panchangDays} panchang, ${muhuratDays} muhurat`);

    await firestoreWrite({
        positions: newPositions,
        panchang: newPanchang,
        muhurat: newMuhurat,
        lastUpdated: new Date().toISOString(),
        lastFetchedDate: sortedDates[sortedDates.length - 1] || "",
        dateRange: {
            from: sortedDates[0] || "",
            to: sortedDates[sortedDates.length - 1] || "",
        },
        stats: {
            totalDays: sortedDates.length,
            panchangDays,
            muhuratDays,
            lastBackfill: new Date().toISOString(),
            lastBackfillCount: fetchList.length,
            lastBackfillErrors: errors,
        },
    });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n✅ Backfill complete in ${elapsed}s`);
    console.log(`   Fetched: ${fetchList.length} dates, ${errors} errors`);
    console.log(`   Firestore: ${sortedDates.length} positions, ${panchangDays} panchang, ${muhuratDays} muhurat`);
    console.log(`   Range: ${sortedDates[0]} → ${sortedDates[sortedDates.length - 1]}\n`);
}

main().catch((err) => {
    console.error("❌ Fatal error:", err);
    process.exit(1);
});
