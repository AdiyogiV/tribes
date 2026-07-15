/**
 * Gemini Live API barge-in prototype.
 *
 * Goal: PROVE that Google's native Live API does interrupt/barge-in for us —
 * automatically, server-side, via built-in Voice Activity Detection — so we can
 * delete our custom Chirp-STT + interrupt-threshold machinery.
 *
 * What it does:
 *   1. Connects to the Live API (audio out).
 *   2. Asks Aurobhatt for a LONG answer so there's plenty to interrupt.
 *   3. Saves his speech to out.pcm (24kHz PCM16 mono — play to verify voice).
 *   4. If you pass a PCM16 16kHz mono file of YOU talking, it streams that in
 *      ~1.2s after he starts, and PRINTS the moment the server fires its
 *      `interrupted` signal + how many ms after we started sending audio.
 *      That latency is the number to compare against today's ~1-2s laggy hack.
 *
 * Run (AI Studio / API-key path — simplest):
 *   cd voice-relay
 *   npm i @google/genai
 *   GEMINI_API_KEY=xxxx node tools/live_proto.mjs              # audio-out only
 *   GEMINI_API_KEY=xxxx node tools/live_proto.mjs me16k.pcm   # + barge-in test
 *
 * Run (Vertex path — uses project IAM instead of a key):
 *   GOOGLE_GENAI_USE_VERTEXAI=true GOOGLE_CLOUD_PROJECT=ty-dev-516d7 \
 *   GOOGLE_CLOUD_LOCATION=us-central1 node tools/live_proto.mjs
 *
 * Make a test input clip (your voice, 16kHz mono PCM16) with ffmpeg:
 *   ffmpeg -i me.m4a -ac 1 -ar 16000 -f s16le me16k.pcm
 */

import { writeFileSync, readFileSync, existsSync } from "node:fs";
import { GoogleGenAI, Modality } from "@google/genai";

const INPUT_PCM = process.argv[2]; // optional: your-voice 16kHz PCM16 mono
const OUT_FILE = "out.pcm";
// half-cascade live model = robust + supports input transcription; swap to
// "gemini-live-2.5-flash-native-audio" to hear the newer native-audio voices.
const MODEL = process.env.LIVE_MODEL || "gemini-live-2.5-flash-preview";

const useVertex = process.env.GOOGLE_GENAI_USE_VERTEXAI === "true";
const ai = useVertex
    ? new GoogleGenAI({
        vertexai: true,
        project: process.env.GOOGLE_CLOUD_PROJECT,
        location: process.env.GOOGLE_CLOUD_LOCATION || "us-central1",
    })
    : new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const audioChunks = [];
let speakStartedAt = 0;
let inputStartedAt = 0;
let interruptedAt = 0;
let turnComplete = false;

const log = (...a) => console.log(`[${Date.now() % 100000}ms]`, ...a);

const session = await ai.live.connect({
    model: MODEL,
    config: {
        responseModalities: [Modality.AUDIO],
        // Persona stub — the real migration would inject the user's chart +
        // ayurveda + memory here (or via tools), replacing the relay's
        // server-side ID-token context load.
        systemInstruction:
            "You are Aurobhatt, a warm Vedic astrologer. Answer at length.",
        // Built-in VAD is ON by default. This is the knob that replaces ALL of
        // our custom barge-in thresholds (BARGE_IN_MIN_CHARS/WORDS/GRACE):
        // realtimeInputConfig: { automaticActivityDetection: { ... } },
    },
    callbacks: {
        onopen: () => log(" Live session open:", MODEL),
        onmessage: (msg) => {
            const sc = msg.serverContent;
            if (!sc) return;
            // THE money event: Google detected the user talking over the model
            // and tells us to stop — no STT, no thresholds, no echo hacks.
            if (sc.interrupted) {
                interruptedAt = Date.now();
                const lat = inputStartedAt ? interruptedAt - inputStartedAt : 0;
                log(` BARGE-IN! server 'interrupted' fired`,
                    inputStartedAt ? `(${lat}ms after we started sending audio)` : "");
            }
            const parts = sc.modelTurn?.parts || [];
            for (const p of parts) {
                if (p.inlineData?.data) {
                    if (!speakStartedAt) {
                        speakStartedAt = Date.now();
                        log(" model audio started streaming");
                        maybeStartBargeIn();
                    }
                    audioChunks.push(Buffer.from(p.inlineData.data, "base64"));
                }
            }
            if (sc.turnComplete) {
                turnComplete = true;
                log(" turnComplete");
            }
        },
        onerror: (e) => log(" error:", e?.message || e),
        onclose: (e) => log(" closed:", e?.reason || ""),
    },
});

// Kick off a long reply so there's something to interrupt.
session.sendClientContent({
    turns: "Namaste! Tell me in detail about the significance of the moon in Vedic astrology.",
});
log("  asked for a long reply");

// ~1.2s into his answer, stream the user's voice clip to trigger native VAD.
function maybeStartBargeIn() {
    if (!INPUT_PCM) return log("ℹ  no input clip given — audio-out test only");
    if (!existsSync(INPUT_PCM)) return log("  input clip not found:", INPUT_PCM);
    setTimeout(() => {
        const pcm = readFileSync(INPUT_PCM);
        inputStartedAt = Date.now();
        log(` streaming your ${pcm.length}-byte clip to trigger barge-in...`);
        const FRAME = 3200; // 100ms @ 16kHz PCM16
        let i = 0;
        const timer = setInterval(() => {
            if (i >= pcm.length) return clearInterval(timer);
            const frame = pcm.subarray(i, i + FRAME);
            session.sendRealtimeInput({
                audio: { data: frame.toString("base64"), mimeType: "audio/pcm;rate=16000" },
            });
            i += FRAME;
        }, 100);
    }, 1200);
}

// Wrap up after 12s: save audio, summarise the verdict.
setTimeout(() => {
    if (audioChunks.length) {
        writeFileSync(OUT_FILE, Buffer.concat(audioChunks));
        log(` wrote ${OUT_FILE} (${Buffer.concat(audioChunks).length} bytes, 24kHz PCM16 mono)`);
        log(`   play it:  ffplay -f s16le -ar 24000 -ac 1 ${OUT_FILE}`);
    } else {
        log("  no audio received — check auth/model/credits");
    }
    if (INPUT_PCM) {
        log(interruptedAt
            ? " VERDICT: native barge-in WORKS (see latency above)."
            : " VERDICT: no interrupt fired — check the input clip is real speech.");
    }
    session.close();
    process.exit(0);
}, 12000);
