#!/bin/bash
# Trigger sky positions prefetch via Firebase CLI
# Usage: ./prefetch_sky.sh [daysBack] [daysAhead]

DAYS_BACK=${1:-30}
DAYS_AHEAD=${2:-30}

echo "🚀 Triggering sky positions prefetch..."
echo "   Range: -$DAYS_BACK to +$DAYS_AHEAD days"
echo ""

# Call the cloud function
firebase functions:shell <<EOF
prefetchSkyPositions({daysBack: $DAYS_BACK, daysAhead: $DAYS_AHEAD})
EOF

echo ""
echo "✅ Prefetch triggered. Check Firebase logs for status."
