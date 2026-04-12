// Cloud Functions exports
// OPTIMIZED: addPostToGlobalFeed and newSpacePost merged into addPostToFeeds
// This reduces 3 function invocations to 1 per space post
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
    awardNamasteAura,
    awardCreatePostAura,
    awardCreateSpacePostAura,
    awardReplyAura,
    onReplyDeleted,
    awardLikeAura,
    awardAuraAction,
    getUserAuraRank,
    getAuraLeaderboard,
    awardManualAura,
} from "./functions/aura.js";
export { freeAstroCalculate, calculateCompatibility, invalidateCompatibilityCache, searchGeoLocation } from "./functions/free_astro.js";
export { syncAstroProfile } from "./functions/astro_sync.js";
export { generateFirstReading, getFirstReading } from "./functions/first_reading.js";
export { generateCurrentTimesReading } from "./functions/current_times_reading.js";
export {
    generateDailyAstroInsights,
    dispatchCardNotification, // NEW: Cloud Tasks worker for scheduled card notifications
    dispatchScheduledInsights, // DEPRECATED: Kept for backward compatibility
    generateInsightForCurrentUser,
    getAstroInsightSystemHealth,
    checkPendingPredictions,
    clearAstroCaches,
    cleanupOldDispatchEntries, // DEPRECATED: Cleanup old dispatch entries (kept for migration)
    cleanupExpiredCacheEntries, // Cleanup expired astroCache/astroCurrent entries
} from "./functions/daily_astro_insights.js";
export { processInsightTask } from "./functions/insight_worker.js"; // Queue-based insight generation worker
export {
    trackInsightView,
    submitInsightFeedback,
    toggleFavoriteInsight,
    getUserEngagement,
} from "./functions/astro_engagement.js";
// Migration functions removed after hash migration completed
export {
    indexUserPhone,
} from "./functions/phone_index.js";
export {
    matchContacts,
    getMatchingInsights,
} from "./functions/contact_matching.js";
export {
    sendNamaste,
    getNamasteQuota,
    canSendNamaste,
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
export {
    generateDailyNewsDigest,
    testDailyNewsDigest,
} from "./functions/ai_daily_digest.js";
// Cosmic Daily Intelligence
export {
    cosmicDailyScheduled,
    cosmicDailyManual,
} from "./functions/cosmic_daily.js";
