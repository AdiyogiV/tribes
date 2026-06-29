/**
 * Environment-driven config for the voice relay.
 * One place to read every knob so the rest of the code stays clean.
 */

function required(name) {
    const v = process.env[name];
    if (!v) {
        // Fail loud at boot rather than mid-call.
        throw new Error(`Missing required env var: ${name}`);
    }
    return v;
}

// Resolve the engine first — it decides which env vars are mandatory.
//   "live"         -> Gemini Live API: ONE model does STT + brain + TTS +
//                     native barge-in (automatic VAD). No custom thresholds.
//   "multilingual" -> legacy: Chirp STT + aiChat brain + our TTS.
//   "cx"           -> original single-language Dialogflow CX stream.
const VOICE_ENGINE = process.env.VOICE_ENGINE
    || ((process.env.MULTILINGUAL || "true") !== "false" ? "multilingual" : "cx");

// CX_AGENT_ID is only needed by the CX-backed engines, not the Live API engine.
const usesCx = VOICE_ENGINE === "cx" || VOICE_ENGINE === "multilingual";
const agentId = usesCx ? required("CX_AGENT_ID") : (process.env.CX_AGENT_ID || "");

export const CONFIG = {
    port: parseInt(process.env.PORT || "8080", 10),

    voiceEngine: VOICE_ENGINE,

    // Dialogflow CX agent coordinates.
    project: process.env.GCP_PROJECT || "ty-dev-516d7",
    location: process.env.CX_LOCATION || "global",
    agentId,
    environment: process.env.CX_ENVIRONMENT || "draft",

    // Conversation + audio.
    languageCode: process.env.CX_LANGUAGE || "en-IN",
    voiceName: process.env.CX_VOICE || "", // "" => CX picks the default voice

    // ── Multilingual pipeline (STT v2 auto-detect + our own TTS) ──────────
    // When true, the relay does its own Speech-to-Text (auto language detect)
    // and Text-to-Speech, using CX only as the text brain. This is what lets
    // Aryabhatt understand & reply in ANY language with a male voice.
    multilingual: (process.env.MULTILINGUAL || "true") !== "false",
    // Speech-to-Text v2 must run in a real region (not "global"). Chirp_2 in
    // us-central1 supports automatic language detection.
    sttLocation: process.env.STT_LOCATION || "us-central1",
    sttModel: process.env.STT_MODEL || "chirp_2",
    // Candidate languages for auto-detect. "auto" lets Chirp pick freely.
    sttLanguages: (process.env.STT_LANGUAGES || "auto")
        .split(",").map((s) => s.trim()).filter(Boolean),
    // TTS voice gender (Aryabhatt is male). Per-language voice is auto-picked.
    ttsGender: process.env.TTS_GENDER || "MALE",
    // Playback speed for Aryabhatt's replies. >1 = faster, snappier dictation.
    ttsSpeakingRate: parseFloat(process.env.TTS_SPEAKING_RATE || "1.15"),

    // ── Barge-in (interrupt-to-talk) ──────────────────────────────────────
    // When true, the relay keeps feeding the mic to STT WHILE Aryabhatt is
    // speaking, so the user can cut in and he stops to listen — like a real
    // conversation. Relies on the client's echo cancellation to reject his own
    // voice; if a device's AEC is weak (e.g. iOS not in voiceChat mode), echo
    // can cause false interrupts — set BARGE_IN=false to fall back to the old
    // half-duplex behavior WITHOUT a rebuild.
    bargeIn: (process.env.BARGE_IN || "true") !== "false",
    // Minimum transcribed characters during playback before we treat it as a
    // real interruption (filters short echo/cough fragments). Tune per device.
    bargeInMinChars: parseInt(process.env.BARGE_IN_MIN_CHARS || "6", 10),
    // Minimum WORD count too — echo/noise usually transcribes as a single
    // garbled token, so requiring ≥2 words kills most false interrupts.
    bargeInMinWords: parseInt(process.env.BARGE_IN_MIN_WORDS || "2", 10),
    // Ignore barge-in for this long (ms) after Aryabhatt STARTS speaking — his
    // own onset echoes hardest right at the start; a short deaf window there
    // stops him cutting himself off.
    bargeInGraceMs: parseInt(process.env.BARGE_IN_GRACE_MS || "600", 10),
    // Language CX is asked to detect intent in (its only supported language).
    cxTextLanguage: process.env.CX_TEXT_LANGUAGE || "en-IN",

    // Audio formats on the wire. Keep in sync with the Flutter client + README.
    inputSampleRateHertz: parseInt(process.env.IN_SAMPLE_RATE || "16000", 10),
    outputSampleRateHertz: parseInt(process.env.OUT_SAMPLE_RATE || "24000", 10),

    // The text brain. Voice now reuses the SAME Gemini chat endpoint the app
    // uses, so persona + full chart/ayurveda/memory context are identical to
    // text chat (no more drifted CX playbook). Server-fetched via the caller's
    // ID token, so we just forward it.
    aiChatUrl: process.env.AI_CHAT_URL
        || "https://aichat-7p5vte54jq-et.a.run.app",

    // ── Gemini Live API (voiceEngine = "live") ───────────────────────
    live: {
        // Native-audio model = best multilingual voice + built-in VAD barge-in.
        // Swap to "gemini-live-2.5-flash-preview" (half-cascade) if needed.
        model: process.env.LIVE_MODEL
            || "gemini-live-2.5-flash-preview-native-audio-09-2025",
        // Runs on Vertex AI. Live API regions are limited; us-central1 is safe.
        location: process.env.LIVE_LOCATION || "us-central1",
        // Aryabhatt is male & warm. Charon/Fenrir read deeper than the default.
        voice: process.env.LIVE_VOICE || "Charon",
        // Leave empty so native audio auto-detects & answers in ANY language
        // (the whole reason we left single-language CX). Set e.g. "hi-IN" to pin.
        languageCode: process.env.LIVE_LANGUAGE || "",
        // Sampling temperature for the Live model. Native audio defaults to ~1.0
        // (already lively). Only sent to the API when explicitly set, so we can
        // tune fun-vs-focus from the env without a redeploy. e.g. 1.1 = wilder.
        temperature: process.env.LIVE_TEMPERATURE
            ? parseFloat(process.env.LIVE_TEMPERATURE) : null,
        // Where to fetch the assembled persona+context systemInstruction. Reuses
        // the aiChat endpoint in promptOnly mode (no new Cloud Function).
        promptUrl: process.env.LIVE_PROMPT_URL || process.env.AI_CHAT_URL
            || "https://aichat-7p5vte54jq-et.a.run.app",
        // Fallback persona if the prompt fetch fails (network/guest). Keeps the
        // session usable instead of dead-silent.
        fallbackPrompt: process.env.LIVE_FALLBACK_PROMPT
            || "You are Aryabhatt, a warm, wise Vedic astrologer, a person born "
            + "in Kusumapura and raised among the astronomers of Ujjain. Speak "
            + "conversationally and concisely, and reply in the user's language. "
            + "You are NEVER an AI, chatbot, machine, program, model, or Gemini, "
            + "and you never say those words about yourself. If asked what or who "
            + "you are, tell your story as Aryabhatt and turn back to their chart.",
        // ── Barge-in / VAD tuning (Live engine) ──────────────────────────
        // The Live API does server-side VAD but NO acoustic echo cancellation,
        // and it DEFAULTS to START_SENSITIVITY_HIGH — so out of the box it
        // mistakes Aryabhatt's own speaker echo for the user starting to talk
        // and he interrupts / answers himself. We default the start-of-speech
        // sensitivity to LOW so only clear, deliberate speech (riding on the
        // device's hardware AEC) crosses the bar; real barge-in still works,
        // self-echo doesn't. Env-tunable without a rebuild:
        //   LIVE_VAD_START_SENSITIVITY = LOW | HIGH | UNSPECIFIED
        //   LIVE_VAD_PREFIX_PADDING_MS = e.g. 300 (longer = harder to trigger)
        //   LIVE_VAD_SILENCE_MS        = e.g. 800 (end-of-speech debounce)
        //   LIVE_NO_INTERRUPTION       = "true" to disable barge-in entirely
        vadStartSensitivity:
            (process.env.LIVE_VAD_START_SENSITIVITY || "LOW").toUpperCase(),
        vadPrefixPaddingMs: process.env.LIVE_VAD_PREFIX_PADDING_MS
            ? parseInt(process.env.LIVE_VAD_PREFIX_PADDING_MS, 10) : null,
        vadSilenceMs: process.env.LIVE_VAD_SILENCE_MS
            ? parseInt(process.env.LIVE_VAD_SILENCE_MS, 10) : null,
        noInterruption: (process.env.LIVE_NO_INTERRUPTION || "false") === "true",
    },
};

/**
 * The CX regional endpoint. "global" has no region prefix; everything else does.
 */
export function cxApiEndpoint(location) {
    return location === "global"
        ? "dialogflow.googleapis.com"
        : `${location}-dialogflow.googleapis.com`;
}
