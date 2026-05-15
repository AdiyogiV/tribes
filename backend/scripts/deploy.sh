#!/bin/bash
# ============================================================================
# Batched Firebase Functions Deploy
# ============================================================================
# Deploys 81 functions in 5 domain batches to stay under the 20 vCPU
# regional quota on Cloud Run. Each batch: ~10-28 functions × 0.5 vCPU
# = 5-14 vCPU, safely under the limit.
#
# Usage:
#   ./scripts/deploy.sh          # Deploy all batches sequentially
#   ./scripts/deploy.sh social   # Deploy only the social batch
#   ./scripts/deploy.sh astro    # Deploy only the astro batch
#   ./scripts/deploy.sh health   # Deploy only the health batch
#   ./scripts/deploy.sh comms    # Deploy only the comms batch
#   ./scripts/deploy.sh system   # Deploy only the system batch
# ============================================================================
set -e

SOCIAL="functions:addPostToFeeds,\
functions:addProfilePostToGlobalFeed,\
functions:deletePostFromGlobalFeed,\
functions:deleteSpacePostFromGlobalFeed,\
functions:cleanupOrphanedFeedEntries,\
functions:sendPushNotification,\
functions:newPost,\
functions:deletePost,\
functions:newLike,\
functions:removeLike,\
functions:newInvite,\
functions:awardCreatePostAura,\
functions:awardCreateSpacePostAura,\
functions:awardReplyAura,\
functions:onReplyDeleted,\
functions:awardLikeAura,\
functions:awardAuraAction,\
functions:onFollow,\
functions:onFollowApproved,\
functions:onUnfollow,\
functions:acceptFollowRequest,\
functions:rejectFollowRequest,\
functions:sendNamaste,\
functions:getNamasteQuota,\
functions:submitAnonymousMessage,\
functions:createRepost,\
functions:deleteRepost,\
functions:onOriginalPostDeleted,\
functions:onSpacePostDeleted"

ASTRO="functions:freeAstroCalculate,\
functions:calculateCompatibility,\
functions:invalidateCompatibilityCache,\
functions:searchGeoLocation,\
functions:syncAstroProfile,\
functions:generateFirstReading,\
functions:generateCurrentTimesReading,\
functions:generateDailyAstroInsights,\
functions:dispatchCardNotification,\
functions:generateInsightForCurrentUser,\
functions:clearAstroCaches,\
functions:cleanupOldDispatchEntries,\
functions:cleanupExpiredCacheEntries,\
functions:processInsightTask,\
functions:enqueuePerHouseReadings,\
functions:processPerHouseTask,\
functions:generatePerHouseNow,\
functions:submitInsightFeedback,\
functions:toggleFavoriteInsight,\
functions:prefetchSkyPositions,\
functions:getSkyPositions,\
functions:getUpcomingEvents,\
functions:refreshSkyPositionsDaily,\
functions:getGlobalMuhurat,\
functions:refreshMuhuratDaily,\
functions:cosmicDailyScheduled,\
functions:cosmicDailyManual,\
functions:generateMundaneForecast,\
functions:getMundaneForecast,\
functions:refreshMundanePanchanga"

HEALTH="functions:calculateAyurvedaProfile,\
functions:calculateCurrentVikriti,\
functions:resetAyurvedaProfile,\
functions:getAyurvedaRecommendations,\
functions:analyzeHealthTrends,\
functions:nightlyHealthAnalysis,\
functions:weeklyHealthAggregation,\
functions:onHealthSnapshotWrite"

COMMS="functions:onNewChatMessage,\
functions:filterChatMessage,\
functions:cleanupTypingIndicators,\
functions:sendCallNotification,\
functions:onCallStatusChanged,\
functions:generateAgoraToken,\
functions:onGroupCallActivity,\
functions:aiChat,\
functions:getChatPromptConfig,\
functions:cleanupAiChatSessions"

SYSTEM="functions:onUserDeleted,\
functions:cleanupStaleDeletions,\
functions:indexUserPhone,\
functions:matchContacts,\
functions:getLinkPreview"

deploy_batch() {
    local name=$1
    local funcs=$2
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  Deploying: $name"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    firebase deploy --only "$funcs" --force
    echo ""
    echo "✅ $name batch deployed successfully"
    echo ""
}

# If a specific batch is requested, deploy only that
if [ -n "$1" ]; then
    case "$1" in
        social)  deploy_batch "Social (29 functions)" "$SOCIAL" ;;
        astro)   deploy_batch "Astro (30 functions)" "$ASTRO" ;;
        health)  deploy_batch "Health (8 functions)" "$HEALTH" ;;
        comms)   deploy_batch "Comms (10 functions)" "$COMMS" ;;
        system)  deploy_batch "System (5 functions)" "$SYSTEM" ;;
        *)
            echo "Unknown batch: $1"
            echo "Usage: $0 [social|astro|health|comms|system]"
            exit 1
            ;;
    esac
    exit 0
fi

# Deploy all batches sequentially
echo "============================================"
echo "  Tribes Backend — Batched Deploy"
echo "  5 domain batches, ~15s pause between"
echo "============================================"

deploy_batch "Social (29 functions)" "$SOCIAL"
sleep 15

deploy_batch "Astro (30 functions)" "$ASTRO"
sleep 15

deploy_batch "Health (8 functions)" "$HEALTH"
sleep 15

deploy_batch "Comms (10 functions)" "$COMMS"
sleep 15

deploy_batch "System (5 functions)" "$SYSTEM"

echo ""
echo "============================================"
echo "  ✅ All 5 batches deployed successfully!"
echo "============================================"
