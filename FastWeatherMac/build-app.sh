#!/bin/bash
#
# Build FastWeather Mac App
# This script builds the Mac app using xcodebuild command line tool
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project settings
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="FastWeatherMac"
SCHEME="FastWeatherMac"
CONFIGURATION="${1:-Release}"  # Default to Release, or use first argument

# Build directory
BUILD_DIR="${PROJECT_DIR}/build"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Building FastWeather Mac App${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""
echo -e "${YELLOW}Configuration: ${CONFIGURATION}${NC}"
echo -e "${YELLOW}Project Dir: ${PROJECT_DIR}${NC}"
echo ""

# Check if data files exist
if [ ! -f "${PROJECT_DIR}/us-cities-cached.json" ]; then
    echo -e "${RED}Warning: us-cities-cached.json not found${NC}"
    echo -e "${YELLOW}Please ensure city data files are present${NC}"
fi

if [ ! -f "${PROJECT_DIR}/international-cities-cached.json" ]; then
    echo -e "${RED}Warning: international-cities-cached.json not found${NC}"
    echo -e "${YELLOW}Please ensure city data files are present${NC}"
fi

# Clean previous build (optional, comment out if you want faster incremental builds)
echo -e "${BLUE}Cleaning previous build...${NC}"
xcodebuild clean \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    > /dev/null 2>&1 || true

# Build the app
echo -e "${BLUE}Building ${PROJECT_NAME}...${NC}"
xcodebuild build \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    
    # Find the built app
    APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"
    
    if [ -d "${APP_PATH}" ]; then
        echo -e "${GREEN}App Location:${NC}"
        echo -e "${BLUE}${APP_PATH}${NC}"
        echo ""
        echo -e "${YELLOW}To run the app:${NC}"
        echo -e "  ./launch-app.sh"
        echo -e "${YELLOW}Or open directly:${NC}"
        echo -e "  open \"${APP_PATH}\""
        echo ""
        
        # Show app size
        APP_SIZE=$(du -sh "${APP_PATH}" | cut -f1)
        echo -e "${YELLOW}App Size: ${APP_SIZE}${NC}"
    else
        echo -e "${RED}Warning: App not found at expected location${NC}"
        echo -e "${YELLOW}Build might have succeeded but app location differs${NC}"
    fi
else
    echo ""
    echo -e "${RED}✗ Build failed${NC}"
    echo -e "${YELLOW}Check the error messages above for details${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=================================${NC}"
