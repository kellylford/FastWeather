#!/bin/bash
#
# Build FastWeather Mac App (Finder-launchable)
# Double-click this file in Finder to build the app
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script directory
cd "$SCRIPT_DIR"

# Run the build script
./build-app.sh

# Keep terminal open
echo ""
echo "Press any key to close this window..."
read -n 1 -s
