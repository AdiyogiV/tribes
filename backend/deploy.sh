#!/bin/bash
#
# Tribes Backend Deployment Script
# Usage: ./deploy.sh [all|functions|rules|specific-function-name]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd "$(dirname "$0")"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 Tribes Backend Deployment${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    # Check Node.js
    if ! command_exists node; then
        echo -e "${RED}❌ Node.js not found. Install it with: brew install node@20${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Node.js $(node --version)"
    
    # Check Firebase CLI
    if ! command_exists firebase; then
        echo -e "${YELLOW}  Installing Firebase CLI...${NC}"
        npm install -g firebase-tools
    fi
    echo -e "  ${GREEN}✓${NC} Firebase CLI $(firebase --version)"
    
    # Check Firebase login
    if ! firebase login:list 2>/dev/null | grep -q "@"; then
        echo -e "${YELLOW}  Logging into Firebase...${NC}"
        firebase login
    fi
    echo -e "  ${GREEN}✓${NC} Firebase authenticated"
    echo ""
}

# Install dependencies
install_deps() {
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    npm install --silent
    echo -e "  ${GREEN}✓${NC} Dependencies installed"
    echo ""
}

# Deploy all functions
deploy_all() {
    echo -e "${YELLOW}☁️  Deploying all Cloud Functions...${NC}"
    firebase deploy --only functions
    echo -e "${GREEN}✓ All functions deployed${NC}"
}

# Deploy specific function
deploy_function() {
    local func_name=$1
    echo -e "${YELLOW}☁️  Deploying function: ${func_name}...${NC}"
    if firebase deploy --only "functions:${func_name}"; then
        echo -e "${GREEN}✓ ${func_name} deployed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to deploy ${func_name}${NC}"
        echo ""
        echo "If this is a secret validation error, try:"
        echo "  1. Deploy via Firebase Console"
        echo "  2. Check VPC Service Controls permissions"
        exit 1
    fi
}

# Deploy Firestore rules
deploy_rules() {
    echo -e "${YELLOW}📜 Deploying Firestore rules...${NC}"
    firebase deploy --only firestore:rules
    echo -e "${GREEN}✓ Firestore rules deployed${NC}"
}

# Deploy Storage rules  
deploy_storage() {
    echo -e "${YELLOW}📦 Deploying Storage rules...${NC}"
    firebase deploy --only storage
    echo -e "${GREEN}✓ Storage rules deployed${NC}"
}

# Main execution
check_prerequisites
install_deps

case "${1:-all}" in
    "all")
        deploy_all
        ;;
    "functions")
        deploy_all
        ;;
    "rules")
        deploy_rules
        deploy_storage
        ;;
    "firestore")
        deploy_rules
        ;;
    "storage")
        deploy_storage
        ;;
    *)
        deploy_function "$1"
        ;;
esac

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "View logs: firebase functions:log"
echo "List functions: firebase functions:list"
echo ""
