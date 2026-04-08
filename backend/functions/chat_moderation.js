import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, logger } from "../lib/firebase.js";
import { containsBlockedText } from "../lib/utils.js";

/**
 * Cloud Function triggered when a new chat message is created
 * Filters objectionable content and deletes messages that violate content policy
 */
export const filterChatMessage = onDocumentCreated(
    {
        document: "spaceChats/{messageId}",
        region: "asia-southeast2",
    },
    async (event) => {
        const messageData = event.data?.data();
        const messageId = event.params.messageId;

        if (!messageData) {
            logger.warn("No message data found", {
                structuredData: true,
                messageId,
            });
            return null;
        }

        // Only filter text messages
        if (messageData.messageType !== "text") {
            return null;
        }

        const content = messageData.content || "";

        // Check for objectionable content
        if (containsBlockedText(content)) {
            logger.info("Blocked objectionable chat message", {
                structuredData: true,
                messageId,
                senderId: messageData.senderId,
                spaceId: messageData.spaceId,
            });

            try {
                // Delete the message immediately
                await event.data?.ref.delete();

                // Optionally, create a report record for admin review
                await db.collection("reports").add({
                    type: "chat_message",
                    messageId: messageId,
                    reportedBy: "system",
                    reason: "Objectionable content detected",
                    content: content.substring(0, 200), // Store preview
                    senderId: messageData.senderId,
                    spaceId: messageData.spaceId,
                    timestamp: new Date(),
                    status: "auto_removed",
                });

                logger.info("Deleted objectionable message and created report", {
                    structuredData: true,
                    messageId,
                });
            } catch (error) {
                logger.error("Error filtering chat message", {
                    structuredData: true,
                    messageId,
                    error: error.message,
                });
            }
        }

        return null;
    }
);
