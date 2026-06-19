/**
 * Shared Vertex AI client singleton.
 *
 * All backend Gemini calls go through this module instead of creating
 * individual GoogleGenerativeAI instances with an API key.
 * Uses Application Default Credentials (ADC) — no API key needed.
 * Cloud Functions automatically get credentials from the service account.
 */

import { VertexAI } from "@google-cloud/vertexai";

const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || "ty-dev-516d7";
// IMPORTANT: must be a real Vertex region, NOT "global".
// The @google-cloud/vertexai SDK builds its endpoint as
//   https://${location}-aiplatform.googleapis.com
// so location="global" produces the non-existent host
// "global-aiplatform.googleapis.com" -> HTML 404 -> the SDK's JSON.parse
// throws "Unexpected token <, <!DOCTYPE ...", which broke AI chat. This SDK
// has no special-casing for the global endpoint (only @google/genai does).
//
// asia-southeast1 (Singapore) chosen deliberately. Reasoning:
//   1) Lowest function→Vertex latency: our Cloud Function runs in
//      asia-southeast2 (Jakarta), and Singapore is the adjacent region
//      (~30ms hop) — closer than Mumbai (~70ms) from the function.
//   2) Reliable capacity: asia-south1 (Mumbai) frequently 429s on
//      gemini-2.5-flash because Vertex's Dynamic Shared Quota pool there
//      saturates under aggregate global demand. Singapore's DSQ pool is
//      far less contended and consistently returns 200 in our probes.
//   3) Verified to serve gemini-2.5-flash (HTTP 200, ~1.7s end-to-end).
// Notes on neighboring regions: asia-south2 (Delhi) returns 501 and
// asia-southeast2 (Jakarta, our function region) returns 400 — neither
// serves Gemini. Override via VERTEX_LOCATION if needed (e.g. fall back
// to us-central1 for redundancy).
const LOCATION = process.env.VERTEX_LOCATION || "asia-southeast1";

let _vertexAI;

/**
 * Get (or create) the singleton VertexAI instance.
 */
export function getVertexAI() {
    if (!_vertexAI) {
        _vertexAI = new VertexAI({ project: PROJECT, location: LOCATION });
    }
    return _vertexAI;
}

/**
 * Helper to extract text from a Vertex AI GenerateContentResult.
 * The Vertex AI SDK doesn't have a .text() convenience method like the
 * AI Studio SDK, so we provide one here.
 */
export function extractText(result) {
    const candidates = result?.response?.candidates;
    if (!candidates?.length) return null;
    const parts = candidates[0]?.content?.parts;
    if (!parts?.length) return null;
    return parts.map((p) => p.text || "").join("").trim() || null;
}

/**
 * Extract text from a single streaming chunk (GenerateContentResponse).
 * Used in generateContentStream loops.
 */
export function extractChunkText(chunk) {
    const parts = chunk?.candidates?.[0]?.content?.parts;
    if (!parts?.length) return "";
    return parts.map((p) => p.text || "").join("");
}
