#!/bin/bash
# ============================================================================
# Batched Firebase Functions Deploy
# ============================================================================
# Deploys 82 functions in 12 micro-batches (~5-10 each) to stay well
# under the 20 vCPU regional quota on Cloud Run.
#
# Max batch: 10 functions × 0.5 vCPU = 5 vCPU (25% of quota)
#
# Usage:
#   ./scripts/deploy.sh              # Deploy ALL batches sequentially
#   ./scripts/deploy.sh feeds        # Deploy one specific batch
#   ./scripts/deploy.sh --list       # Show all batch names
#   ./scripts/deploy.sh --dry-run    # Show what would deploy without doing it
# ============================================================================
set -e

# Resolve firebase CLI
FIREBASE="${FIREBASE_CLI:-$(command -v firebase 2>/dev/null || echo /usr/local/bin/firebase)}"
if [ ! -x "$FIREBASE" ]; then
    echo "❌ firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

PAUSE=10  # seconds between batches — let Cloud Run settle

# ── Social domain (29 total → 4 batches) ────────────────────────────

FEEDS="functions:addPostToFeeds,\
functions:addProfilePostToGlobalFeed,\
functions:deletePostFromGlobalFeed,\
functions:deleteSpacePostFromGlobalFeed,\
functions:cleanupOrphanedFeedEntries"

POSTS="functions:newPost,\
functions:deletePost,\
functions:newLike,\
functions:removeLike,\
functions:newInvite,\
functions:createRepost,\
functions:deleteRepost,\
functions:onOriginalPostDeleted,\
functions:onSpacePostDeleted"

AURA="functions:awardCreatePostAura,\
functions:awardCreateSpacePostAura,\
functions:awardReplyAura,\
functions:onReplyDeleted,\
functions:awardLikeAura,\
functions:awardAuraAction"

PEOPLE="functions:onFollow,\
functions:onFollowApproved,\
functions:onUnfollow,\
functions:acceptFollowRequest,\
functions:rejectFollowRequest,\
functions:sendNamaste,\
functions:getNamasteQuota,\
functions:submitAnonymousMessage,\
functions:sendPushNotification"

# ── Astro domain (30 total → 4 batches) ─────────────────────────────

ASTRO_CORE="functions:freeAstroCalculate,\
functions:calculateCompatibility,\
functions:invalidateCompatibilityCache,\
functions:searchGeoLocation,\
functions:syncAstroProfile"

ASTRO_DAILY="functions:generateDailyAstroInsights,\
functions:dispatchCardNotification,\
functions:cleanupOldDispatchEntries,\
functions:cleanupExpiredCacheEntries,\
functions:processInsightTask"

ASTRO_READINGS="functions:generateFirstReading,\
functions:generateCurrentTimesReading,\
functions:generateInsightForCurrentUser,\
functions:clearAstroCaches,\
functions:submitInsightFeedback,\
functions:toggleFavoriteInsight,\
functions:enqueuePerHouseReadings,\
functions:processPerHouseTask,\
functions:generatePerHouseNow"

ASTRO_SKY="functions:prefetchSkyPositions,\
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

# ── Health domain (8 → 1 batch) ─────────────────────────────────────

HEALTH="functions:calculateAyurvedaProfile,\
functions:calculateCurrentVikriti,\
functions:resetAyurvedaProfile,\
functions:getAyurvedaRecommendations,\
functions:analyzeHealthTrends,\
functions:nightlyHealthAnalysis,\
functions:weeklyHealthAggregation,\
functions:onHealthSnapshotWrite"

# ── Comms domain (10 → 1 batch) ─────────────────────────────────────

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

# ── System domain (5 → 1 batch) ─────────────────────────────────────

SYSTEM="functions:onUserDeleted,\
functions:cleanupStaleDeletions,\
functions:indexUserPhone,\
functions:matchContacts,\
functions:getLinkPreview"

# ── Batch registry (order matters — deploy least-risky first) ────────

BATCH_NAMES=(
    system
    feeds
    aura
    posts
    people
    health
    comms
    astro-core
    astro-daily
    astro-readings
    astro-sky
)

