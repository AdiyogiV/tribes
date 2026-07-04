/**
 * user_memory.js — durable, evolving per-user memory for HolyCow.
 *
 * THE PROBLEM IT SOLVES
 * Chat history is per-conversation and capped (MAX_HISTORY_MESSAGES). Every new
 * conversation starts from a blank slate, so HolyCow forgets everything the user
 * told it last week. That amnesia is the #1 reason engaged users (see Mishthi)
 * churn — they re-explain their life every time and never feel known.
 *
 * THE DESIGN (deliberately simple — see decision notes in repo)
 * One small doc per user at users/{uid}/memory/profile holding:
 *   - rollingSummary: 1-3 sentence portrait of who they are + what they navigate
 *   - threads:        their ongoing life concerns ({topic, note, status})
 * Updated NIGHTLY (not inline) for users who chatted since the last run, so it
 * stays off the chat critical path. Read once per chat request in ai.js and
 * injected into the system prompt, so every session opens with continuity.
 *
 * No vector DB, no embeddings, no RAG. One read, one write/day/active-user.
 */

import { db, FieldValue, logger } from "../lib/firebase.js";
import { callGemini } from "../lib/gemini.js";

const HOLYCOW_USER_ID = "holycow_system_user";
const MEMORY_DOC_PATH = (uid) => `users/${uid}/memory/profile`;

// Tuning knobs (kept here so they're easy to find/adjust).
const MAX_CONVERSATIONS_PER_USER = 4;   // most-recent AI conversations to read
const MAX_MESSAGES_PER_USER = 60;       // cap messages fed to the model
const MAX_THREADS = 8;                   // memory stays bounded forever
const THREAD_TTL_DAYS = 60;              // decay: drop threads untouched this long
const REFRESH_LOOKBACK_HOURS = 26;       // catch everything since last nightly run
const MAX_USERS_PER_RUN = 250;           // safety ceiling per nightly run
const REFRESH_CONCURRENCY = 4;           // gentle on Gemini rate limits

// =============================================================================
// PROMPT
// =============================================================================

const MEMORY_SYSTEM_PROMPT = [
    "You maintain a compact, evolving MEMORY PROFILE of a user of HolyCow, an",
    "astrology + wellness companion app. Given the PRIOR MEMORY and the user's",
    "RECENT MESSAGES, return an UPDATED memory profile as strict JSON.",
    "",
    "The RECENT MESSAGES are the USER'S OWN words only (Aryabhatt's replies are",
    "deliberately excluded). Treat every line as something the USER said about",
    "themselves. NEVER record astrological claims, predictions, or advice as facts",
    "about the user — only what they actually told you about their own life.",
    "",
    "WHAT TO CAPTURE (durable life facts only):",
    "- Who they are: age, location, work/study, life stage when stated.",
    "- Their ongoing concerns as 'threads': career, relationships, money, health,",
    "  family, education, life-direction. Each thread = {topic, note, status}.",
    "- Goals and decisions in progress (e.g. 'considering a new job', 'wants to",
    "  learn investing', 'deciding whether to move cities').",
    "",
    "RULES:",
    "- MERGE new facts into the prior memory. Don't lose still-true context.",
    "- Only record what the USER stated. Never infer facts from advice given to them.",
    "- status is 'open' while unresolved, 'resolved' once the user settles it.",
    "- Keep at most " + MAX_THREADS + " threads; merge or drop the least relevant",
    "  (prefer dropping old 'resolved' ones).",
    "- rollingSummary: 1-3 plain sentences — who they are + what they're navigating.",
    "- IGNORE greetings, one-off trivia, and HolyCow's own replies.",
    "- Write notes the way a thoughtful friend would remember them. NO astrology",
    "  jargon, no planets/houses/dashas. Plain, factual, concise.",
    "",
    "OUTPUT: ONLY valid JSON, no prose, no code fences:",
    '{"rollingSummary":"...","threads":[{"topic":"career","note":"...","status":"open"}]}',
].join("\n");

function buildMemoryUserPrompt(priorMemory, messages) {
    const prior = priorMemory
        ? JSON.stringify({ rollingSummary: priorMemory.rollingSummary || "", threads: priorMemory.threads || [] }, null, 2)
        : "(none yet — this is the first memory for this user)";

    // Provenance: feed the USER'S OWN messages only. Including Aryabhatt's
    // replies here let his astrological speculation leak in as "user facts" —
    // the root of the "misunderstands context" bug. The model can't absorb
    // what it never sees.
    const transcript = messages
        .filter((m) => m.role === "user")
        .map((m) => `U: ${m.content}`)
        .join("\n");

    return [
        "PRIOR MEMORY:",
        prior,
        "",
        "RECENT MESSAGES (oldest first; the USER'S own words only):",
        transcript,
    ].join("\n");
}

// =============================================================================
// READ: gather a user's recent AI messages
// =============================================================================

/**
 * Pull the user's most recent AI chat messages across their recent
 * conversations, oldest-first, capped. Returns [] if none.
 */
