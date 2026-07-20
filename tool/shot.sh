#!/usr/bin/env bash
# Aurogram web: screenshot the RUNNING Chrome tab via CDP (read-only, no reload).
# Writes /tmp/aurogram_shot_0.png. Auto-discovers the CDP port + page target,
# so it survives flutter-run restarts (which reshuffle all the ports).
set -euo pipefail

CHROME_PID=$(pgrep -f flutter_tools_chrome_device | head -1 || true)
if [ -z "$CHROME_PID" ]; then
  echo "No flutter Chrome device process found. Is 'flutter run -d chrome' alive?" >&2
  exit 1
fi
PORT=$(ps -o command= -p "$CHROME_PID" | tr ' ' '\n' \
  | grep -oE 'remote-debugging-port=[0-9]+' | cut -d= -f2)
if [ -z "$PORT" ]; then
  echo "Couldn't read remote-debugging-port from Chrome args." >&2
  exit 1
fi
PAGE=$(curl -s --max-time 3 "http://127.0.0.1:${PORT}/json" \
  | python3 -c "import sys,json;print(next(t['webSocketDebuggerUrl'] for t in json.load(sys.stdin) if t['type']=='page'))")
echo "CDP :$PORT -> $PAGE"
dart run tool/cdp_shot.dart "$PAGE"
