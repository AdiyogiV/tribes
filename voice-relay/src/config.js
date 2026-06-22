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

export const CONFIG = {
    port: parseInt(process.env.PORT || "8080", 10),

    // Dialogflow CX agent coordinates.
    project: process.env.GCP_PROJECT || "ty-dev-516d7",
    location: process.env.CX_LOCATION || "global",
    agentId: required("CX_AGENT_ID"),
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
};

/**
 * The CX regional endpoint. "global" has no region prefix; everything else does.
 */
export function cxApiEndpoint(location) {
    return location === "global"
        ? "dialogflow.googleapis.com"
        : `${location}-dialogflow.googleapis.com`;
}
