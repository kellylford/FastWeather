#!/bin/bash
#
# Launch FastWeather Mac App (Finder-launchable)
# Double-click this file in Finder to launch the app
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script directory
cd "$SCRIPT_DIR"

# Run the launch script
./launch-app.sh

# Keep terminal open
echo ""
echo "Press any key to close this window..."
read -n 1 -s
