/**
 * Aurobhatt Voice Relay — Cloud Run entrypoint.
 *
 * HTTP for health checks; a WebSocket at /voice for the live audio loop.
 * Each socket gets its own CxVoiceSession. We stay transport-thin: binary
 * frames are audio, JSON frames are control/events. See README for the protocol.
 */

import http from "node:http";
import { randomUUID } from "node:crypto";
import { WebSocketServer } from "ws";
import admin from "firebase-admin";
import { CONFIG } from "./config.js";
import { CxVoiceSession } from "./cx_stream.js";
import { LiveVoiceSession } from "./live_session.js";
import { withAuthoritativeAccount } from "./auth_directive.js";

// Pick the engine:
//   "cx"   -> Dialogflow CX streaming (production default; tool-calling +
//             trial-credit funded)
//   "live" -> Gemini Live API (native barge-in; PARKED until Vertex quota)
// Default comes from VOICE_ENGINE; the client may override PER SESSION by
// sending `engine` in its start frame (used by the in-app Live<->CX toggle).
const ALLOWED_ENGINES = new Set(["cx", "live"]);
const makeSession = (sessionId, uid, idToken, engine, tools, directive) => {
    const eng = ALLOWED_ENGINES.has(engine) ? engine : CONFIG.voiceEngine;
    switch (eng) {
        case "live":
            return new LiveVoiceSession(sessionId, uid, idToken, tools, directive);
        case "cx":
        default:
            return new CxVoiceSession(sessionId, tools, directive);
    }
};

// Firebase Admin verifies caller ID tokens. Uses ADC (the Cloud Run runtime
// service account) — no key file needed. Set REQUIRE_AUTH=false for local dev.
admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: CONFIG.project,
});
const REQUIRE_AUTH = (process.env.REQUIRE_AUTH || "true") !== "false";

// Never let an unhandled async error silently wedge or crash the process
// without a log line. Cloud Run restarts on a hard crash, but a swallowed
// rejection can leave the process limping — surface both.
process.on("unhandledRejection", (reason) => {
    // eslint-disable-next-line no-console
    console.error("[relay] unhandledRejection:", reason?.stack || reason);
});
process.on("uncaughtException", (err) => {
    // eslint-disable-next-line no-console
    console.error("[relay] uncaughtException:", err?.stack || err);
});

/**
 * Reduce an internal error to something safe to hand an untrusted client.
 * We keep the ONE signal the Flutter client self-heals on (a wedged CX session
 * awaiting a tool result) so its auto-heal still fires; everything else becomes
 * a generic message — the full detail stays in the server logs.
 */
function clientSafeError(err) {
    const raw = String(err?.message || err || "");
    if (raw.includes("waiting for tool call result") || raw.includes("INVALID_ARGUMENT")) {
        return raw.slice(0, 300);
    }
    return "voice service error";
}

/**
 * Verify a Firebase ID token. Returns decoded claims, or null if the token is
 * missing/invalid. The claims make auth type authoritative for session facts.
 */
async function verifyCaller(token) {
    if (!REQUIRE_AUTH) {
        return { uid: token ? "dev-bypass" : "anon-dev" };
    }
    if (!token) return null;
    try {
        return await admin.auth().verifyIdToken(token);
    } catch {
        return null;
    }
}

const server = http.createServer((req, res) => {
    // Health check for Cloud Run.
    if (req.url === "/" || req.url === "/healthz") {
        res.writeHead(200, { "content-type": "text/plain" });
        res.end("aryabhatt-voice-relay ok");
        return;
    }
    res.writeHead(404);
    res.end();
});

const wss = new WebSocketServer({
    server,
    path: "/voice",
    maxPayload: CONFIG.maxPayloadBytes, // reject oversized frames outright
});

// Count of live sockets, for the connection cap. A hard ceiling stops a flood
// from exhausting memory or spinning up unbounded paid CX/Live streams.
let liveConnections = 0;

// Heartbeat: ping every client on an interval and terminate any that missed
// the previous pong. This reaps dead TCP peers (mobile network drops) whose
// `close` never fires, so their session + CX gRPC stream can't leak forever.
const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
        if (ws.isAlive === false) {
            try { ws.terminate(); } catch { /* already gone */ }
            continue;
        }
        ws.isAlive = false;
        try { ws.ping(); } catch { /* closing */ }
    }
}, CONFIG.heartbeatMs);
wss.on("close", () => clearInterval(heartbeat));

