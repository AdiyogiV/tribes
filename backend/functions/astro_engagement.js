import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { DateTime } from "luxon";

/**
 * Track insight view for streak calculation
 */
export const trackInsightView = onCall({
    region: "asia-southeast2",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Must be authenticated to track insight view",
        );
    }

    const userId = request.auth.uid;
    const { insightId, date } = request.data || {};

    if (!insightId && !date) {
        throw new HttpsError(
            "invalid-argument",
            "insightId or date is required",
        );
    }

    // Define outside try block so it's available in catch
    const insightDate = date || insightId || DateTime.now().toFormat("yyyy-MM-dd");
    
    try {
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const yesterday = DateTime.now().minus({ days: 1 }).toFormat("yyyy-MM-dd");

        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
            logger.warn("User not found for tracking", {
                structuredData: true,
                userId,
            });
            return {
                success: false,
                streak: 0,
                date: insightDate,
                error: "User not found",
            };
        }

        const userData = userDoc.data();
        const currentStreak = userData.insightStreak || 0;
        const lastInsightView = userData.lastInsightView;

        let newStreak = currentStreak;

        // Check if this is a consecutive day
        if (lastInsightView === yesterday || lastInsightView === today) {
            // Continue streak
            if (insightDate === today && lastInsightView !== today) {
                // New day, increment streak
                newStreak = currentStreak + 1;
            }
        } else if (insightDate === today) {
            // Starting new streak
            newStreak = 1;
        }

        // Update user document (only update fields that changed)
        const updateData = {
            lastInsightView: insightDate,
            insightStreak: newStreak,
            lastStreakUpdate: FieldValue.serverTimestamp(),
        };
        
        // Use set with merge - Cloud Functions bypass Firestore rules
        await userRef.set(updateData, { merge: true });

        logger.info("Tracked insight view", {
            structuredData: true,
            userId,
            insightDate,
            streak: newStreak,
        });

        return {
            success: true,
            streak: newStreak,
            date: insightDate,
        };
    } catch (error) {
        logger.error("Failed to track insight view", {
            structuredData: true,
            userId,
            error: String(error),
            stack: error.stack,
        });

        // Return error instead of throwing to prevent constant retries
        return {
            success: false,
            streak: 0,
            date: insightDate || DateTime.now().toFormat("yyyy-MM-dd"),
            error: error.message || "Unknown error",
        };
    }
});

/**
 * Submit feedback for an insight (thumbs up/down)
 */
export const submitInsightFeedback = onCall({
    region: "asia-southeast2",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Must be authenticated to submit feedback",
        );
    }

    const userId = request.auth.uid;
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
});

/**
 * Toggle favorite status for an insight
 */
export const toggleFavoriteInsight = onCall({
    region: "asia-southeast2",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Must be authenticated to toggle favorite",
        );
    }

    const userId = request.auth.uid;
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
});

/**
 * Get user's streak and favorite insights
 */
export const getUserEngagement = onCall({
    region: "asia-southeast2",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Must be authenticated to get engagement data",
        );
    }

    const userId = request.auth.uid;

    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const streak = userData.insightStreak || 0;
        const lastInsightView = userData.lastInsightView;

        // Get favorite insights
        const favoritesSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("favoriteInsights")
            .orderBy("createdAt", "desc")
            .limit(50)
            .get();

        const favorites = favoritesSnapshot.docs.map((doc) => ({
            insightId: doc.data().insightId || doc.id,
            date: doc.data().date,
            createdAt: doc.data().createdAt?.toDate?.() || null,
        }));

        return {
            success: true,
            streak,
            lastInsightView,
            favorites,
            favoriteCount: favorites.length,
        };
    } catch (error) {
        logger.error("Failed to get engagement data", {
            structuredData: true,
            userId,
            error: String(error),
        });

        if (error instanceof HttpsError) {
            throw error;
        }

        throw new HttpsError(
            "internal",
            `Failed to get engagement data: ${error.message}`,
        );
    }
});

