/**
 * Aura Service — shared helper for awarding aura points.
 *
 * Extracted from functions/aura.js so that ANY domain (social, follows,
 * namaste, etc.) can award aura without importing a Cloud Function file.
 * This avoids cross-group dependencies when the codebase is split into
 * separate Firebase codebases.
 */

import { logger } from "firebase-functions";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

/**
 * Award aura points to a user (positive only).
 *
 * @param {string} userId   - Recipient user ID
 * @param {number} points   - Points to award (must be > 0)
 * @param {string} reason   - Human-readable reason
 * @param {object} metadata - Optional metadata stored in auraHistory
 * @returns {Promise<boolean>} true if awarded, false if skipped/errored
 */
export async function awardAura(userId, points, reason, metadata = {}) {
    if (!userId || points <= 0) {
        logger.warn("awardAura: skipped (invalid params)", {
            structuredData: true,
            userId: userId || null,
            points,
            reason,
        });
        return false;
    }

    const db = getFirestore();
    const batch = db.batch();

    try {
        const userRef = db.collection("users").doc(userId);
        batch.set(
            userRef,
            {
                auraScore: FieldValue.increment(points),
                lastAuraUpdate: FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        const historyRef = db
            .collection("users")
            .doc(userId)
            .collection("auraHistory")
            .doc();

        batch.set(historyRef, {
            points,
            reason,
            timestamp: FieldValue.serverTimestamp(),
            metadata,
        });

        await batch.commit();

        logger.info(`Awarded ${points} aura to user ${userId} for: ${reason}`);
        return true;
    } catch (error) {
        logger.error("Error awarding aura:", error);
        return false;
    }
}
