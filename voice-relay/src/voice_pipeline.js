/**
 * Multilingual voice pipeline.
 *
 * Decouples the three jobs CX used to do in one locked-language stream so
 * Aryabhatt can understand AND answer in ANY language with a male voice:
 *
 *   mic PCM ─► Speech-to-Text v2 (Chirp_2, AUTO language detect)
 *           ─► Dialogflow CX playbook (the brain — replies in the user's lang)
 *           ─► Text-to-Speech (MALE voice for the detected language)  ─► PCM
 *
 * Emits the SAME events as CxVoiceSession so server.js never changes:
 *   'transcript' ({text, final})  'reply' ({text})  'audio' (Buffer)
 *   'turn_end'   ()               'error' (Error)    'close' ()
 */

import { EventEmitter } from "node:events";
import speech from "@google-cloud/speech";
import textToSpeech from "@google-cloud/text-to-speech";
import { SessionsClient } from "@google-cloud/dialogflow-cx";
import { CONFIG, cxApiEndpoint } from "./config.js";
import { buildUserContext } from "./user_context.js";

// Reuse clients across sessions (channels pool internally).
const sttClient = new speech.v2.SpeechClient({
    apiEndpoint: `${CONFIG.sttLocation}-speech.googleapis.com`,
});
const ttsClient = new textToSpeech.TextToSpeechClient();
const cxClient = new SessionsClient({
    apiEndpoint: cxApiEndpoint(CONFIG.location),
});

/** Normalize an STT language tag ("hi-in") to BCP-47 ("hi-IN") for TTS. */
function normalizeLang(code) {
    if (!code) return CONFIG.cxTextLanguage;
    const [lang, region] = code.split("-");
    return region ? `${lang.toLowerCase()}-${region.toUpperCase()}` : lang;
}

export class MultilingualVoiceSession extends EventEmitter {
    /**
     * @param {string} sessionId stable id per call for CX context
     * @param {string} [uid] verified Firebase uid, for loading their chart
     */
    constructor(sessionId, uid) {
        super();
        this.sessionId = sessionId;
        this.uid = uid || null;
        this.userContext = null; // lazily loaded chart briefing (string)
        this._contextLoaded = false;
        this.sttStream = null;
        this.ended = false;
        this.busy = false; // processing a turn (CX + TTS in flight)
        this.speaking = false; // TTS audio is playing — ignore mic echo
        this.lastLang = CONFIG.cxTextLanguage;
        this._speakTimer = null;
        this._reopenTimer = null; // debounces STT reopen
        this._reopenAttempts = 0; // backoff counter, reset on healthy data
    }

    _sessionPath() {
        const { project, location, agentId, environment } = CONFIG;
        if (environment && environment !== "draft") {
            return cxClient.projectLocationAgentEnvironmentSessionPath(
                project, location, agentId, environment, this.sessionId,
            );
        }
        return cxClient.projectLocationAgentSessionPath(
            project, location, agentId, this.sessionId,
        );
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
        // Drop mic while Aryabhatt is speaking or we're mid-turn (anti-echo).
        if (!this.sttStream || this.speaking || this.busy) return;
        try {
            this.sttStream.write({ audio: chunk });
        } catch {
            // stream reopening; next chunk will land
        }
    }

    /** Handle one STT response: interim captions + end-of-utterance trigger. */
    _onStt(res) {
        const result = res.results?.[0];
        if (!result) return;
        const alt = result.alternatives?.[0];
        const text = alt?.transcript?.trim();
        if (!text) return;

        if (result.languageCode) this.lastLang = normalizeLang(result.languageCode);
        this.emit("transcript", { text, final: !!result.isFinal });

        if (result.isFinal && !this.busy) {
            this._handleUtterance(text, this.lastLang);
        }
    }

    /** Brain + voice for one finished user utterance. */
    async _handleUtterance(text, lang) {
        this.busy = true;
        try {
            const reply = await this._askBrain(text);
            if (reply) {
                this.emit("reply", { text: reply });
                await this._speak(reply, lang);
            }
            this.emit("turn_end");
        } catch (err) {
            // One turn failing (transient CX/TTS hiccup) shouldn't end the call.
            // Log it, then hand control back so the user can just try again.
            if (!this.ended) {
                // eslint-disable-next-line no-console
                console.warn(`[turn] failed, staying live: ${err?.message || err}`);
                this.emit("turn_end");
            }
        } finally {
            this.busy = false;
        }
    }

    /**
     * Load the user's chart briefing once per call. Best-effort and cached:
     * a failed/empty lookup just means Aryabhatt answers without personal data.
     */
    async _ensureContext() {
        if (this._contextLoaded) return;
        this._contextLoaded = true;
        try {
            this.userContext = await buildUserContext(this.uid);
        } catch {
            this.userContext = null;
        }
    }

    /** Ask the Aryabhatt CX playbook (text in, text out). */
    async _askBrain(text) {
        await this._ensureContext();
        // Bundle the chart briefing with the question so CX has no separate
        // "system" channel to miss. The guard keeps him from reciting the data
        // verbatim — he should use it to think, then answer naturally aloud.
        const queryText = this.userContext
            ? `(Background for you only, do not read this aloud: ${this.userContext}) `
              + `The person said: ${text}`
            : text;
        const [response] = await cxClient.detectIntent({
            session: this._sessionPath(),
            queryInput: {
                text: { text: queryText },
                languageCode: CONFIG.cxTextLanguage,
            },
        });
        const messages = response.queryResult?.responseMessages || [];
        return messages
            .map((m) => m.text?.text?.join(" ").trim())
            .filter(Boolean)
            .join(" ")
            .trim();
    }

    /** Synthesize a MALE voice in the detected language and stream it out. */
    async _speak(text, lang) {
        const pcm = await this._synthesize(text, lang);
        if (!pcm || !pcm.length) return;

        this.speaking = true;
        // Emit in ~8KB chunks so the client can start playing immediately.
        const CHUNK = 8192;
        for (let i = 0; i < pcm.length && !this.ended; i += CHUNK) {
            this.emit("audio", pcm.subarray(i, i + CHUNK));
        }

        // Keep the mic muted for the playback duration (+ tail) to stop echo.
        const seconds = pcm.length / (2 * CONFIG.outputSampleRateHertz);
        clearTimeout(this._speakTimer);
        this._speakTimer = setTimeout(() => {
            this.speaking = false;
        }, Math.ceil(seconds * 1000) + 300);
    }

    /** TTS with a male voice; fall back to en-IN if the language has none. */
    async _synthesize(text, lang) {
        const audioConfig = {
            audioEncoding: "LINEAR16",
            sampleRateHertz: CONFIG.outputSampleRateHertz,
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
