#!/bin/bash
#
# Launch FastWeather Mac App
# This script launches the built Mac app
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project settings
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="FastWeatherMac"

# Possible build configurations
CONFIGURATIONS=("Release" "Debug")

# Function to find the app
find_app() {
    for CONFIG in "${CONFIGURATIONS[@]}"; do
        APP_PATH="${PROJECT_DIR}/build/Build/Products/${CONFIG}/${PROJECT_NAME}.app"
        if [ -d "${APP_PATH}" ]; then
            echo "${APP_PATH}"
            return 0
        fi
    done
    return 1
}

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Launching FastWeather Mac App${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Find the built app
APP_PATH=$(find_app)

if [ -z "${APP_PATH}" ]; then
    echo -e "${RED}✗ App not found${NC}"
    echo -e "${YELLOW}Please build the app first:${NC}"
    echo -e "  ./build-app.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}Found app at:${NC}"
echo -e "${BLUE}${APP_PATH}${NC}"
echo ""

# Check if app is already running
if pgrep -x "${PROJECT_NAME}" > /dev/null; then
    echo -e "${YELLOW}App is already running. Bringing to front...${NC}"
    osascript -e "tell application \"${PROJECT_NAME}\" to activate"
else
    echo -e "${GREEN}Launching app...${NC}"
    open "${APP_PATH}"
fi

echo ""
echo -e "${GREEN}✓ Done${NC}"
echo ""
echo -e "${YELLOW}Tip: You can also double-click the app in Finder:${NC}"
echo -e "${BLUE}${APP_PATH}${NC}"
echo ""
