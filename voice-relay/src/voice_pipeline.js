/**
 * Multilingual voice pipeline.
 *
 * Decouples the three jobs CX used to do in one locked-language stream so
 * Aryabhatt can understand AND answer in ANY language with a male voice:
 *
 *   mic PCM ─► Speech-to-Text v2 (Chirp_2, AUTO language detect)
 *           ─► aiChat (the SAME Gemini brain text chat uses — one persona,
 *              full chart/ayurveda/memory context via the caller's ID token)
 *           ─► Text-to-Speech (MALE voice for the detected language)  ─► PCM
 *
 * Emits the SAME events as CxVoiceSession so server.js never changes:
 *   'transcript' ({text, final})  'reply' ({text})  'audio' (Buffer)
 *   'turn_end'   ()               'error' (Error)    'close' ()
 */

import { EventEmitter } from "node:events";
import speech from "@google-cloud/speech";
import textToSpeech from "@google-cloud/text-to-speech";
import { CONFIG } from "./config.js";

// Reuse clients across sessions (channels pool internally).
const sttClient = new speech.v2.SpeechClient({
    apiEndpoint: `${CONFIG.sttLocation}-speech.googleapis.com`,
});
const ttsClient = new textToSpeech.TextToSpeechClient();

/** Normalize an STT language tag ("hi-in") to BCP-47 ("hi-IN") for TTS. */
function normalizeLang(code) {
    if (!code) return CONFIG.cxTextLanguage;
    const [lang, region] = code.split("-");
    return region ? `${lang.toLowerCase()}-${region.toUpperCase()}` : lang;
}

export class MultilingualVoiceSession extends EventEmitter {
    /**
     * @param {string} sessionId stable id per call (kept for logging parity)
     * @param {string} [uid] verified Firebase uid
     * @param {string} [idToken] caller's Firebase ID token, forwarded to the
     *   brain so it loads THIS user's full context server-side
     */
    constructor(sessionId, uid, idToken) {
        super();
        this.sessionId = sessionId;
        this.uid = uid || null;
        this.idToken = idToken || null;
        // Multi-turn memory for this call. Sent to the brain every turn; the
        // backend trims to its own history cap. Fresh per call (no carryover).
        this.history = [];
        this.sttStream = null;
        this.ended = false;
        this.busy = false; // processing a turn (brain + TTS in flight)
        this.speaking = false; // TTS audio is playing — ignore mic echo
        // Monotonic turn counter. Every new utterance claims a generation; an
        // interrupt (barge-in) bumps it so any in-flight brain/TTS reply from
        // the cut-off turn is discarded instead of resurrecting after the user
        // already took the floor back.
        this.turnId = 0;
        this.lastLang = CONFIG.cxTextLanguage;
        this._speakStartedAt = 0; // ms timestamp when current playback began
        this._speakTimer = null;
        this._reopenTimer = null; // debounces STT reopen
        this._reopenAttempts = 0; // backoff counter, reset on healthy data
    }

    start() {
        this.ended = false;
        this._openStt();
    }

    /** Open (or reopen) the long-lived STT v2 stream. */
    _openStt() {
        if (this.ended) return;
        this._teardownStt(); // drop any previous stream + its listeners
        const recognizer =
            `projects/${CONFIG.project}/locations/${CONFIG.sttLocation}`
            + "/recognizers/_";

        const stream = sttClient._streamingRecognize();
        this.sttStream = stream;
        stream.on("data", (res) => {
            this._reopenAttempts = 0; // stream is healthy again
            this._onStt(res);
        });
        // A torn-down STT stream is NEVER fatal: v2 streams are routinely closed
        // by Google (max duration, the inactivity gap while Aryabhatt speaks,
        // transient network). Both 'error' and 'end' just mean "open a fresh
        // one" — killing the call here was the bug that dropped conversations.
        stream.on("error", (err) => this._reopenStt(stream, err));
        stream.on("end", () => this._reopenStt(stream, null));

        // First message = config; audio frames follow.
        stream.write({
            recognizer,
            streamingConfig: {
                config: {
                    explicitDecodingConfig: {
                        encoding: "LINEAR16",
                        sampleRateHertz: CONFIG.inputSampleRateHertz,
                        audioChannelCount: 1,
                    },
                    languageCodes: CONFIG.sttLanguages,
                    model: CONFIG.sttModel,
                    features: { enableAutomaticPunctuation: true },
                },
                streamingFeatures: { interimResults: true },
            },
        });
    }