async function gatherRecentMessages(uid) {
    // array-contains only (no orderBy) so no composite index is required; a user
    // has few conversations, so we sort by recency in memory.
    const convSnap = await db.collection("dmConversations")
        .where("participants", "array-contains", uid)
        .get();

    const aiConvos = convSnap.docs
        .filter((d) => {
            const c = d.data();
            return c.isAiConversation === true ||
                (Array.isArray(c.participants) && c.participants.includes(HOLYCOW_USER_ID));
        })
        .sort((a, b) => {
            const am = a.data().lastActivity?.toMillis ? a.data().lastActivity.toMillis() : 0;
            const bm = b.data().lastActivity?.toMillis ? b.data().lastActivity.toMillis() : 0;
            return bm - am;
        })
        .slice(0, MAX_CONVERSATIONS_PER_USER);

    const all = [];
    for (const c of aiConvos) {
        const msgs = await db.collection("dmConversations").doc(c.id)
            .collection("messages").orderBy("timestamp").get();
        msgs.docs.forEach((m) => {
            const x = m.data();
            const content = (x.content || "").trim();
            if (!content) return;
            all.push({
                role: x.senderId === HOLYCOW_USER_ID ? "assistant" : "user",
                content,
                ts: x.timestamp?.toMillis ? x.timestamp.toMillis() : 0,
            });
        });
    }

    all.sort((a, b) => a.ts - b.ts);
    // Keep the most recent slice, but preserve chronological order.
    return all.slice(-MAX_MESSAGES_PER_USER);
}

// =============================================================================
// WRITE: build/refresh one user's memory
// =============================================================================

/**
 * Refresh a single user's memory profile from their recent AI chats.
 * Safe to call repeatedly — it merges into the existing memory.
 * @returns {Promise<{uid:string, updated:boolean, reason?:string}>}
 */
export async function updateUserMemory(uid, sinceActivityMs = 0) {
    try {
        // Read the (cheap) memory doc FIRST so we can pre-gate before paying for
        // the message gather (1 query + up to 4 subcollection reads).
        const priorSnap = await db.doc(MEMORY_DOC_PATH(uid)).get();
        const prior = priorSnap.exists ? priorSnap.data() : null;

        // Pre-gate: if memory was last refreshed at/after the newest known
        // conversation activity, nothing new happened — skip gather AND Gemini.
        const priorUpdatedMs = prior?.lastUpdated?.toMillis ? prior.lastUpdated.toMillis() : 0;
        if (sinceActivityMs && priorUpdatedMs && priorUpdatedMs >= sinceActivityMs) {
            return { uid, updated: false, reason: "no_new_activity" };
        }

        const messages = await gatherRecentMessages(uid);
        const userTurns = messages.filter((m) => m.role === "user").length;
        if (userTurns < 2) {
            return { uid, updated: false, reason: "too_few_user_messages" };
        }

        // Backstop gate: even if activity timestamps slipped through, skip the
        // Gemini call when no new MESSAGE arrived since the last refresh.
        const newestTs = messages.reduce((mx, m) => Math.max(mx, m.ts || 0), 0);
        if (prior?.lastSourceMessageTs && newestTs <= prior.lastSourceMessageTs) {
            return { uid, updated: false, reason: "no_new_messages" };
        }

        const { json } = await callGemini({
            systemPrompt: MEMORY_SYSTEM_PROMPT,
            userPrompt: buildMemoryUserPrompt(prior, messages),
            temperature: 0.3,
            maxOutputTokens: 2048,
            expectJson: true,
            flavorName: "user_memory",
        });

        if (!json || typeof json.rollingSummary !== "string") {
            return { uid, updated: false, reason: "unparseable_memory" };
        }

        const rawThreads = Array.isArray(json.threads)
            ? json.threads
                .filter((t) => t && t.topic && t.note)
                .map((t) => ({
                    topic: String(t.topic),
                    note: String(t.note),
                    status: t.status === "resolved" ? "resolved" : "open",
                }))
            : [];

        // Light decay: carry forward each thread's updatedAt when it's unchanged,
        // otherwise stamp it now. Then drop anything untouched past the TTL and
        // keep only the most-recently-touched MAX_THREADS. This stops stale
        // concerns from lingering forever and conflating with current life.
        const threads = applyThreadDecay(rawThreads, prior?.threads || []);

        await db.doc(MEMORY_DOC_PATH(uid)).set({
            rollingSummary: json.rollingSummary.trim(),
            threads,
            lastUpdated: FieldValue.serverTimestamp(),
            lastSourceMessageTs: newestTs,
            version: (prior?.version || 0) + 1,
            sourceMessageCount: messages.length,
        }, { merge: true });

        return { uid, updated: true };
    } catch (err) {
        logger.warn("updateUserMemory failed (non-fatal)", {
            structuredData: true, uid, error: String(err?.message || err),
        });
        return { uid, updated: false, reason: "error" };
    }
}

