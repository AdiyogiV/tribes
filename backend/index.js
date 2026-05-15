// Cloud Functions exports
// Global options (region, concurrency, memory) are set in lib/firebase.js

// ---------------------------------------------------------------------------
// Gateways — consolidated onCall routers (1 Cloud Run service = many methods)
// Deploy these ALONGSIDE the old individual functions during migration.
// Once Flutter switches to gateway calls, delete the old individual exports.
// ---------------------------------------------------------------------------
export { astroGateway } from "./gateways/astro.js";

// ---------------------------------------------------------------------------
// Individual function exports (legacy — will be removed after gateway migration)
// ---------------------------------------------------------------------------
export {
    addPostToFeeds,
    addProfilePostToGlobalFeed,
    deletePostFromGlobalFeed,
    deleteSpacePostFromGlobalFeed,
    cleanupOrphanedFeedEntries, // NEW: Weekly cleanup of orphaned feed entries
} from "./functions/feeds.js";
export { sendPushNotification } from "./functions/notifications.js";
export { onNewChatMessage } from "./functions/chat_notifications.js";
export { filterChatMessage } from "./functions/chat_moderation.js";
export { cleanupTypingIndicators } from "./functions/cleanup_typing.js";
export { getLinkPreview } from "./functions/link_preview.js";
export { newPost, deletePost } from "./functions/posts.js";
export { newLike, removeLike, newInvite } from "./functions/likes_and_invites.js";
export { aiChat, getChatPromptConfig } from "./functions/ai.js";
export { cleanupAiChatSessions } from "./functions/cleanup_ai_sessions.js";
export {
    awardCreatePostAura,
    awardCreateSpacePostAura,
    awardReplyAura,
    onReplyDeleted,
    awardLikeAura,
    awardAuraAction,
} from "./functions/aura.js";
export { freeAstroCalculate, calculateCompatibility, invalidateCompatibilityCache, searchGeoLocation } from "./functions/free_astro.js";
export { syncAstroProfile } from "./functions/astro_sync.js";
export { generateFirstReading } from "./functions/first_reading.js";
export { generateCurrentTimesReading } from "./functions/current_times_reading.js";
export {
    generateDailyAstroInsights,
    dispatchCardNotification, // Cloud Tasks worker for scheduled card notifications
    generateInsightForCurrentUser,
    clearAstroCaches,
    cleanupOldDispatchEntries, // Cleanup old insightDispatch entries (still needed by Cloud Tasks dispatch flow)
    cleanupExpiredCacheEntries, // Cleanup expired astroCache/astroCurrent entries
} from "./functions/daily_astro_insights.js";
export { processInsightTask } from "./functions/insight_worker.js"; // Queue-based insight generation worker

// ---------------------------------------------------------------------------
// Insights Engine — unified pipeline for AI-powered readings
// ---------------------------------------------------------------------------
export {
    enqueuePerHouseReadings,  // Daily scheduler: finds users with expired cycles
    processPerHouseTask,      // Cloud Tasks worker: runs one user's biweekly batch
    generatePerHouseNow,      // onCall: force regenerate for current user
} from "./insights/orchestration/per_house_scheduler.js";
export {
    submitInsightFeedback,
    toggleFavoriteInsight,
} from "./functions/astro_engagement.js";
// Migration functions removed after hash migration completed
export {
    indexUserPhone,
} from "./functions/phone_index.js";
export {
    matchContacts,
} from "./functions/contact_matching.js";
export {
    sendNamaste,
    getNamasteQuota,
} from "./functions/namaste.js";
export {
    onFollow,
    onFollowApproved,
    onUnfollow,
    acceptFollowRequest,
    rejectFollowRequest,
} from "./functions/follows.js";
export {
    onUserDeleted,
    cleanupStaleDeletions,
} from "./functions/user_deletion.js";
export {
    sendCallNotification,
    onCallStatusChanged,
} from "./functions/calls.js";
export {
    generateAgoraToken,
} from "./functions/agora_token.js";
export {
    onGroupCallActivity,
} from "./functions/group_call_notifications.js";
export {
    calculateAyurvedaProfile,
    calculateCurrentVikriti,
    resetAyurvedaProfile,
    getAyurvedaRecommendations,
    analyzeHealthTrends,
    nightlyHealthAnalysis,
    weeklyHealthAggregation,
    onHealthSnapshotWrite,
} from "./functions/ayurveda.js";
export {
    prefetchSkyPositions,
    getSkyPositions,
    getUpcomingEvents,
    refreshSkyPositionsDaily,
    getGlobalMuhurat,
    refreshMuhuratDaily,
} from "./functions/sky_positions.js";
export {
    submitAnonymousMessage,
} from "./functions/anonymous_messages.js";
export {
    createRepost,
    deleteRepost,
    onOriginalPostDeleted,
    onSpacePostDeleted,
} from "./functions/reposts.js";
// Cosmic Daily Intelligence
export {
    cosmicDailyScheduled,
    cosmicDailyManual,
} from "./functions/cosmic_daily.js";
// बृहत्संहिता — Mundane Astrology (Brihat Samhita)
export {
    generateMundaneForecast,
    getMundaneForecast,
    refreshMundanePanchanga,
} from "./mundane/index.js";
