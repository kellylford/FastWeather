#!/bin/bash
#
# Build and Launch FastWeather Mac App
# This is a convenience wrapper that builds and then launches the app
#

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Build & Launch FastWeather${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Build the app
"${PROJECT_DIR}/build-app.sh" "$@"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}Waiting 2 seconds before launching...${NC}"
    sleep 2
    
    # Launch the app
    "${PROJECT_DIR}/launch-app.sh"
else
    exit 1
fi
