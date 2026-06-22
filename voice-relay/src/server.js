/**
 * Aryabhatt Voice Relay — Cloud Run entrypoint.
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
import { MultilingualVoiceSession } from "./voice_pipeline.js";

// Pick the engine: multilingual pipeline (STT v2 + our TTS) or the original
// single-language CX streaming. Toggle with MULTILINGUAL=false.
const makeSession = (sessionId, uid, idToken) =>
    CONFIG.multilingual
        ? new MultilingualVoiceSession(sessionId, uid, idToken)
        : new CxVoiceSession(sessionId);

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

    const openSession = (sessionId, uid, idToken) => {
        session = makeSession(sessionId || randomUUID(), uid, idToken);

        session.on("transcript", (t) => sendJson({ type: "transcript", ...t }));
        session.on("reply", (r) => sendJson({ type: "reply", text: r.text }));
        session.on("audio", (buf) => {
            if (ws.readyState === ws.OPEN) ws.send(buf); // binary TTS chunk
        });
        session.on("turn_end", () => sendJson({ type: "speaking_done" }));
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
                openSession(msg.sessionId || uid, uid, msg.token);
            });
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
        `voice-relay listening on :${CONFIG.port} -> CX agent ${CONFIG.agentId} `
        + `(${CONFIG.location}/${CONFIG.environment}) `
        + (CONFIG.multilingual
            ? `[multilingual: STT ${CONFIG.sttModel}@${CONFIG.sttLocation} `
              + `auto-detect, TTS ${CONFIG.ttsGender}]`
            : `[single-language ${CONFIG.languageCode}]`),
    );
});