wss.on("connection", (ws) => {
    // Enforce the connection cap before doing any work.
    if (liveConnections >= CONFIG.maxConnections) {
        try { ws.close(1013, "server busy"); } catch { /* closing */ }
        return;
    }
    liveConnections += 1;

    let session = null;
    let starting = false;  // synchronous guard against the double-start race
    let closed = false;
    // Per-connection throttle for billed `context` turns.
    let contextCount = 0;
    let contextWindowStart = Date.now();

    ws.isAlive = true;
    ws.on("pong", () => { ws.isAlive = true; });
    // A socket that never authenticates just consumes a slot — close it.
    let authTimer = setTimeout(() => {
        if (!session && !starting) {
            try { ws.close(4408, "no start"); } catch { /* closing */ }
        }
    }, CONFIG.authTimeoutMs);
    const clearAuthTimer = () => {
        if (authTimer) { clearTimeout(authTimer); authTimer = null; }
    };

    const sendJson = (obj) => {
        if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
    };

    const openSession = (sessionId, uid, idToken, engine, tools, directive) => {
        session = makeSession(sessionId || randomUUID(), uid, idToken, engine, tools, directive);

        session.on("transcript", (t) => sendJson({ type: "transcript", ...t }));
        session.on("reply", (r) => sendJson({ type: "reply", text: r.text }));
        session.on("audio", (buf) => {
            if (ws.readyState !== ws.OPEN) return;
            // Backpressure: a slow client can't keep up — drop this chunk rather
            // than buffer unbounded audio in the server's memory.
            if (ws.bufferedAmount > CONFIG.outboundBufferLimitBytes) return;
            ws.send(buf); // binary TTS chunk
        });
        session.on("turn_end", (turn = {}) =>
            sendJson({ type: "speaking_done", ...turn }));
        // Baba wants to act: forward the tool call so the client can run it.
        session.on("tool_call", (call) => sendJson({ type: "tool_call", ...call }));
        // Barge-in: user cut in while Aurobhatt was speaking. Tell the client to
        // flush whatever it has buffered and stop playing immediately.
        session.on("interrupt", () => sendJson({ type: "interrupt" }));
        session.on("error", (err) => {
            // Full detail server-side; only a safe summary to the untrusted client.
            // eslint-disable-next-line no-console
            console.error(`[session ${sessionId}] error:`, err?.stack || err);
            sendJson({ type: "error", message: clientSafeError(err) });
        });
        session.on("close", () => sendJson({ type: "session_closed" }));

        session.start();
        sendJson({ type: "ready" });
    };

    ws.on("message", (data, isBinary) => {
        if (isBinary) {
            // Raw PCM16 mic chunk from the client.
            if (session) session.sendAudio(data);
            return;
        }
        // JSON control message.
        let msg;
        try {
            msg = JSON.parse(data.toString());
        } catch {
            sendJson({ type: "error", message: "bad json control frame" });
            return;
        }
        if (!msg || typeof msg.type !== "string") return;
        if (msg.type === "start") {
            if (session || starting) return; // already started / starting
            starting = true;                 // set SYNCHRONOUSLY (race guard)
            clearAuthTimer();
            // Verify the caller before spending any Gen AI credits.
            verifyCaller(msg.token).then((caller) => {
                if (closed) { starting = false; return; }
                if (!caller?.uid) {
                    sendJson({ type: "error", message: "unauthorized" });
                    try { ws.close(4401, "unauthorized"); } catch { /* closing */ }
                    starting = false;
                    return;
                }
                // Token claims beat a stale pre-warmed client directive. This
                // is especially important after anonymous -> phone upgrades.
                const directive = withAuthoritativeAccount(msg.directive, caller);
                // Bind the session to the user and forward their ID token so
                // the brain (aiChat) can load their full chart from Firestore.
                // `engine` (optional) lets the app pick Live vs CX per session.
                openSession(msg.sessionId || caller.uid, caller.uid, msg.token,
                    msg.engine, msg.tools, directive);
                starting = false;
            }).catch((e) => {
                // eslint-disable-next-line no-console
                console.error("[relay] start failed:", e?.stack || e);
                sendJson({ type: "error", message: "voice service error" });
                starting = false;
                try { ws.close(1011, "start failed"); } catch { /* closing */ }
            });
        } else if (msg.type === "tool_response") {
            // Client ran a tool Baba requested; hand the result back to Gemini.
            if (typeof msg.id !== "string") return;
            if (session && typeof session.sendToolResponse === "function") {
                session.sendToolResponse([
                    { id: msg.id, name: msg.name, response: msg.response || {} },
                ]);
            }
        } else if (msg.type === "context") {
            // The client's UI changed under a LIVE call (e.g. onboarding walked
            // the user onto the chart reveal). Inject what's on screen so Baba
            // can react to it. `speak` (default true) => he narrates now; false
            // => silent awareness (Live only; CX always answers a text turn).
            if (typeof msg.text !== "string" || !msg.text.trim()) return;
            // Throttle: each context opens a billed CX turn — ignore floods.
            const now = Date.now();
            if (now - contextWindowStart > 60_000) { contextWindowStart = now; contextCount = 0; }
            contextCount += 1;
            if (contextCount > CONFIG.maxContextPerMinute) return;
            if (session && typeof session.injectContext === "function") {
                session.injectContext(msg.text, msg.speak !== false);
            }
        } else if (msg.type === "stop") {
            session?.end();
            session = null;
        }
    });

    // A socket-level error (e.g. abrupt reset) must not become an uncaught
    // exception; log and let the close handler clean up.
    ws.on("error", (err) => {
        // eslint-disable-next-line no-console
        console.error("[relay] socket error:", err?.message || err);
    });

    ws.on("close", () => {
        closed = true;
        clearAuthTimer();
        liveConnections = Math.max(0, liveConnections - 1);
        session?.end();
        session = null;
    });
});

server.listen(CONFIG.port, () => {
    // eslint-disable-next-line no-console
    console.log(
        `voice-relay listening on :${CONFIG.port} [engine: ${CONFIG.voiceEngine}] `
        + (CONFIG.voiceEngine === "live"
            ? `-> Gemini Live API ${CONFIG.live.model}@${CONFIG.live.location} `
              + `(voice ${CONFIG.live.voice}, ${CONFIG.live.languageCode || "auto-lang"}, native barge-in)`
            : `-> CX agent ${CONFIG.agentId} (${CONFIG.location}/${CONFIG.environment}) `
              + `[${CONFIG.languageCode}, voice ${CONFIG.voiceName}]`),
    );
});
