#!/bin/bash

# Test Cloud Function via HTTP
# Requires: TEST_USER_ID environment variable
# Requires: Firebase project ID

set -e

PROJECT_ID=${FIREBASE_PROJECT_ID:-"your-project-id"}
REGION="us-central1"
FUNCTION_NAME="generateInsightForCurrentUser"
TEST_USER_ID=${TEST_USER_ID:-""}

if [ -z "$TEST_USER_ID" ]; then
    echo "❌ ERROR: TEST_USER_ID not set"
    echo "Set it with: export TEST_USER_ID='your-user-id'"
    exit 1
fi

echo "🚀 Testing Cloud Function via HTTP..."
echo "Project: $PROJECT_ID"
echo "User ID: $TEST_USER_ID"
echo ""

# Get auth token (requires firebase-tools)
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

# Get auth token
echo "📝 Getting auth token..."
TOKEN=$(firebase login:ci --no-localhost 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo "⚠️  Could not get auth token automatically"
    echo "   You may need to authenticate manually"
    TOKEN="YOUR_AUTH_TOKEN_HERE"
fi

# Call the function
echo "📞 Calling Cloud Function..."
RESPONSE=$(curl -s -X POST \
  "https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{}")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"



