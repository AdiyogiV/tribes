import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, logger } from "../lib/firebase.js";

/**
 * Scheduled function to clean up stale typing indicators.
 * Runs every minute to delete typing documents older than 10 seconds.
 * This prevents orphaned typing indicators when users disconnect unexpectedly.
 */
export const cleanupTypingIndicators = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    retryCount: 0, // Don't retry - next scheduled run will handle it
  },
  async () => {
    try {
      // Delete typing documents older than 10 seconds
      const cutoff = new Date(Date.now() - 10000); // 10 seconds ago
      
      const expiredDocs = await db
        .collection("typing")
        .where("updatedAt", "<", cutoff)
        .limit(500) // Batch limit
        .get();

      if (expiredDocs.empty) {
        return;
      }

      // Batch delete for efficiency
      const batch = db.batch();
      expiredDocs.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      logger.info("Cleaned up stale typing indicators", {
        structuredData: true,
        count: expiredDocs.size,
      });
    } catch (error) {
      // Log error but don't throw - next scheduled run will retry
      logger.error("Error cleaning up typing indicators", {
        structuredData: true,
        error: error.message,
      });
    }
  }
);
