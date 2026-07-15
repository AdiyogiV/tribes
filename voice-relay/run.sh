#!/usr/bin/env bash
# Start the Aurobhatt voice relay. Usage: ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json"
export CX_AGENT_ID="${CX_AGENT_ID:-58d722c1-df7d-41d9-8a92-85d88feeda81}"
export CX_LOCATION="${CX_LOCATION:-global}"
export CX_LANGUAGE="${CX_LANGUAGE:-en-IN}"
export PORT="${PORT:-8080}"
echo "LAN URL for the app:  ws://$(ipconfig getifaddr en0 2>/dev/null || echo 127.0.0.1):$PORT/voice"
exec node src/server.js
