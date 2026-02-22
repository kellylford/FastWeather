#!/bin/bash
# Waits for the expand-us-cities-100 background job to finish, then distributes
# the updated us-cities-cached.json to all platforms.
#
# Usage: run this in any terminal and leave it — it will print status every 30s
# and auto-distribute when done.

set -euo pipefail

SCRIPT_NAME="expand-us-cities-100.py"
CACHEDATA_DIR="$(cd "$(dirname "$0")/CityData" && pwd)"
LOG_FILE="$(dirname "$0")/expand-cities.log"

echo "⏳ Waiting for city expansion job to finish..."
echo "   (checking every 30 seconds, log: $LOG_FILE)"
echo ""

while pgrep -f "$SCRIPT_NAME" > /dev/null 2>&1; do
    CURRENT=$(tail -5 "$LOG_FILE" 2>/dev/null | grep -E "^\[" | tail -1)
    echo "   Still running — $CURRENT"
    sleep 30
done

echo ""
echo "✅ City expansion job finished!"
echo ""

# Show final size
TOTAL=$(python3 -c "import json; d=json.load(open('$CACHEDATA_DIR/us-cities-cached.json')); print(sum(len(v) for v in d.values()))")
echo "   Total US cities cached: $TOTAL"
echo ""

# Distribute
echo "🚀 Distributing updated files to all platforms..."
cd "$CACHEDATA_DIR"
bash distribute-caches.sh
