import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { DateTime } from "luxon";
import { requireAuth } from "../lib/auth_utils.js";

// REMOVED: trackInsightView — Flutter app tracks insight views via Firebase
// Analytics client-side (lib/shared/services/analytics_service.dart), not via
// this backend function. The insightStreak/lastInsightView fields it wrote were
// never read by any active feature.

/** Handler: Submit feedback for an insight. Extracted for gateway reuse. */
export async function handleSubmitInsightFeedback(request) {
    const userId = requireAuth(request, "submit feedback");
    const { insightId, date, feedback, rating } = request.data || {};

    if (!insightId && !date) {
        throw new HttpsError(
            "invalid-argument",
            "insightId or date is required",
        );
    }

    if (!feedback && rating == null) {
        throw new HttpsError(
            "invalid-argument",
            "feedback or rating is required",
        );
    }

    try {
        const insightDate = date || insightId || DateTime.now().toFormat("yyyy-MM-dd");

        // Store feedback
        const feedbackRef = db
            .collection("users")
            .doc(userId)
            .collection("insightFeedback")
            .doc();

        await feedbackRef.set({
            insightId: insightDate,
            date: insightDate,
            feedback: feedback || (rating === 1 ? "thumbs_up" : "thumbs_down"),
            rating: rating || (feedback === "thumbs_up" ? 1 : 0),
            createdAt: FieldValue.serverTimestamp(),
        });

        logger.info("Submitted insight feedback", {
            structuredData: true,
            userId,
            insightDate,
            feedback,
            rating,
        });

        return {
            success: true,
            feedbackId: feedbackRef.id,
        };
    } catch (error) {
        logger.error("Failed to submit feedback", {
            structuredData: true,
            userId,
            error: String(error),
        });

        if (error instanceof HttpsError) {
            throw error;
        }

        throw new HttpsError(
            "internal",
            `Failed to submit feedback: ${error.message}`,
        );
    }
}

/** Handler: Toggle favorite status for an insight. Extracted for gateway reuse. */
export async function handleToggleFavoriteInsight(request) {
    const userId = requireAuth(request, "toggle favorite");
    const { insightId, date } = request.data || {};

    if (!insightId && !date) {
        throw new HttpsError(
            "invalid-argument",
            "insightId or date is required",
        );
    }

    try {
        const insightDate = date || insightId || DateTime.now().toFormat("yyyy-MM-dd");
        const favoriteRef = db
            .collection("users")
            .doc(userId)
            .collection("favoriteInsights")
            .doc(insightDate);

        const favoriteDoc = await favoriteRef.get();
        const isFavorite = favoriteDoc.exists;

        if (isFavorite) {
            // Remove from favorites
            await favoriteRef.delete();
            logger.info("Removed from favorites", {
                structuredData: true,
                userId,
                insightDate,
            });
        } else {
            // Add to favorites
            await favoriteRef.set({
                insightId: insightDate,
                date: insightDate,
                createdAt: FieldValue.serverTimestamp(),
            });
            logger.info("Added to favorites", {
                structuredData: true,
                userId,
                insightDate,
            });
        }

        return {
            success: true,
            isFavorite: !isFavorite,
            insightId: insightDate,
        };
    } catch (error) {
        logger.error("Failed to toggle favorite", {
            structuredData: true,
            userId,
            error: String(error),
        });

        if (error instanceof HttpsError) {
            throw error;
        }

        throw new HttpsError(
            "internal",
            `Failed to toggle favorite: ${error.message}`,
        );
    }
}

// REMOVED: getUserEngagement — No UI feature ever displayed engagement stats
// (streak/favorites count). The Flutter app reads favorites directly from
// Firestore where needed; this callable was orphan code.