/**
 * Merge freshly-extracted threads with their prior timestamps, expire stale
 * ones, and cap to MAX_THREADS by recency. Pure function — easy to reason about.
 * @param {Array<{topic,note,status}>} rawThreads - this run's extraction
 * @param {Array<{topic,note,status,updatedAt?}>} priorThreads - stored memory
 * @returns {Array<{topic,note,status,updatedAt}>}
 */
function applyThreadDecay(rawThreads, priorThreads) {
    const now = Date.now();
    const ttlMs = THREAD_TTL_DAYS * 24 * 60 * 60 * 1000;
    const priorByTopic = new Map(
        priorThreads.map((t) => [String(t.topic).toLowerCase(), t]),
    );

    return rawThreads
        .map((t) => {
            const p = priorByTopic.get(t.topic.toLowerCase());
            const unchanged = p && p.note === t.note && p.status === t.status;
            return {
                ...t,
                updatedAt: unchanged && p.updatedAt ? p.updatedAt : now,
            };
        })
        .filter((t) => now - (t.updatedAt || now) <= ttlMs)
        .sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0))
        .slice(0, MAX_THREADS);
}

/**
 * Clear a user's durable memory entirely (the "forget me" button). Deletes the
 * single memory/profile doc so the next chat opens with a blank slate. Routed
 * through socialGateway as method 'clearAiMemory' (auth required).
 * @returns {Promise<{cleared:boolean}>}
 */
export async function handleClearUserMemory(request) {
    const uid = request.auth?.uid;
    await db.doc(MEMORY_DOC_PATH(uid)).delete();
    logger.info("clearAiMemory", { structuredData: true, uid });
    return { cleared: true };
}

// =============================================================================
// ORCHESTRATOR RUNNER: refresh everyone who chatted recently
// =============================================================================

/**
 * Find users who had AI chat activity in the last REFRESH_LOOKBACK_HOURS and
 * refresh their memory. Plugged into unifiedOrchestrator (nightly).
 */
export async function runRefreshUserMemories() {
    const start = Date.now();
    const cutoff = new Date(Date.now() - REFRESH_LOOKBACK_HOURS * 60 * 60 * 1000);

    // Single-field range + orderBy on the same field → no composite index needed.
    const snap = await db.collection("dmConversations")
        .where("lastActivity", ">=", cutoff)
        .orderBy("lastActivity", "desc")
        .limit(1000)
        .get();

    // Collect unique human uids + their newest AI-conversation activity, so
    // updateUserMemory can pre-gate (skip users whose memory already covers
    // their latest activity) without paying for the message gather.
    const activityByUid = new Map();
    snap.docs.forEach((d) => {
        const c = d.data();
        const isAi = c.isAiConversation === true ||
            (Array.isArray(c.participants) && c.participants.includes(HOLYCOW_USER_ID));
        if (!isAi) return;
        const actMs = c.lastActivity?.toMillis ? c.lastActivity.toMillis() : 0;
        (c.participants || []).forEach((p) => {
            if (p && p !== HOLYCOW_USER_ID) {
                activityByUid.set(p, Math.max(activityByUid.get(p) || 0, actMs));
            }
        });
    });

    const targets = [...activityByUid.keys()].slice(0, MAX_USERS_PER_RUN);
    logger.info("runRefreshUserMemories: starting", {
        structuredData: true,
        recentAiConversations: snap.size,
        uniqueUsers: activityByUid.size,
        processing: targets.length,
    });

    // Bounded-concurrency pool.
    let updated = 0, skipped = 0, idx = 0;
    async function worker() {
        while (idx < targets.length) {
            const uid = targets[idx++];
            const r = await updateUserMemory(uid, activityByUid.get(uid) || 0);
            if (r.updated) updated++; else skipped++;
        }
    }
    await Promise.all(
        Array.from({ length: Math.min(REFRESH_CONCURRENCY, targets.length) }, worker),
    );

    const summary = {
        durationMs: Date.now() - start,
        processed: targets.length,
        updated,
        skipped,
    };
    logger.info("runRefreshUserMemories: complete", { structuredData: true, ...summary });
    return summary;
}

// =============================================================================
// READ HELPER: load memory for injection into the chat prompt
// =============================================================================

/**
 * Load a user's memory profile. Returns null if none yet (graceful — chat still
 * works without it). Shape: { rollingSummary, threads:[{topic,note,status}] }.
 */
export async function getUserMemory(uid) {
    try {
        const snap = await db.doc(MEMORY_DOC_PATH(uid)).get();
        if (!snap.exists) return null;
        const d = snap.data();
        if (!d.rollingSummary && !(d.threads || []).length) return null;
        return { rollingSummary: d.rollingSummary || "", threads: d.threads || [] };
    } catch (err) {
        logger.warn("getUserMemory failed (non-fatal)", {
            structuredData: true, uid, error: String(err?.message || err),
        });
        return null;
    }
}
