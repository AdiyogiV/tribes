import { defineSecret, defineString } from "firebase-functions/params";

// Firebase Functions v2 secrets (sensitive credentials)
export const openrouterApiKey = defineSecret("OPENROUTER_API_KEY");
export const freeAstrologyApiKey = defineSecret("FREE_ASTROLOGY_API_KEY");
export const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Agora credentials for group calls
export const agoraAppCertificate = defineSecret("AGORA_APP_CERTIFICATE");

// =============================================================================
// ENVIRONMENT CONFIGURATION (non-sensitive, but environment-specific)
// =============================================================================

// Agora App ID (public identifier - safe to expose, but should be configurable per environment)
export const agoraAppId = defineString("AGORA_APP_ID", {
    default: "89a0a2f0e6c9488fbc657ec4c1dac6eb",
    description: "Agora App ID for voice/video calls",
});

// Firebase Storage bucket name (varies by environment)
export const storageBucketName = defineString("STORAGE_BUCKET_NAME", {
    default: "ty-dev-516d7.appspot.com",
    description: "Firebase Storage bucket name",
});

// App environment
export const appEnv = defineString("APP_ENV", {
    default: "production",
    description: "Application environment (development, staging, production)",
});
