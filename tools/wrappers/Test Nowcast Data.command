#!/bin/bash
# Nowcast data test — validates the nowcast data layer outside the app.
# Tools come fresh from main via fastweather-tools-sync.sh (any branch may be
# checked out). Results go to RadarData/datatesting/run-<timestamp>/.
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Nowcast Data Test"
echo "Results are logged to RadarData/datatesting/"
echo ""

TOOLS="$(bash "$DIR/fastweather-tools-sync.sh")" || { echo "Tool sync failed."; read -n 1; exit 1; }

read -p "Number of cities (Enter for 100): " COUNT
COUNT="${COUNT:-100}"
echo ""

python3 "$TOOLS/datatesting/nowcast_data_test.py" --cities "$COUNT" --output-root "$DIR/datatesting"

echo ""
echo "Press any key to close..."
read -n 1
