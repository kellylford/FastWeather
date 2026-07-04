#!/bin/bash
# Live radar prompt test — runs main's tools/quickradar/run_test_prompt.sh.
# Tools come fresh from main via fastweather-tools-sync.sh (any branch may be
# checked out). Results are logged to RadarData/test_logs/.
DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_CITY="Madison WI"

echo "Live Radar Test"
echo "Results are logged to RadarData/test_logs/"
echo ""

TOOLS="$(bash "$DIR/fastweather-tools-sync.sh")" || { echo "Tool sync failed."; read -n 1; exit 1; }

while true; do
    read -p "City to test (Enter for $DEFAULT_CITY, q to quit): " INPUT
    echo ""

    if [ "$INPUT" = "q" ] || [ "$INPUT" = "Q" ]; then
        echo "Done."
        break
    fi

    CITY="${INPUT:-$DEFAULT_CITY}"

    bash "$TOOLS/quickradar/run_test_prompt.sh" "$CITY"
    echo ""
done

echo ""
echo "Press any key to close..."
read -n 1
