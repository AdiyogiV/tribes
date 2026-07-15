/**
 * Local end-to-end test client for the voice relay.
 *
 * Streams a WAV file (must be PCM16, 16 kHz, mono) into the relay over the
 * same WebSocket protocol the Flutter app uses, prints the live transcript and
 * Aurobhatt's reply, and saves the returned TTS audio as a playable WAV.
 *
 * Usage:
 *   node tools/test_client.js path/to/input.wav [ws://localhost:8080/voice]
 *
 * Make a compatible WAV from anything with ffmpeg:
 *   ffmpeg -i any.m4a -ac 1 -ar 16000 -sample_fmt s16 input.wav
 */

import fs from "node:fs";
import { WebSocket } from "ws";

const inputPath = process.argv[2];
const url = process.argv[3] || "ws://localhost:8080/voice";
const OUT_PATH = "out.wav";
const OUT_SAMPLE_RATE = 24000; // relay's TTS output rate (see config.js)

if (!inputPath) {
    console.error("Usage: node tools/test_client.js <input.wav> [ws-url]");
    process.exit(1);
}

// ---------------------------------------------------------------------------
// Minimal WAV helpers (PCM16 mono only — enough for this test).
// ---------------------------------------------------------------------------

/** Extract raw PCM bytes + sample rate from a WAV buffer. */
function readWavPcm(buf) {
    if (buf.toString("ascii", 0, 4) !== "RIFF" || buf.toString("ascii", 8, 12) !== "WAVE") {
        throw new Error("Not a RIFF/WAVE file");
    }
    let offset = 12;
    let sampleRate = 16000;
    let dataStart = -1;
    let dataLen = 0;
    while (offset + 8 <= buf.length) {
        const id = buf.toString("ascii", offset, offset + 4);
        const size = buf.readUInt32LE(offset + 4);
        if (id === "fmt ") {
            sampleRate = buf.readUInt32LE(offset + 12);
            const bits = buf.readUInt16LE(offset + 22);
            const channels = buf.readUInt16LE(offset + 10);
            if (bits !== 16 || channels !== 1) {
                throw new Error(`Need PCM16 mono, got ${bits}-bit ${channels}ch`);
            }
        } else if (id === "data") {
            dataStart = offset + 8;
            dataLen = size;
        }
        offset += 8 + size + (size % 2); // chunks are word-aligned
    }
    if (dataStart < 0) throw new Error("No data chunk in WAV");
    return { pcm: buf.subarray(dataStart, dataStart + dataLen), sampleRate };
}

/** Wrap raw PCM16 mono bytes in a WAV header. */
function writeWav(pcm, sampleRate, path) {
    const header = Buffer.alloc(44);
    header.write("RIFF", 0);
    header.writeUInt32LE(36 + pcm.length, 4);
    header.write("WAVE", 8);
    header.write("fmt ", 12);
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20); // PCM
    header.writeUInt16LE(1, 22); // mono
    header.writeUInt32LE(sampleRate, 24);
    header.writeUInt32LE(sampleRate * 2, 28); // byte rate
    header.writeUInt16LE(2, 32); // block align
    header.writeUInt16LE(16, 34); // bits per sample
    header.write("data", 36);
    header.writeUInt32LE(pcm.length, 40);
    fs.writeFileSync(path, Buffer.concat([header, pcm]));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
// Stream it.
// ---------------------------------------------------------------------------

async function main() {
    const { pcm, sampleRate } = readWavPcm(fs.readFileSync(inputPath));
    if (sampleRate !== 16000) {
        console.warn(`WARNING: input is ${sampleRate} Hz; relay expects 16000 Hz.`);
    }
    console.log(`Loaded ${pcm.length} bytes PCM @ ${sampleRate} Hz from ${inputPath}`);

    const ws = new WebSocket(url);
    const audioChunks = [];

    ws.on("open", async () => {
        console.log(`Connected to ${url}`);
        ws.send(JSON.stringify({ type: "start", sessionId: "local-test" }));

        // Stream ~20 ms frames (640 bytes @ 16 kHz mono PCM16) in real time.
        const FRAME = 640;
        for (let i = 0; i < pcm.length; i += FRAME) {
            ws.send(pcm.subarray(i, i + FRAME));
            await sleep(20);
        }
        console.log("Finished sending audio; waiting for reply...");
    });

    ws.on("message", (data, isBinary) => {
        if (isBinary) {
            audioChunks.push(Buffer.from(data));
            return;
        }
        const msg = JSON.parse(data.toString());
        if (msg.type === "transcript") {
            console.log(`  [you${msg.final ? ", final" : ""}] ${msg.text}`);
        } else if (msg.type === "reply") {
            console.log(`  [Aurobhatt] ${msg.text}`);
        } else if (msg.type === "speaking_done") {
            finish(ws, audioChunks);
        } else if (msg.type === "error") {
            console.error(`  [error] ${msg.message}`);
        } else {
            console.log(`  [${msg.type}]`);
        }
    });

    ws.on("error", (e) => console.error("WS error:", e.message));
    ws.on("close", () => process.exit(0));

    // Safety net: if no speaking_done arrives, flush after 15 s.
    setTimeout(() => finish(ws, audioChunks), 15000);
}

let finished = false;
function finish(ws, chunks) {
    if (finished) return;
    finished = true;
    const audio = Buffer.concat(chunks);
    if (audio.length) {
        writeWav(audio, OUT_SAMPLE_RATE, OUT_PATH);
        console.log(`\nSaved ${audio.length} bytes of TTS to ${OUT_PATH} `
            + `(play it: open ${OUT_PATH})`);
    } else {
        console.log("\nNo audio returned — check agent voice config / credit scope.");
    }
    try { ws.send(JSON.stringify({ type: "stop" })); } catch { /* closing */ }
    ws.close();
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
