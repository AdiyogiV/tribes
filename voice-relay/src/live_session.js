/**
 * LiveVoiceSession - Gemini Live API bridge.
 *
 * Replaces the Rube-Goldberg pipeline (Chirp STT + aiChat brain + our TTS +
 * hand-rolled barge-in thresholds) with ONE Google model that does speech-in,
 * thinking, and speech-out over a single WebSocket -- AND interrupts itself
 * natively via built-in Voice Activity Detection. No BARGE_IN_MIN_CHARS, no
 * grace windows, no echo hacks.
 *
 * It is a drop-in for MultilingualVoiceSession: same constructor shape, same
 * emitted events, so server.js wiring is unchanged.
 *
 *   emits "audio"      (Buffer)  -> 24kHz PCM16 chunk of Aryabhatt's voice
 *   emits "interrupt"  ()        -> user barged in; client should flush+stop
 *   emits "transcript" ({text})  -> what the user said (final-ish)
 *   emits "reply"      ({text})  -> what Aryabhatt said (text form)
 *   emits "turn_end"   ()        -> Aryabhatt finished this turn
 *   emits "error"      (Error)
 *   emits "close"      ()
 *
 * Wire protocol in: raw PCM16 16kHz mono mic frames via sendAudio(Buffer).
 */

import { EventEmitter } from "node:events";
import { GoogleGenAI, Modality, StartSensitivity, ActivityHandling } from "@google/genai";
import { CONFIG } from "./config.js";

export class LiveVoiceSession extends EventEmitter {
    constructor(sessionId, uid, idToken, tools) {
        super();
        this.sessionId = sessionId;
        this.uid = uid;
        this.idToken = idToken;
        // Whitelisted functionDeclarations the CLIENT registered for the current
        // surface. The client owns the tool set (per-screen); we just declare
        // them to Gemini and relay the calls/responses back and forth.
        this._tools = Array.isArray(tools) ? tools : [];
        this._session = null;
        this._connected = false;
        this._closed = false;
        this._pendingAudio = []; // mic frames that arrive before connect finishes
    }

