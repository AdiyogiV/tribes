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
// Use Vertex's global endpoint so Gemini requests route to the nearest
// datacenter (lower TTFT for our India-based users) instead of pinning a
// single far-away region. Override via VERTEX_LOCATION if ever needed.
const LOCATION = process.env.VERTEX_LOCATION || "global";

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
    return parts.map(p => p.text || "").join("").trim() || null;
}

/**
 * Extract text from a single streaming chunk (GenerateContentResponse).
 * Used in generateContentStream loops.
 */
export function extractChunkText(chunk) {
    const parts = chunk?.candidates?.[0]?.content?.parts;
    if (!parts?.length) return "";
    return parts.map(p => p.text || "").join("");
}
