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
//   "cx"   -> Dialogflow CX streaming: ONE agent does STT + brain (playbook,
//             with tool-calling via v3beta1) + TTS. Funded by trial credits;
//             this is the production default.
//   "live" -> Gemini Live API: ONE model does STT + brain + TTS + native
//             barge-in. Currently PARKED (needs Vertex AI Live quota/billing).
const VOICE_ENGINE = process.env.VOICE_ENGINE || "cx";

// CX_AGENT_ID is required by the CX engine, optional for the Live API engine.
const agentId = VOICE_ENGINE === "cx"
    ? required("CX_AGENT_ID")
    : (process.env.CX_AGENT_ID || "");

export const CONFIG = {
    port: parseInt(process.env.PORT || "8080", 10),

    voiceEngine: VOICE_ENGINE,

    // Dialogflow CX agent coordinates.
    project: process.env.GCP_PROJECT || "ty-dev-516d7",
    location: process.env.CX_LOCATION || "global",
    agentId,
    environment: process.env.CX_ENVIRONMENT || "draft",

    // Conversation + audio. Hindi (hi-IN) is the preferred language for STT
    // recognition AND Aurobhatt's spoken/text reply. Override per-deploy via env.
    languageCode: process.env.CX_LANGUAGE || "hi-IN",
    voiceName: process.env.CX_VOICE || "hi-IN-Chirp3-HD-Charon", // male, warm

    // STT recognizer model for CX's built-in speech recognition. The default
    // (unspecified) recognizer is weak on English + code-switching, so English
    // spoken to a hi-IN session comes back as Devanagari gibberish. "latest_long"
    // is Google's newest general model and handles accents + mixed Hindi/English
    // far better, still on CX pricing (NO Live premium). Env-tunable without a
    // rebuild: try CX_STT_MODEL=chirp_2 for the strongest multilingual model,
    // or CX_STT_MODEL="" to fall back to the CX default recognizer.
    sttModel: process.env.CX_STT_MODEL ?? "latest_long",

    // Audio formats on the wire. Keep in sync with the Flutter client + README.
    inputSampleRateHertz: parseInt(process.env.IN_SAMPLE_RATE || "16000", 10),
    outputSampleRateHertz: parseInt(process.env.OUT_SAMPLE_RATE || "24000", 10),

    // ── Gemini Live API (voiceEngine = "live") ───────────────────────
    live: {
        // Native-audio model = best multilingual voice + built-in VAD barge-in.
        // Swap to "gemini-live-2.5-flash-preview" (half-cascade) if needed.
        model: process.env.LIVE_MODEL
            || "gemini-live-2.5-flash-preview-native-audio-09-2025",
        // Runs on Vertex AI. Live API regions are limited; us-central1 is safe.
        location: process.env.LIVE_LOCATION || "us-central1",
        // Aurobhatt is male & warm. Charon/Fenrir read deeper than the default.
        voice: process.env.LIVE_VOICE || "Charon",
        // Hindi (hi-IN) preferred so Aurobhatt speaks Hindi on the Live engine
        // too (onboarding). Set LIVE_LANGUAGE="" to restore free auto-detect.
        languageCode: process.env.LIVE_LANGUAGE || "hi-IN",
        // Sampling temperature for the Live model. Native audio defaults to ~1.0
        // (already lively). Only sent to the API when explicitly set, so we can
        // tune fun-vs-focus from the env without a redeploy. e.g. 1.1 = wilder.
        temperature: process.env.LIVE_TEMPERATURE
            ? parseFloat(process.env.LIVE_TEMPERATURE) : null,
        // Where to fetch the assembled persona+context systemInstruction. Reuses
        // the aiChat endpoint in promptOnly mode (no new Cloud Function).
        promptUrl: process.env.LIVE_PROMPT_URL || process.env.AI_CHAT_URL
            || "https://aichat-7p5vte54jq-et.a.run.app",
        // Minimal fallback ONLY if the prompt fetch fails (network/guest).
        // The real persona is the SINGLE SOURCE OF TRUTH in the backend
        // (functions/prompts/chat.js -> AUROBHATT_PERSONA), fetched at runtime
        // via promptUrl. This stub just keeps the session usable + in-character
        // during an outage; keep it short so it can never drift from canon.
        fallbackPrompt: process.env.LIVE_FALLBACK_PROMPT
            || "You are Aurobhatt (fondly called Baba), a warm, wise Vedic "
            + "astrologer. Speak conversationally and concisely in the user's "
            + "language. You are a person, NEVER an AI, chatbot, machine, or "
            + "Gemini, and you never say those words about yourself.",
        // ── Barge-in / VAD tuning (Live engine) ──────────────────────────
        // The Live API does server-side VAD but NO acoustic echo cancellation,
        // and it DEFAULTS to START_SENSITIVITY_HIGH — so out of the box it
        // mistakes Aurobhatt's own speaker echo for the user starting to talk
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
