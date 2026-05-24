#!/bin/bash
# ============================================================================
# Batched Firebase Functions Deploy — Consolidated Architecture
# ============================================================================
# Deploys the 20 consolidated Cloud Functions in 6 micro-batches to stay
# well under the 20 vCPU regional Cloud Run quota.
#
# With cpu:1 + maxInstances:1, each function = 1 vCPU during health check.
# 5 functions per batch = 5 vCPU burst — safely under 20 vCPU even with
# existing running instances.
#
# Architecture map (20 functions total):
#   • 5 gateways         — astro, insight, health, social, comms
#   • 1 scheduler        — unifiedOrchestrator (replaces 14 onSchedule)
#   • 1 task worker      — taskRouter        (replaces 3 onTaskDispatched)
#   • 7 path-merged triggers (onDocumentWritten on shared paths)
#   • 5 unique-path triggers
#   • 1 HTTP streaming   — aiChat (onRequest with SSE; can't be in a gateway)
#
# Note: User-deletion cleanup (previously the `onUserDeleted` v1 auth trigger)
# is now folded into `unifiedOrchestrator` Phase 1 via a tombstone sweep,
# saving 1 vCPU and removing the only remaining v1 function.
#
# Usage:
#   ./scripts/deploy.sh                       # Deploy ALL batches sequentially
#   ./scripts/deploy.sh gateways              # Deploy one specific batch
#   ./scripts/deploy.sh gateways,workers      # Deploy multiple batches
#   ./scripts/deploy.sh --list                # Show all batch names
#   ./scripts/deploy.sh --dry-run             # Show what would deploy
# ============================================================================
set -e

FIREBASE="${FIREBASE_CLI:-$(command -v firebase 2>/dev/null || echo /usr/local/bin/firebase)}"
if [ ! -x "$FIREBASE" ]; then
    echo "firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

PAUSE=30  # seconds between batches — Cloud Run needs time to scale down

# ── Gateways (5 onCall routers) ───────────────────────────────────────
GATEWAYS="functions:astroGateway,\
functions:insightGateway,\
functions:healthGateway,\
functions:socialGateway,\
functions:commsGateway"

# ── Workers (1 scheduler + 1 task router) ─────────────────────────────
WORKERS="functions:unifiedOrchestrator,\
functions:taskRouter"

# ── Path-merged Firestore triggers (7) — content paths ────────────────
TRIGGERS_CONTENT="functions:onPostWrite,\
functions:onSpacePostWrite,\
functions:onReplyWrite,\
functions:onChatCreated"

# ── Path-merged Firestore triggers — engagement & social paths ────────
TRIGGERS_ENGAGEMENT="functions:onPostLikeWrite,\
functions:onFollowWrite,\
functions:onCallWrite"

# ── Unique-path Firestore triggers (5) ────────────────────────────────
TRIGGERS_UNIQUE="functions:sendPushNotification,\
functions:newInvite,\
functions:onSpacePostDeleted,\
functions:onHealthSnapshotWrite,\
functions:onGroupCallActivity"

# ── Standalone HTTP endpoint (SSE — can't be merged into a gateway) ──
STANDALONE="functions:aiChat"

# ── Batch registry ────────────────────────────────────────────────────

BATCH_NAMES=(
    gateways
    workers
    triggers-content
    triggers-engagement
    triggers-unique
    standalone
)

get_batch_label() {
    case "$1" in
        gateways)             echo "Gateways (5)" ;;
        workers)              echo "Workers — scheduler + task router (2)" ;;
        triggers-content)     echo "Triggers — content paths (4)" ;;
        triggers-engagement)  echo "Triggers — engagement & social (3)" ;;
        triggers-unique)      echo "Triggers — unique paths (5)" ;;
        standalone)           echo "Standalone — aiChat (1)" ;;
        *)                    echo "$1" ;;
    esac
}

get_batch_funcs() {
    case "$1" in
        gateways)             echo "$GATEWAYS" ;;
        workers)              echo "$WORKERS" ;;
        triggers-content)     echo "$TRIGGERS_CONTENT" ;;
        triggers-engagement)  echo "$TRIGGERS_ENGAGEMENT" ;;
        triggers-unique)      echo "$TRIGGERS_UNIQUE" ;;
        standalone)           echo "$STANDALONE" ;;
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
    echo "Available batches (${#BATCH_NAMES[@]} total, 20 functions):"
    echo ""
    for name in "${BATCH_NAMES[@]}"; do
        printf "  %-22s  %s\n" "$name" "$(get_batch_label "$name")"
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
echo "║  ${BATCH_TOTAL} batches, 20 consolidated functions     ║"
echo "║  ≤5 vCPU per batch (25% of 20 vCPU quota)      ║"
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
