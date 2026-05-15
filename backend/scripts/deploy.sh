#!/bin/bash
# ============================================================================
# Batched Firebase Functions Deploy
# ============================================================================
# Deploys 82 functions in 21 micro-batches (max 4 each) to stay well
# under the 20 vCPU regional quota on Cloud Run.
#
# With cpu:1 + maxInstances:1, each function = 1 vCPU during health check.
# 4 functions per batch = 4 vCPU burst — safely under 20 vCPU even with
# existing running instances.
#
# Usage:
#   ./scripts/deploy.sh              # Deploy ALL batches sequentially
#   ./scripts/deploy.sh feeds        # Deploy one specific batch
#   ./scripts/deploy.sh feeds,aura   # Deploy multiple batches
#   ./scripts/deploy.sh --list       # Show all batch names
#   ./scripts/deploy.sh --dry-run    # Show what would deploy without doing it
# ============================================================================
set -e

FIREBASE="${FIREBASE_CLI:-$(command -v firebase 2>/dev/null || echo /usr/local/bin/firebase)}"
if [ ! -x "$FIREBASE" ]; then
    echo "firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

PAUSE=30  # seconds between batches — Cloud Run needs time to scale down

# ── System (5 → 2 batches) ─────────────────────────────────────────
SYSTEM_1="functions:onUserDeleted,\
functions:cleanupStaleDeletions,\
functions:indexUserPhone"

SYSTEM_2="functions:matchContacts,\
functions:getLinkPreview"

# ── Feeds (5 → 2 batches) ──────────────────────────────────────────
FEEDS_1="functions:addPostToFeeds,\
functions:addProfilePostToGlobalFeed,\
functions:deletePostFromGlobalFeed"

FEEDS_2="functions:deleteSpacePostFromGlobalFeed,\
functions:cleanupOrphanedFeedEntries"

# ── Aura (6 → 2 batches) ───────────────────────────────────────────
AURA_1="functions:awardCreatePostAura,\
functions:awardCreateSpacePostAura,\
functions:awardReplyAura"

AURA_2="functions:onReplyDeleted,\
functions:awardLikeAura,\
functions:awardAuraAction"

# ── Posts (9 → 3 batches) ──────────────────────────────────────────
POSTS_1="functions:newPost,\
functions:deletePost,\
functions:newLike"

POSTS_2="functions:removeLike,\
functions:newInvite,\
functions:createRepost"

POSTS_3="functions:deleteRepost,\
functions:onOriginalPostDeleted,\
functions:onSpacePostDeleted"

# ── People (9 → 3 batches) ─────────────────────────────────────────
PEOPLE_1="functions:onFollow,\
functions:onFollowApproved,\
functions:onUnfollow"

PEOPLE_2="functions:acceptFollowRequest,\
functions:rejectFollowRequest,\
functions:sendNamaste"

PEOPLE_3="functions:getNamasteQuota,\
functions:submitAnonymousMessage,\
functions:sendPushNotification"

# ── Health (8 → 2 batches) ─────────────────────────────────────────
HEALTH_1="functions:calculateAyurvedaProfile,\
functions:calculateCurrentVikriti,\
functions:resetAyurvedaProfile,\
functions:getAyurvedaRecommendations"

HEALTH_2="functions:analyzeHealthTrends,\
functions:nightlyHealthAnalysis,\
functions:weeklyHealthAggregation,\
functions:onHealthSnapshotWrite"

# ── Comms (10 → 3 batches) ─────────────────────────────────────────
COMMS_1="functions:onNewChatMessage,\
functions:filterChatMessage,\
functions:cleanupTypingIndicators"

COMMS_2="functions:sendCallNotification,\
functions:onCallStatusChanged,\
functions:generateAgoraToken,\
functions:onGroupCallActivity"

COMMS_3="functions:aiChat,\
functions:getChatPromptConfig,\
functions:cleanupAiChatSessions"

