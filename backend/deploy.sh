#!/bin/bash
#
# Aurogram Backend Deployment Script
#
# Usage:
#   ./deploy.sh [dev|prod] [all|functions|rules|storage|<function-name>]
#
# Examples:
#   ./deploy.sh dev                      # deploy all to dev (aurogram-dev)
#   ./deploy.sh prod                     # deploy all to prod (ty-dev-516d7) — asks for confirm
#   ./deploy.sh dev onHealthSnapshotWrite # deploy one function to dev
#   ./deploy.sh prod rules               # deploy Firestore rules to prod
#   ./deploy.sh dev functions            # deploy all functions to dev
#
# ENV is required. There is no "default" — being explicit prevents accidents.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

cd "$(dirname "$0")"

# ── Argument parsing ─────────────────────────────────────────────────────────

ENV="${1:-}"
TARGET="${2:-all}"

if [ -z "$ENV" ] || { [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; }; then
    echo -e "${RED}Error: first argument must be 'dev' or 'prod'${NC}"
    echo ""
    echo "  Usage: ./deploy.sh [dev|prod] [all|functions|rules|storage|<function-name>]"
    echo ""
    echo "  ./deploy.sh dev                       → deploy to aurogram-dev (safe)"
    echo "  ./deploy.sh prod                      → deploy to prod (asks for confirm)"
    echo "  ./deploy.sh dev onHealthSnapshotWrite → test one function in dev first"
    echo ""
    exit 1
fi

# ── Project resolution ───────────────────────────────────────────────────────

if [ "$ENV" = "prod" ]; then
    PROJECT="ty-dev-516d7"
    PROJECT_LABEL="Aurogram PROD (ty-dev-516d7)"
    FIREBASE_ALIAS="prod"
else
    PROJECT="aurogram-dev"
    PROJECT_LABEL="Aurogram dev (aurogram-dev)"
    FIREBASE_ALIAS="dev"
fi

# ── Header ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ENV" = "prod" ]; then
    echo -e "${RED}${BOLD}================================================${NC}"
    echo -e "${RED}${BOLD}  PRODUCTION DEPLOYMENT${NC}"
    echo -e "${RED}${BOLD}  Project: ${PROJECT_LABEL}${NC}"
    echo -e "${RED}${BOLD}  Target:  ${TARGET}${NC}"
    echo -e "${RED}${BOLD}================================================${NC}"
else
    echo -e "${CYAN}${BOLD}================================================${NC}"
    echo -e "${CYAN}${BOLD}  DEV DEPLOYMENT${NC}"
    echo -e "${CYAN}${BOLD}  Project: ${PROJECT_LABEL}${NC}"
    echo -e "${CYAN}${BOLD}  Target:  ${TARGET}${NC}"
    echo -e "${CYAN}${BOLD}================================================${NC}"
fi
echo ""

# ── Prod confirmation gate ───────────────────────────────────────────────────

if [ "$ENV" = "prod" ]; then
    echo -e "${RED}${BOLD}⚠️  You are about to deploy to PRODUCTION.${NC}"
    echo -e "${YELLOW}   Real users will be affected immediately.${NC}"
    echo -e "${YELLOW}   Have you tested this change in dev first?${NC}"
    echo ""
    echo -e "${BOLD}   Type 'yes-prod' to confirm:${NC} "
    read -r CONFIRM
    if [ "$CONFIRM" != "yes-prod" ]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
    echo ""
fi

# ── Prerequisites ────────────────────────────────────────────────────────────

echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}❌ Node.js not found. Install: brew install node@20${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Node.js $(node --version)"

if ! command -v firebase >/dev/null 2>&1; then
    echo -e "${YELLOW}  Installing Firebase CLI...${NC}"
    npm install -g firebase-tools
fi
echo -e "  ${GREEN}✓${NC} Firebase CLI $(firebase --version 2>/dev/null | head -1)"

if ! firebase login:list 2>/dev/null | grep -q "@"; then
    echo -e "${YELLOW}  Logging in to Firebase...${NC}"
    firebase login
fi
echo -e "  ${GREEN}✓${NC} Firebase authenticated"
echo ""

# ── Dependencies ─────────────────────────────────────────────────────────────

echo -e "${YELLOW}Installing dependencies...${NC}"
npm install --silent
echo -e "  ${GREEN}✓${NC} Dependencies ready"
echo ""

# ── Deploy ───────────────────────────────────────────────────────────────────

deploy_functions_all() {
    echo -e "${YELLOW}Deploying all Cloud Functions → ${PROJECT_LABEL}...${NC}"
    firebase deploy --only functions --project "$FIREBASE_ALIAS"
    echo -e "${GREEN}✓ All functions deployed${NC}"
}

deploy_function() {
    local fn=$1
    echo -e "${YELLOW}Deploying function '${fn}' → ${PROJECT_LABEL}...${NC}"
    if firebase deploy --only "functions:${fn}" --project "$FIREBASE_ALIAS"; then
        echo -e "${GREEN}✓ ${fn} deployed${NC}"
    else
        echo -e "${RED}❌ Failed to deploy ${fn}${NC}"
        echo ""
        echo "If this is a secret validation error, try:"
        echo "  1. Deploy via Firebase Console"
        echo "  2. Check VPC Service Controls permissions"
        exit 1
    fi
}

deploy_rules() {
    echo -e "${YELLOW}Deploying Firestore rules → ${PROJECT_LABEL}...${NC}"
    firebase deploy --only firestore:rules --project "$FIREBASE_ALIAS"
    echo -e "${GREEN}✓ Firestore rules deployed${NC}"
}

deploy_storage() {
    echo -e "${YELLOW}Deploying Storage rules → ${PROJECT_LABEL}...${NC}"
    firebase deploy --only storage --project "$FIREBASE_ALIAS"
    echo -e "${GREEN}✓ Storage rules deployed${NC}"
}

case "$TARGET" in
    "all")
        deploy_functions_all
        ;;
    "functions")
        deploy_functions_all
        ;;
    "rules"|"firestore")
        deploy_rules
        ;;
    "storage")
        deploy_storage
        ;;
    *)
        deploy_function "$TARGET"
        ;;
esac

# ── Footer ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ENV" = "prod" ]; then
    echo -e "${GREEN}${BOLD}================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ PROD deployment complete${NC}"
    echo -e "${GREEN}${BOLD}================================================${NC}"
else
    echo -e "${CYAN}${BOLD}================================================${NC}"
    echo -e "${CYAN}${BOLD}✅ DEV deployment complete${NC}"
    echo -e "${CYAN}${BOLD}================================================${NC}"
fi
echo ""
echo "  Logs:      firebase functions:log --project $FIREBASE_ALIAS"
echo "  Functions: firebase functions:list --project $FIREBASE_ALIAS"
if [ "$ENV" = "dev" ]; then
    echo ""
    echo -e "${YELLOW}  When ready for prod: ./deploy.sh prod ${TARGET}${NC}"
fi
echo ""
