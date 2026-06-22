/**
 * Dialogflow CX bidirectional streaming wrapper.
 *
 * Owns ONE live conversation turn-loop with CX: push user audio in, get
 * interim transcripts + Aryabhatt's reply + synthesized TTS audio out.
 *
 * Deliberately dumb about transport — it just emits events. server.js wires
 * those events to the browser/Flutter WebSocket. Keeps each file cohesive.
 */

import { EventEmitter } from "node:events";
import { SessionsClient } from "@google-cloud/dialogflow-cx";
import { CONFIG, cxApiEndpoint } from "./config.js";

// Reuse one gRPC client across sessions (channels are pooled internally).
const client = new SessionsClient({
    apiEndpoint: cxApiEndpoint(CONFIG.location),
});

/**
 * A single voice session. Emits:
 *   'transcript' ({ text, final })  — live STT of the user
 *   'reply'      ({ text })         — Aryabhatt's text (captions)
 *   'audio'      (Buffer)           — TTS PCM chunk to play
 *   'turn_end'   ()                 — CX finished a response turn
 *   'error'      (Error)
 *   'close'      ()
 */
export class CxVoiceSession extends EventEmitter {
    /** @param {string} sessionId stable id per user/device for context */
    constructor(sessionId) {
        super();
        this.sessionId = sessionId;
        this.stream = null;
        this.configSent = false;
        this.ended = false; // true only after a real hang-up / fatal error
    }

    /** Build the CX session resource path (env-scoped if not draft). */
    _sessionPath() {
        const { project, location, agentId, environment } = CONFIG;
        if (environment && environment !== "draft") {
            return client.projectLocationAgentEnvironmentSessionPath(
                project, location, agentId, environment, this.sessionId,
            );
        }
        return client.projectLocationAgentSessionPath(
            project, location, agentId, this.sessionId,
        );
    }

    /** The first request configures audio + language for the whole stream. */
    _configRequest() {
        const outputAudioConfig = {
            audioEncoding: "OUTPUT_AUDIO_ENCODING_LINEAR_16",
            sampleRateHertz: CONFIG.outputSampleRateHertz,
        };
        if (CONFIG.voiceName) {
            outputAudioConfig.synthesizeSpeechConfig = {
                voice: { name: CONFIG.voiceName },
            };
        }
        return {
            session: this._sessionPath(),
            queryInput: {
                audio: {
                    config: {
                        audioEncoding: "AUDIO_ENCODING_LINEAR_16",
                        sampleRateHertz: CONFIG.inputSampleRateHertz,
                        // Let CX auto-detect end-of-speech and close the turn.
                        // We reopen a fresh stream for the next utterance.
                        singleUtterance: true,
                    },
                },
                languageCode: CONFIG.languageCode,
            },
            outputAudioConfig,
        };
    }

    /** Begin the session: open the first turn's stream. */
    start() {
        this.ended = false;
        this._openTurn();
    }

    /**
     * Open ONE turn's bidi stream. With singleUtterance the server ends the
     * stream after it replies; we transparently reopen for the next utterance
     * so the caller sees one continuous conversation (no 'close' per turn).
     */
    _openTurn() {
        if (this.ended) return;
        this.configSent = false;
        this.stream = client.streamingDetectIntent();

        this.stream.on("data", (res) => this._onData(res));
        this.stream.on("error", (err) => {
            if (!this.ended) this.emit("error", err);
        });
        this.stream.on("end", () => {
            // Turn finished. Reopen for the next utterance unless we're done.
            if (!this.ended) this._openTurn();
            else this.emit("close");
        });

        // First write = the config turn. Audio chunks follow.
        this.stream.write(this._configRequest());
        this.configSent = true;
    }

    /** Forward a raw PCM16 chunk from the client into CX. */
    sendAudio(chunk) {
        if (!this.stream || !this.configSent) return;
        this.stream.write({ queryInput: { audio: { audio: chunk } } });
    }

    /** Translate one CX streaming response into our events. */
    _onData(res) {
        // Interim / final speech recognition of what the USER said.
        const rr = res.recognitionResult;
        if (rr && rr.transcript) {
            this.emit("transcript", {
                text: rr.transcript,
                final: rr.messageType === "END_OF_SINGLE_UTTERANCE"
                    || rr.isFinal === true,
            });
        }

        // The full detect-intent response: Aryabhatt's reply + TTS audio.
        const dir = res.detectIntentResponse;
        if (dir) {
            const messages = dir.queryResult?.responseMessages || [];
            for (const m of messages) {
                const t = m.text?.text?.join(" ").trim();
                if (t) this.emit("reply", { text: t });
            }
            if (dir.outputAudio && dir.outputAudio.length) {
                this.emit("audio", Buffer.from(dir.outputAudio));
            }
            this.emit("turn_end");
        }
    }

    /** Close the session for good (user hung up). Stops the reopen loop. */
    end() {
        this.ended = true;
        try {
            this.stream?.end();
        } catch {
            // already closed; nothing to do
        }
        this.stream = null;
    }
}
