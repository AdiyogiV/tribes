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

/**
 * Verify a Firebase ID token. Returns the decoded uid, or null if the token is
 * missing/invalid. When REQUIRE_AUTH is off (local dev) we skip verification.
 */
async function verifyCaller(token) {
    if (!REQUIRE_AUTH) return token ? "dev-bypass" : "anon-dev";
    if (!token) return null;
    try {
        const decoded = await admin.auth().verifyIdToken(token);
        return decoded.uid;
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

const wss = new WebSocketServer({ server, path: "/voice" });

wss.on("connection", (ws) => {
    let session = null;

    const sendJson = (obj) => {
        if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
    };

    const openSession = (sessionId, uid, idToken, engine, tools, directive) => {
        session = makeSession(sessionId || randomUUID(), uid, idToken, engine, tools, directive);

        session.on("transcript", (t) => sendJson({ type: "transcript", ...t }));
        session.on("reply", (r) => sendJson({ type: "reply", text: r.text }));
        session.on("audio", (buf) => {
            if (ws.readyState === ws.OPEN) ws.send(buf); // binary TTS chunk
        });
        session.on("turn_end", () => sendJson({ type: "speaking_done" }));
        // Baba wants to act: forward the tool call so the client can run it.
        session.on("tool_call", (call) => sendJson({ type: "tool_call", ...call }));
        // Barge-in: user cut in while Aurobhatt was speaking. Tell the client to
        // flush whatever it has buffered and stop playing immediately.
        session.on("interrupt", () => sendJson({ type: "interrupt" }));
        session.on("error", (err) => {
            // Log server-side so failures show up in Cloud Run logs, not just
            // as an opaque {type:"error"} on the client.
            // eslint-disable-next-line no-console
            console.error(`[session ${sessionId}] error:`, err?.stack || err);
            sendJson({ type: "error", message: String(err?.message || err) });
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
        if (msg.type === "start") {
            if (session) return; // already started
            // Verify the caller before spending any Gen AI credits.
            verifyCaller(msg.token).then((uid) => {
                if (!uid) {
                    sendJson({ type: "error", message: "unauthorized" });
                    try { ws.close(4401, "unauthorized"); } catch { /* closing */ }
                    return;
                }
                // Bind the session to the user and forward their ID token so
                // the brain (aiChat) can load their full chart from Firestore.
                // `engine` (optional) lets the app pick Live vs CX per session.
                openSession(msg.sessionId || uid, uid, msg.token, msg.engine, msg.tools, msg.directive);
            });
        } else if (msg.type === "tool_response") {
            // Client ran a tool Baba requested; hand the result back to Gemini.
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
            if (session && typeof session.injectContext === "function") {
                session.injectContext(msg.text, msg.speak !== false);
            }
        } else if (msg.type === "stop") {
            session?.end();
            session = null;
        }
    });

    ws.on("close", () => {
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
