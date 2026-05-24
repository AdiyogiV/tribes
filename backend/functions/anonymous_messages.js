import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { checkRateLimit } from "../lib/rate_limiter.js";
import { normalizeText, containsBlockedText } from "../lib/utils.js";

const MAX_MESSAGE_LENGTH = 200;
const PREVIEW_LENGTH = 40;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const RATE_LIMIT_MAX_PER_IP_RECIPIENT = 10;
const RATE_LIMIT_MAX_PER_UID = 20;

function buildPreview(text) {
    if (!text) return "";
    return text.length > PREVIEW_LENGTH ? `${text.slice(0, PREVIEW_LENGTH)}…` : text;
}

function getRequestIp(request) {
    const rawRequest = request.rawRequest;
    const forwarded = rawRequest?.headers?.["x-forwarded-for"];
    if (typeof forwarded === "string" && forwarded.length > 0) {
        return forwarded.split(",")[0].trim();
    }
    return rawRequest?.ip || rawRequest?.connection?.remoteAddress || null;
}

async function resolveRecipientIdBySlug(slug) {
    const snapshot = await db
        .collection("users")
        .where("anonymousLinkSlug", "==", slug)
        .limit(1)
        .get();
    if (snapshot.empty) return null;
    return snapshot.docs[0].id;
}

async function validateRecipientExists(recipientId) {
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    return recipientDoc.exists;
}

async function enforceRateLimits({ recipientId, uid, ip }) {
    if (ip) {
        const ipResult = await checkRateLimit("secret_message_ip", {
            windowMs: RATE_LIMIT_WINDOW_MS,
            maxRequests: RATE_LIMIT_MAX_PER_IP_RECIPIENT,
            identifier: `${ip}_${recipientId}`,
        });
        if (!ipResult.allowed) {
            throw new HttpsError("resource-exhausted", "RATE_LIMITED");
        }
    }

    if (uid) {
        const uidResult = await checkRateLimit("secret_message_uid", {
            windowMs: RATE_LIMIT_WINDOW_MS,
            maxRequests: RATE_LIMIT_MAX_PER_UID,
            identifier: uid,
        });
        if (!uidResult.allowed) {
            throw new HttpsError("resource-exhausted", "RATE_LIMITED");
        }
    }
}

export async function handleSubmitAnonymousMessage(request) {
    try {
        const { slug, recipientId, text } = request.data || {};
        const trimmedText = normalizeText(text);

        if (!trimmedText) {
            throw new HttpsError("invalid-argument", "EMPTY_TEXT");
        }

        if (trimmedText.length > MAX_MESSAGE_LENGTH) {
            throw new HttpsError("invalid-argument", "TEXT_TOO_LONG");
        }

        if (containsBlockedText(trimmedText)) {
            throw new HttpsError("invalid-argument", "BLOCKLISTED");
        }

        let resolvedRecipientId = null;
        if (slug) {
            resolvedRecipientId = await resolveRecipientIdBySlug(slug);
            if (!resolvedRecipientId) {
                throw new HttpsError("not-found", "SLUG_NOT_FOUND");
            }
        } else if (recipientId) {
            resolvedRecipientId = recipientId;
            const exists = await validateRecipientExists(resolvedRecipientId);
            if (!exists) {
                throw new HttpsError("not-found", "INVALID_RECIPIENT");
            }
        } else {
            throw new HttpsError("invalid-argument", "MISSING_RECIPIENT");
        }

        const authUid = request.auth?.uid || null;
        if (authUid && authUid === resolvedRecipientId) {
            throw new HttpsError("failed-precondition", "SELF_MESSAGE");
        }

        const ip = getRequestIp(request);
        await enforceRateLimits({
            recipientId: resolvedRecipientId,
            uid: authUid,
            ip,
        });

        const messageRef = await db.collection("anonymousMessages").add({
            recipientId: resolvedRecipientId,
            text: trimmedText,
            createdAt: FieldValue.serverTimestamp(),
            status: "visible",
        });

        await db
            .collection("notifications")
            .doc(resolvedRecipientId)
            .collection("notifications")
            .add({
                type: "anonymousMessage",
                read: false,
                messageId: messageRef.id,
                preview: buildPreview(trimmedText),
                timestamp: FieldValue.serverTimestamp(),
            });

        return { success: true, messageId: messageRef.id };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }

        const errMsg = error?.message ?? String(error);
        const errStack = error?.stack ?? "";
        logger.error("Error submitting anonymous message", {
            structuredData: true,
            error: errMsg,
            stack: errStack,
            name: error?.name,
        });
        logger.error("[submitAnonymousMessage] internal error", {
            structuredData: true,
            error: errMsg,
            stack: errStack,
        });

        throw new HttpsError("internal", "UNKNOWN");
    }
}