get_batch_label() {
    case "$1" in
        system)         echo "System (5)" ;;
        feeds)          echo "Feeds (5)" ;;
        aura)           echo "Aura (6)" ;;
        posts)          echo "Posts & Reposts (9)" ;;
        people)         echo "Follows & Social (9)" ;;
        health)         echo "Ayurveda (8)" ;;
        comms)          echo "Chat & Calls (10)" ;;
        astro-core)     echo "Astro Core (5)" ;;
        astro-daily)    echo "Daily Insights (5)" ;;
        astro-readings) echo "Readings & Engine (9)" ;;
        astro-sky)      echo "Sky & Mundane (11)" ;;
        *)              echo "$1" ;;
    esac
}

get_batch_funcs() {
    case "$1" in
        system)         echo "$SYSTEM" ;;
        feeds)          echo "$FEEDS" ;;
        aura)           echo "$AURA" ;;
        posts)          echo "$POSTS" ;;
        people)         echo "$PEOPLE" ;;
        health)         echo "$HEALTH" ;;
        comms)          echo "$COMMS" ;;
        astro-core)     echo "$ASTRO_CORE" ;;
        astro-daily)    echo "$ASTRO_DAILY" ;;
        astro-readings) echo "$ASTRO_READINGS" ;;
        astro-sky)      echo "$ASTRO_SKY" ;;
    esac
}

deploy_batch() {
    local name=$1
    local label
    label=$(get_batch_label "$name")
    local funcs
    funcs=$(get_batch_funcs "$name")

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    printf "║  [%2d/%-2d] %-40s║\n" "$BATCH_NUM" "$BATCH_TOTAL" "$label"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        echo "  (dry-run) would deploy: $funcs"
        return
    fi

    "$FIREBASE" deploy --only "$funcs" --force
    echo ""
    echo "  ✅ $label deployed"
}

# ── CLI handling ─────────────────────────────────────────────────────

# --list: show available batches
if [ "$1" = "--list" ]; then
    echo "Available batches:"
    for name in "${BATCH_NAMES[@]}"; do
        printf "  %-16s  %s\n" "$name" "$(get_batch_label "$name")"
    done
    exit 0
fi

# --dry-run: show what would deploy
DRY_RUN="false"
if [ "$1" = "--dry-run" ]; then
    DRY_RUN="true"
    shift
fi

# Single batch
if [ -n "$1" ]; then
    # Support comma-separated: deploy.sh feeds,aura,posts
    IFS=',' read -ra TARGETS <<< "$1"
    BATCH_TOTAL=${#TARGETS[@]}
    BATCH_NUM=0
    for target in "${TARGETS[@]}"; do
        BATCH_NUM=$((BATCH_NUM + 1))
        funcs=$(get_batch_funcs "$target")
        if [ -z "$funcs" ]; then
            echo "❌ Unknown batch: $target"
            echo "Run: $0 --list"
            exit 1
        fi
        deploy_batch "$target"
        if [ "$BATCH_NUM" -lt "$BATCH_TOTAL" ] && [ "$DRY_RUN" != "true" ]; then
            echo "  ⏳ Pausing ${PAUSE}s before next batch..."
            sleep "$PAUSE"
        fi
    done
    exit 0
fi

# Deploy ALL batches
BATCH_TOTAL=${#BATCH_NAMES[@]}
BATCH_NUM=0

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Tribes Backend — Full Deploy                   ║"
echo "║  ${BATCH_TOTAL} micro-batches, max 11 functions each      ║"
echo "║  ~5 vCPU per batch (25% of 20 vCPU quota)      ║"
echo "╚══════════════════════════════════════════════════╝"

for name in "${BATCH_NAMES[@]}"; do
    BATCH_NUM=$((BATCH_NUM + 1))
    deploy_batch "$name"

    if [ "$BATCH_NUM" -lt "$BATCH_TOTAL" ] && [ "$DRY_RUN" != "true" ]; then
        echo "  ⏳ Pausing ${PAUSE}s..."
        sleep "$PAUSE"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅ All ${BATCH_TOTAL} batches deployed!                   ║"
echo "╚══════════════════════════════════════════════════╝"