    /** Tear down the current STT stream and detach its listeners. */
    _teardownStt() {
        const s = this.sttStream;
        this.sttStream = null;
        if (!s) return;
        try { s.removeAllListeners(); } catch { /* already gone */ }
        try { s.end(); } catch { /* already closed */ }
        try { s.destroy?.(); } catch { /* already destroyed */ }
    }

    /**
     * Reopen the STT stream after it closed/errored. Debounced (one pending
     * reopen at a time) with a small backoff so a persistent failure can't spin
     * the CPU. Stale callbacks from an old stream are ignored.
     */
    _reopenStt(fromStream, err) {
        if (fromStream !== this.sttStream && this.sttStream !== null) return;
        if (this.ended) {
            this.emit("close");
            return;
        }
        if (err) {
            // eslint-disable-next-line no-console
            console.warn(`[stt] stream closed, reopening: ${err.message || err}`);
        }
        if (this._reopenTimer) return; // a reopen is already scheduled
        const delay = Math.min(150 * (this._reopenAttempts + 1), 2000);
        this._reopenAttempts += 1;
        this._reopenTimer = setTimeout(() => {
            this._reopenTimer = null;
            this._openStt();
        }, delay);
    }

    sendAudio(chunk) {
        if (!this.sttStream) return;
        // Half-duplex (barge-in OFF): drop the mic while Aryabhatt is speaking
        // or mid-turn so his own voice can't echo back into STT. With barge-in
        // ON we KEEP feeding the mic during playback so the user can cut in;
        // echo rejection then rides on the client's acoustic echo canceller.
        if (!CONFIG.bargeIn && (this.speaking || this.busy)) return;
        try {
            this.sttStream.write({ audio: chunk });
        } catch {
            // stream reopening; next chunk will land
        }
    }

    /**
     * Barge-in: the user started talking while Aryabhatt was speaking. Stop him
     * immediately, abandon the current turn, and hand the floor back. We do NOT
     * treat the triggering partial as the user's utterance — STT keeps running,
     * so their own final transcript is what gets answered next.
     */
    _interrupt() {
        if (!this.speaking) return;
        this.speaking = false;
        clearTimeout(this._speakTimer);
        this.busy = false; // free the floor for the user's incoming utterance
        this.turnId += 1; // invalidate the cut-off turn's in-flight reply/TTS
        this.emit("interrupt"); // tell the client to flush playback NOW
    }

    /** Handle one STT response: interim captions + end-of-utterance trigger. */
    _onStt(res) {
        const result = res.results?.[0];
        if (!result) return;
        const alt = result.alternatives?.[0];
        const text = alt?.transcript?.trim();
        if (!text) return;

        if (result.languageCode) this.lastLang = normalizeLang(result.languageCode);

        // Barge-in check BEFORE anything else: only cut him off on STRONG
        // evidence of real speech, so his own echo / room noise can't trigger
        // it. Require, during playback and past the start-of-speech grace
        // window: enough characters AND enough words.
        if (CONFIG.bargeIn && this.speaking) {
            const sinceSpeak = Date.now() - this._speakStartedAt;
            const words = text.split(/\s+/).filter(Boolean).length;
            if (sinceSpeak >= CONFIG.bargeInGraceMs
                && text.length >= CONFIG.bargeInMinChars
                && words >= CONFIG.bargeInMinWords) {
                this._interrupt();
            }
        }

        this.emit("transcript", { text, final: !!result.isFinal });

        if (result.isFinal && !this.busy) {
            this._handleUtterance(text, this.lastLang);
        }
    }

    /** Brain + voice for one finished user utterance. */
    async _handleUtterance(text, lang) {
        const myTurn = ++this.turnId; // claim this generation
        this.busy = true;
        try {
            const reply = await this._askBrain(text);
            // Interrupted (or call ended) while the brain was thinking? Drop the
            // stale answer on the floor.
            if (this.ended || this.turnId !== myTurn) return;
            if (reply) {
                this.emit("reply", { text: reply });
                await this._speak(reply, lang, myTurn);
            }
            if (this.turnId !== myTurn) return;
            this.emit("turn_end");
        } catch (err) {
            // One turn failing (transient CX/TTS hiccup) shouldn't end the call.
            // Log it, then hand control back so the user can just try again.
            if (!this.ended && this.turnId === myTurn) {
                // eslint-disable-next-line no-console
                console.warn(`[turn] failed, staying live: ${err?.message || err}`);
                this.emit("turn_end");
            }
        } finally {
            // Only clear busy if WE still own the floor — an interrupt may have
            // already started (or cleared the way for) a newer turn.
            if (this.turnId === myTurn) this.busy = false;
        }
    }

