#!/bin/bash
# Storm Approach ring vs Weather Around Me tiles diagnostic (east side
# Madison by default — edit LAT/LON in the script for other places).
# Tools come fresh from main; output saved to RadarData/datatesting/.
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Madison Scope Diagnostic (Storm Approach ring vs WAM tiles)"
TOOLS="$(bash "$DIR/fastweather-tools-sync.sh")" || { echo "Tool sync failed."; read -n 1; exit 1; }

mkdir -p "$DIR/datatesting"
OUT="$DIR/datatesting/madison-diag-$(date -u +%Y%m%d-%H%M%SZ).txt"
python3 "$TOOLS/datatesting/madison_diag.py" | tee "$OUT"
echo ""
echo "Saved to $OUT"
echo "Press any key to close..."
read -n 1