    /**
     * Fetch the assembled persona + chart/ayurveda/memory systemInstruction from
     * the aiChat backend (promptOnly mode) using the caller's ID token. This is
     * the SAME context the text chat uses, so the voice persona never drifts.
     */
    async _fetchSystemPrompt() {
        const { promptUrl, fallbackPrompt } = CONFIG.live;
        try {
            const res = await fetch(promptUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    ...(this.idToken ? { Authorization: `Bearer ${this.idToken}` } : {}),
                },
                body: JSON.stringify({ promptOnly: true, messages: [] }),
            });
            if (!res.ok) throw new Error(`promptOnly HTTP ${res.status}`);
            const data = await res.json();
            if (data?.systemPrompt) return data.systemPrompt;
            throw new Error("promptOnly: empty systemPrompt");
        } catch (err) {
            // Never leave the user with a dead mic — fall back to a basic persona.
            console.warn(`[live ${this.sessionId}] prompt fetch failed, using fallback:`, err?.message || err);
            return fallbackPrompt;
        }
    }

    async start() {
        const { model, location, voice, languageCode } = CONFIG.live;
        let systemInstruction;
        try {
            systemInstruction = await this._fetchSystemPrompt();
            if (this._closed) return; // client hung up while we were fetching

            const ai = new GoogleGenAI({
                vertexai: true,
                project: CONFIG.project,
                location,
            });

            const speechConfig = {
                voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } },
            };
            // Pin a language only if explicitly configured; empty => native
            // multilingual auto-detect (understand AND answer in any language).
            if (languageCode) speechConfig.languageCode = languageCode;

            // VAD tuning: the Live API has NO echo cancellation and defaults to
            // a hair-trigger (START_SENSITIVITY_HIGH), so Aryabhatt's own
            // speaker echo gets mistaken for the user and he answers himself.
            // Default start sensitivity to LOW so only deliberate speech (with
            // the device's hardware AEC behind it) interrupts; real barge-in
            // still works. All env-tunable (see CONFIG.live).
            const realtimeInputConfig = this._buildRealtimeInputConfig();

            this._session = await ai.live.connect({
                model,
                config: {
                    responseModalities: [Modality.AUDIO],
                    systemInstruction,
                    speechConfig,
                    ...(CONFIG.live.temperature != null
                        ? { generationConfig: { temperature: CONFIG.live.temperature } }
                        : {}),
                    // Transcripts of both sides, so the client UI still shows text.
                    inputAudioTranscription: {},
                    outputAudioTranscription: {},
                    // Built-in VAD barge-in, but de-sensitized against self-echo
                    // (see _buildRealtimeInputConfig). Omitted entirely if it
                    // resolves to defaults so we never send an empty object.
                    ...(realtimeInputConfig ? { realtimeInputConfig } : {}),
                    // Tools Baba may call this session (client-registered,
                    // whitelisted). Omitted when there are none.
                    ...(this._tools.length
                        ? { tools: [{ functionDeclarations: this._tools }] }
                        : {}),
                },
                callbacks: {
                    onopen: () => {
                        this._connected = true;
                        console.log(`[live ${this.sessionId}] session open (${model})`);
                        // Flush any mic frames buffered during connect. This may
                        // fire BEFORE the await below assigns this._session, so
                        // _flushPending() no-ops until both are ready; the
                        // post-await call covers the other ordering.
                        this._flushPending();
                    },
                    onmessage: (msg) => this._onMessage(msg),
                    onerror: (e) => this.emit("error", e instanceof Error ? e : new Error(String(e?.message || e))),
                    onclose: () => { if (!this._closed) this.emit("close"); },
                },
            });
            // The connect() promise resolved => this._session is now set. If
            // onopen already fired (session still null then), flush here.
            this._flushPending();
        } catch (err) {
            this.emit("error", err instanceof Error ? err : new Error(String(err)));
        }
    }

    /**
     * Build the Live API realtimeInputConfig from CONFIG.live VAD knobs. Returns
     * null when everything is at the API default (so we don't send an empty
     * object). Defaults start-of-speech sensitivity to LOW to stop Aryabhatt's
     * own speaker echo from false-triggering a "user is talking" interrupt.
     */
    _buildRealtimeInputConfig() {
        const {
            vadStartSensitivity, vadPrefixPaddingMs, vadSilenceMs, noInterruption,
        } = CONFIG.live;

        const aad = {};
        const startMap = {
            LOW: StartSensitivity.START_SENSITIVITY_LOW,
            HIGH: StartSensitivity.START_SENSITIVITY_HIGH,
        };
        if (startMap[vadStartSensitivity]) {
            aad.startOfSpeechSensitivity = startMap[vadStartSensitivity];
        }
        if (vadPrefixPaddingMs != null) aad.prefixPaddingMs = vadPrefixPaddingMs;
        if (vadSilenceMs != null) aad.silenceDurationMs = vadSilenceMs;

        const cfg = {};
        if (Object.keys(aad).length) cfg.automaticActivityDetection = aad;
        if (noInterruption) cfg.activityHandling = ActivityHandling.NO_INTERRUPTION;

        return Object.keys(cfg).length ? cfg : null;
    }

    /**
     * Forward queued mic frames once BOTH the socket is open (_connected) AND
     * the session handle is assigned (_session). Idempotent: whichever of
     * onopen / post-await runs last does the actual flush.
     */
    _flushPending() {
        if (this._closed || !this._connected || !this._session) return;
        const pending = this._pendingAudio;
        this._pendingAudio = [];
        for (const buf of pending) this._forwardAudio(buf);
    }

    /** Translate a Live API server message into our event vocabulary. */
    _onMessage(msg) {
        // Tool calls arrive at the top level, not inside serverContent. Forward
        // each functionCall to the client, which runs it and sends a
        // tool_response back (see sendToolResponse).
        const calls = msg?.toolCall?.functionCalls;
        if (Array.isArray(calls)) {
            for (const call of calls) {
                this.emit("tool_call", {
                    id: call.id,
                    name: call.name,
                    args: call.args || {},
                });
            }
        }

        const sc = msg?.serverContent;
        if (!sc) return;

        // Native barge-in: Google detected the user talking over Aryabhatt.
        if (sc.interrupted) this.emit("interrupt");

        // User speech transcript.
        if (sc.inputTranscription?.text) {
            this.emit("transcript", { text: sc.inputTranscription.text });
        }
        // Aryabhatt's words (text form, for the chat bubble).
        if (sc.outputTranscription?.text) {
            this.emit("reply", { text: sc.outputTranscription.text });
        }

        // Aryabhatt's voice audio (base64 PCM16 24kHz).
        for (const part of sc.modelTurn?.parts || []) {
            const data = part.inlineData?.data;
            if (data) this.emit("audio", Buffer.from(data, "base64"));
        }

        if (sc.turnComplete) this.emit("turn_end");
    }

    _forwardAudio(buf) {
        if (!this._session) return; // not connected yet; sendAudio queues instead
        try {
            this._session.sendRealtimeInput({
                audio: {
                    data: Buffer.isBuffer(buf) ? buf.toString("base64") : Buffer.from(buf).toString("base64"),
                    mimeType: `audio/pcm;rate=${CONFIG.inputSampleRateHertz}`,
                },
            });
        } catch (err) {
            this.emit("error", err instanceof Error ? err : new Error(String(err)));
        }
    }

    /** Send the client's tool result(s) back to Gemini. */
    sendToolResponse(functionResponses) {
        if (this._closed || !this._session) return;
        try {
            this._session.sendToolResponse({ functionResponses });
        } catch (err) {
            this.emit("error", err instanceof Error ? err : new Error(String(err)));
        }
    }

    /** Raw PCM16 mic frame from the client. */
    sendAudio(buf) {
        if (this._closed) return;
        if (this._connected && this._session) this._forwardAudio(buf);
        else this._pendingAudio.push(buf); // queue until the session opens
    }

    end() {
        if (this._closed) return;
        this._closed = true;
        try { this._session?.close(); } catch { /* already closing */ }
        this.emit("close");
    }
}
