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
import { callGemini } from "../insights/engine/ai_client.js";

const HOLYCOW_USER_ID = "holycow_system_user";
const MEMORY_DOC_PATH = (uid) => `users/${uid}/memory/profile`;

// Tuning knobs (kept here so they're easy to find/adjust).
const MAX_CONVERSATIONS_PER_USER = 4;   // most-recent AI conversations to read
const MAX_MESSAGES_PER_USER = 60;       // cap messages fed to the model
const MAX_THREADS = 8;                   // memory stays bounded forever
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
    "WHAT TO CAPTURE (durable life facts only):",
    "- Who they are: age, location, work/study, life stage when stated.",
    "- Their ongoing concerns as 'threads': career, relationships, money, health,",
    "  family, education, life-direction. Each thread = {topic, note, status}.",
    "- Goals and decisions in progress (e.g. 'considering a new job', 'wants to",
    "  learn investing', 'deciding whether to move cities').",
    "",
    "RULES:",
    "- MERGE new facts into the prior memory. Don't lose still-true context.",
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

    const transcript = messages
        .map((m) => `${m.role === "user" ? "U" : "H"}: ${m.content}`)
        .join("\n");

    return [
        "PRIOR MEMORY:",
        prior,
        "",
        "RECENT MESSAGES (oldest first; U = user, H = HolyCow):",
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
export async function updateUserMemory(uid) {
    try {
        const messages = await gatherRecentMessages(uid);
        const userTurns = messages.filter((m) => m.role === "user").length;
        if (userTurns < 2) {
            return { uid, updated: false, reason: "too_few_user_messages" };
        }

        const priorSnap = await db.doc(MEMORY_DOC_PATH(uid)).get();
        const prior = priorSnap.exists ? priorSnap.data() : null;

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

        const threads = Array.isArray(json.threads)
            ? json.threads
                .filter((t) => t && t.topic && t.note)
                .slice(0, MAX_THREADS)
                .map((t) => ({
                    topic: String(t.topic),
                    note: String(t.note),
                    status: t.status === "resolved" ? "resolved" : "open",
                }))
            : [];

        await db.doc(MEMORY_DOC_PATH(uid)).set({
            rollingSummary: json.rollingSummary.trim(),
            threads,
            lastUpdated: FieldValue.serverTimestamp(),
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

    // Collect unique human uids from recently-active AI conversations.
    const uids = new Set();
    snap.docs.forEach((d) => {
        const c = d.data();
        const isAi = c.isAiConversation === true ||
            (Array.isArray(c.participants) && c.participants.includes(HOLYCOW_USER_ID));
        if (!isAi) return;
        (c.participants || []).forEach((p) => {
            if (p && p !== HOLYCOW_USER_ID) uids.add(p);
        });
    });

    const targets = [...uids].slice(0, MAX_USERS_PER_RUN);
    logger.info("runRefreshUserMemories: starting", {
        structuredData: true,
        recentAiConversations: snap.size,
        uniqueUsers: uids.size,
        processing: targets.length,
    });

    // Bounded-concurrency pool.
    let updated = 0, skipped = 0, idx = 0;
    async function worker() {
        while (idx < targets.length) {
            const uid = targets[idx++];
            const r = await updateUserMemory(uid);
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