# ── Astro Core (5 → 2 batches) ─────────────────────────────────────
ASTRO_CORE_1="functions:freeAstroCalculate,\
functions:calculateCompatibility,\
functions:invalidateCompatibilityCache"

ASTRO_CORE_2="functions:searchGeoLocation,\
functions:syncAstroProfile"

# ── Astro Daily (5 → 2 batches) ────────────────────────────────────
ASTRO_DAILY_1="functions:generateDailyAstroInsights,\
functions:dispatchCardNotification,\
functions:cleanupOldDispatchEntries"

ASTRO_DAILY_2="functions:cleanupExpiredCacheEntries,\
functions:processInsightTask"

# ── Astro Readings (9 → 3 batches) ─────────────────────────────────
ASTRO_READ_1="functions:generateFirstReading,\
functions:generateCurrentTimesReading,\
functions:generateInsightForCurrentUser"

ASTRO_READ_2="functions:clearAstroCaches,\
functions:submitInsightFeedback,\
functions:toggleFavoriteInsight"

ASTRO_READ_3="functions:enqueuePerHouseReadings,\
functions:processPerHouseTask,\
functions:generatePerHouseNow"

# ── Astro Sky (11 → 3 batches) ─────────────────────────────────────
ASTRO_SKY_1="functions:prefetchSkyPositions,\
functions:getSkyPositions,\
functions:getUpcomingEvents,\
functions:refreshSkyPositionsDaily"

ASTRO_SKY_2="functions:getGlobalMuhurat,\
functions:refreshMuhuratDaily,\
functions:cosmicDailyScheduled,\
functions:cosmicDailyManual"

ASTRO_SKY_3="functions:generateMundaneForecast,\
functions:getMundaneForecast,\
functions:refreshMundanePanchanga"

# ── Batch registry ──────────────────────────────────────────────────

BATCH_NAMES=(
    system-1 system-2
    feeds-1 feeds-2
    aura-1 aura-2
    posts-1 posts-2 posts-3
    people-1 people-2 people-3
    health-1 health-2
    comms-1 comms-2 comms-3
    astro-core-1 astro-core-2
    astro-daily-1 astro-daily-2
    astro-read-1 astro-read-2 astro-read-3
    astro-sky-1 astro-sky-2 astro-sky-3
)

get_batch_label() {
    case "$1" in
        system-1)      echo "System 1/2 (3)" ;;
        system-2)      echo "System 2/2 (2)" ;;
        feeds-1)       echo "Feeds 1/2 (3)" ;;
        feeds-2)       echo "Feeds 2/2 (2)" ;;
        aura-1)        echo "Aura 1/2 (3)" ;;
        aura-2)        echo "Aura 2/2 (3)" ;;
        posts-1)       echo "Posts 1/3 (3)" ;;
        posts-2)       echo "Posts 2/3 (3)" ;;
        posts-3)       echo "Posts 3/3 (3)" ;;
        people-1)      echo "People 1/3 (3)" ;;
        people-2)      echo "People 2/3 (3)" ;;
        people-3)      echo "People 3/3 (3)" ;;
        health-1)      echo "Health 1/2 (4)" ;;
        health-2)      echo "Health 2/2 (4)" ;;
        comms-1)       echo "Comms 1/3 (3)" ;;
        comms-2)       echo "Comms 2/3 (4)" ;;
        comms-3)       echo "Comms 3/3 (3)" ;;
        astro-core-1)  echo "Astro Core 1/2 (3)" ;;
        astro-core-2)  echo "Astro Core 2/2 (2)" ;;
        astro-daily-1) echo "Astro Daily 1/2 (3)" ;;
        astro-daily-2) echo "Astro Daily 2/2 (2)" ;;
        astro-read-1)  echo "Readings 1/3 (3)" ;;
        astro-read-2)  echo "Readings 2/3 (3)" ;;
        astro-read-3)  echo "Readings 3/3 (3)" ;;
        astro-sky-1)   echo "Sky 1/3 (4)" ;;
        astro-sky-2)   echo "Sky 2/3 (4)" ;;
        astro-sky-3)   echo "Sky 3/3 (3)" ;;
        *)             echo "$1" ;;
    esac
}

