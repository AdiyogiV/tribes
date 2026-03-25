import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "../lib/firebase.js";
import { db } from "../lib/firebase.js";
import { cleanupExpiredRateLimits } from "../lib/rate_limiter.js";

// =============================================================================
// SCHEDULED CLEANUP FUNCTIONS
// Removes old documents to prevent unbounded Firestore growth
// =============================================================================

/**
 * Scheduled function to clean up old ai_chat_sessions documents
 * 
 * ai_chat_sessions are ephemeral - they're used during streaming for:
 * - Real-time thought step updates
 * - Streaming status tracking
 * - Performance metrics
 * 
 * After a response completes, the conversation is saved to dmConversations,
 * so ai_chat_sessions can be safely deleted after 24 hours.
 * 
 * Runs daily at 3:00 AM UTC (low traffic time)
 */
export const cleanupAiChatSessions = onSchedule(
    {
        schedule: "0 3 * * *", // Every day at 3:00 AM UTC
        timeZone: "UTC",
        region: "asia-southeast2",
        memory: "256MiB",
        timeoutSeconds: 540, // 9 minutes max
    },
    async () => {
        const startTime = Date.now();
        
        // Delete sessions older than 24 hours
        const cutoffMs = 24 * 60 * 60 * 1000; // 24 hours
        const cutoffDate = new Date(Date.now() - cutoffMs);
        
        logger.info("Starting ai_chat_sessions cleanup", {
            structuredData: true,
            cutoffDate: cutoffDate.toISOString(),
            cutoffMs,
        });

        try {
            // Query for old sessions
            // Note: createdAt is a server timestamp, so we compare against it
            const oldSessionsQuery = db.collection("ai_chat_sessions")
                .where("createdAt", "<", cutoffDate)
                .limit(500); // Process in batches to avoid timeout

            let totalDeleted = 0;
            let batchCount = 0;

            // Process in batches until no more old sessions
            while (true) {
                const snapshot = await oldSessionsQuery.get();
                
                if (snapshot.empty) {
                    logger.info("No more old sessions to delete", {
                        structuredData: true,
                        batchCount,
                    });
                    break;
                }

                // Delete in batch
                const batch = db.batch();
                snapshot.docs.forEach((doc) => {
                    batch.delete(doc.ref);
                });

                await batch.commit();
                
                totalDeleted += snapshot.size;
                batchCount++;

                logger.info("Deleted batch of ai_chat_sessions", {
                    structuredData: true,
                    batchSize: snapshot.size,
                    totalDeleted,
                    batchCount,
                });

                // Safety check - don't run forever
                if (batchCount >= 20) {
                    logger.warn("Reached max batch count, stopping early", {
                        structuredData: true,
                        totalDeleted,
                        batchCount,
                    });
                    break;
                }

                // Small delay between batches to avoid overwhelming Firestore
                await new Promise((resolve) => setTimeout(resolve, 100));
            }

            // Also cleanup expired rate limits
            let rateLimitsDeleted = 0;
            try {
                rateLimitsDeleted = await cleanupExpiredRateLimits();
            } catch (rateLimitError) {
                logger.warn("Rate limit cleanup failed (non-fatal)", {
                    structuredData: true,
                    error: String(rateLimitError),
                });
            }

            const duration = Date.now() - startTime;
            
            logger.info("Scheduled cleanup complete", {
                structuredData: true,
                aiSessionsDeleted: totalDeleted,
                rateLimitsDeleted,
                batchCount,
                duration_ms: duration,
            });

            return { success: true, aiSessionsDeleted: totalDeleted, rateLimitsDeleted };
        } catch (error) {
            logger.error("Scheduled cleanup failed", {
                structuredData: true,
                error: String(error),
            });
            throw error;
        }
    }
);
