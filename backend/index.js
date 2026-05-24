// Cloud Functions exports — consolidated for the 20 vCPU regional quota.
// Global options (region, concurrency, memory) are set in lib/firebase.js.
//
// Each export below = 1 Cloud Function = 1 Cloud Run service = 1 vCPU.
// Path-based triggers and gateways are the primary consolidation mechanisms.

// ---------------------------------------------------------------------------
// Gateways (5) — consolidated onCall routers (1 Cloud Run service = many methods)
// Flutter calls: functions.httpsCallable('<gateway>').call({'method': '...', ...data})
// ---------------------------------------------------------------------------
export { astroGateway } from "./gateways/astro.js";
export { insightGateway } from "./gateways/insight.js";
export { healthGateway } from "./gateways/health.js";
export { socialGateway } from "./gateways/social.js";
export { commsGateway } from "./gateways/comms.js";

// ---------------------------------------------------------------------------
// Scheduler (1) — single nightly orchestrator replaces 14 individual onSchedule
// functions across cleanup, data refresh, content generation, user insights
// and health phases. See backend/functions/schedulers/unified_orchestrator.js
// ---------------------------------------------------------------------------
export { unifiedOrchestrator } from "./functions/schedulers/unified_orchestrator.js";

// ---------------------------------------------------------------------------
// Cloud Tasks worker (1) — single unified router replaces 3 separate workers:
//   - dispatchCardNotification, processInsightTask, processPerHouseTask.
// Routes by `taskType` discriminator (with shape sniffing fallback for
// in-flight tasks deployed before the discriminator existed).
// ---------------------------------------------------------------------------
export { taskRouter } from "./functions/task_router.js";

// ---------------------------------------------------------------------------
// Path-merged Firestore triggers (7) — each one collapses several
// onDocumentCreated/Updated/Deleted exports on the same document path into a
// single onDocumentWritten subscription (Eventarc allows only one Cloud
// Function per unique path, so merging lets us pay 1 vCPU per path instead
// of N). Path served by each is annotated in the file's header.
// ---------------------------------------------------------------------------
export { onChatCreated } from "./functions/triggers/on_chat_created.js";
export { onCallWrite } from "./functions/triggers/on_call_write.js";
export { onPostWrite } from "./functions/triggers/on_post_write.js";
export { onSpacePostWrite } from "./functions/triggers/on_space_post_write.js";
export { onPostLikeWrite } from "./functions/triggers/on_post_like_write.js";
export { onReplyWrite } from "./functions/triggers/on_reply_write.js";
export { onFollowWrite } from "./functions/triggers/on_follow_write.js";

// ---------------------------------------------------------------------------
// Unique-path Firestore triggers — only one consumer per path, nothing to merge
// ---------------------------------------------------------------------------
export { sendPushNotification } from "./functions/notifications.js";
export { newInvite } from "./functions/likes_and_invites.js";
export { onSpacePostDeleted } from "./functions/reposts.js";
export { onHealthSnapshotWrite } from "./functions/ayurveda.js";
export { onGroupCallActivity } from "./functions/group_call_notifications.js";

// ---------------------------------------------------------------------------
// Standalone HTTP endpoint — uses Server-Sent Events streaming via `onRequest`,
// so it cannot be merged into an `onCall` gateway. All other callable
// operations are routed through one of the 5 gateways above.
//
// Note: User-deletion cleanup (previously the `onUserDeleted` v1 auth trigger)
// is now handled by `unifiedOrchestrator` Phase 1 via a tombstone sweep —
// Flutter writes `deletedUsers/{uid}` with `status: 'pending'` before calling
// `user.delete()`, and the daily orchestrator picks up those tombstones.
// ---------------------------------------------------------------------------
export { aiChat } from "./functions/ai.js";