get_batch_funcs() {
    case "$1" in
        system-1)      echo "$SYSTEM_1" ;;
        system-2)      echo "$SYSTEM_2" ;;
        feeds-1)       echo "$FEEDS_1" ;;
        feeds-2)       echo "$FEEDS_2" ;;
        aura-1)        echo "$AURA_1" ;;
        aura-2)        echo "$AURA_2" ;;
        posts-1)       echo "$POSTS_1" ;;
        posts-2)       echo "$POSTS_2" ;;
        posts-3)       echo "$POSTS_3" ;;
        people-1)      echo "$PEOPLE_1" ;;
        people-2)      echo "$PEOPLE_2" ;;
        people-3)      echo "$PEOPLE_3" ;;
        health-1)      echo "$HEALTH_1" ;;
        health-2)      echo "$HEALTH_2" ;;
        comms-1)       echo "$COMMS_1" ;;
        comms-2)       echo "$COMMS_2" ;;
        comms-3)       echo "$COMMS_3" ;;
        astro-core-1)  echo "$ASTRO_CORE_1" ;;
        astro-core-2)  echo "$ASTRO_CORE_2" ;;
        astro-daily-1) echo "$ASTRO_DAILY_1" ;;
        astro-daily-2) echo "$ASTRO_DAILY_2" ;;
        astro-read-1)  echo "$ASTRO_READ_1" ;;
        astro-read-2)  echo "$ASTRO_READ_2" ;;
        astro-read-3)  echo "$ASTRO_READ_3" ;;
        astro-sky-1)   echo "$ASTRO_SKY_1" ;;
        astro-sky-2)   echo "$ASTRO_SKY_2" ;;
        astro-sky-3)   echo "$ASTRO_SKY_3" ;;
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
    echo "  $label deployed"
}

# ── CLI handling ─────────────────────────────────────────────────────

if [ "$1" = "--list" ]; then
    echo "Available batches (27 total, max 4 functions each):"
    echo ""
    for name in "${BATCH_NAMES[@]}"; do
        printf "  %-16s  %s\n" "$name" "$(get_batch_label "$name")"
    done
    exit 0
fi

DRY_RUN="false"
if [ "$1" = "--dry-run" ]; then
    DRY_RUN="true"
    shift
fi

# Single or comma-separated batches
if [ -n "$1" ]; then
    IFS=',' read -ra TARGETS <<< "$1"
    BATCH_TOTAL=${#TARGETS[@]}
    BATCH_NUM=0
    for target in "${TARGETS[@]}"; do
        BATCH_NUM=$((BATCH_NUM + 1))
        funcs=$(get_batch_funcs "$target")
        if [ -z "$funcs" ]; then
            echo "Unknown batch: $target"
            echo "Run: $0 --list"
            exit 1
        fi
        deploy_batch "$target"
        if [ "$BATCH_NUM" -lt "$BATCH_TOTAL" ] && [ "$DRY_RUN" != "true" ]; then
            echo "  Pausing ${PAUSE}s before next batch..."
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
echo "║  ${BATCH_TOTAL} micro-batches, max 4 functions each       ║"
echo "║  ~4 vCPU per batch (20% of 20 vCPU quota)      ║"
echo "║  30s pause between batches                      ║"
echo "╚══════════════════════════════════════════════════╝"

for name in "${BATCH_NAMES[@]}"; do
    BATCH_NUM=$((BATCH_NUM + 1))
    deploy_batch "$name"

    if [ "$BATCH_NUM" -lt "$BATCH_TOTAL" ] && [ "$DRY_RUN" != "true" ]; then
        echo "  Pausing ${PAUSE}s..."
        sleep "$PAUSE"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  All ${BATCH_TOTAL} batches deployed!                     ║"
echo "╚══════════════════════════════════════════════════╝"