    /**
     * Ask the brain: the SAME aiChat Gemini endpoint the app's text chat uses.
     * We forward the caller's ID token so the backend loads THIS user's full
     * context (chart + ayurveda + memory) server-side — identical to text chat.
     * `voice: true` makes it use the spoken-length style. The reply streams
     * back as SSE token events, which we accumulate into one string.
     */
    async _askBrain(text) {
        this.history.push({ role: "user", content: text });
        const res = await fetch(CONFIG.aiChatUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                ...(this.idToken
                    ? { Authorization: `Bearer ${this.idToken}` }
                    : {}),
            },
            body: JSON.stringify({ messages: this.history, voice: true }),
        });
        if (!res.ok || !res.body) {
            throw new Error(`aiChat HTTP ${res.status}`);
        }

        let reply = "";
        let buffer = "";
        const decoder = new TextDecoder();
        const consume = (line) => {
            const t = line.trim();
            if (!t.startsWith("data:")) return;
            const payload = t.slice(5).trim();
            if (!payload) return;
            try {
                const data = JSON.parse(payload);
                if (data.event === "token" && typeof data.content === "string") {
                    reply += data.content;
                }
            } catch { /* partial / non-token frame: ignore */ }
        };
        for await (const chunk of res.body) {
            buffer += decoder.decode(chunk, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";
            for (const line of lines) consume(line);
        }
        if (buffer) consume(buffer); // flush any trailing line

        reply = reply.trim();
        if (reply) this.history.push({ role: "assistant", content: reply });
        return reply;
    }

    /** Synthesize a MALE voice in the detected language and stream it out. */
    async _speak(text, lang, myTurn) {
        const pcm = await this._synthesize(text, lang);
        if (!pcm || !pcm.length) return;
        // Interrupted while we were synthesizing? Don't start playing a reply
        // the user already talked over.
        if (this.ended || (myTurn !== undefined && this.turnId !== myTurn)) return;

        this.speaking = true;
        this._speakStartedAt = Date.now();
        // Emit in ~8KB chunks so the client can start playing immediately.
        const CHUNK = 8192;
        for (let i = 0; i < pcm.length && !this.ended; i += CHUNK) {
            // Stop mid-stream the instant a barge-in bumps the generation.
            if (myTurn !== undefined && this.turnId !== myTurn) break;
            this.emit("audio", pcm.subarray(i, i + CHUNK));
        }
        if (myTurn !== undefined && this.turnId !== myTurn) return;

        // Keep the mic muted for the playback duration (+ tail) to stop echo.
        // (No-op for echo when barge-in is on, but still the natural point to
        // flip speaking=false so the next turn starts clean.)
        const seconds = pcm.length / (2 * CONFIG.outputSampleRateHertz);
        clearTimeout(this._speakTimer);
        this._speakTimer = setTimeout(() => {
            if (myTurn === undefined || this.turnId === myTurn) {
                this.speaking = false;
            }
        }, Math.ceil(seconds * 1000) + 300);
    }

    /** TTS with a male voice; fall back to en-IN if the language has none. */
    async _synthesize(text, lang) {
        const audioConfig = {
            audioEncoding: "LINEAR16",
            sampleRateHertz: CONFIG.outputSampleRateHertz,
            speakingRate: CONFIG.ttsSpeakingRate,
        };
        const tryLang = async (languageCode) => {
            const [res] = await ttsClient.synthesizeSpeech({
                input: { text },
                voice: { languageCode, ssmlGender: CONFIG.ttsGender },
                audioConfig,
            });
            return stripWav(Buffer.from(res.audioContent));
        };
        try {
            return await tryLang(lang);
        } catch {
            // No male voice for that language — English male is intelligible.
            return tryLang(CONFIG.cxTextLanguage);
        }
    }

    end() {
        this.ended = true;
        clearTimeout(this._speakTimer);
        clearTimeout(this._reopenTimer);
        this._reopenTimer = null;
        this._teardownStt();
    }
}

/** Strip a 44-byte RIFF/WAV header so the client gets raw PCM16. */
function stripWav(buf) {
    if (buf.length > 44 && buf.toString("ascii", 0, 4) === "RIFF") {
        return buf.subarray(44);
    }
    return buf;
}
