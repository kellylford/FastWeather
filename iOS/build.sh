#!/bin/bash

# Build Weather Fast iOS App
# This script builds the Weather Fast iOS application using xcodebuild

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Weather Fast iOS Build Script${NC}"
echo ""

# Configuration
PROJECT_NAME="FastWeather"
SCHEME="FastWeather"
CONFIGURATION="Debug"
SDK="iphonesimulator"
SIMULATOR_NAME="iPhone 17"
SIMULATOR_OS="26.2"

# Change to script directory
cd "$(dirname "$0")"

echo -e "${GREEN}Building ${PROJECT_NAME}...${NC}"
echo "  Scheme: ${SCHEME}"
echo "  Configuration: ${CONFIGURATION}"
echo "  SDK: ${SDK}"
echo "  Simulator: ${SIMULATOR_NAME} (iOS ${SIMULATOR_OS})"
echo ""

# Build for simulator
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -sdk "${SDK}" \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}" \
    clean build

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Build succeeded!${NC}"
    echo ""
    echo "The app has been built to:"
    echo "  ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*/Build/Products/${CONFIGURATION}-${SDK}/${PROJECT_NAME}.app"
    echo ""
    echo "To run the app in the simulator:"
    echo "  1. Open Xcode"
    echo "  2. Open the simulator (Xcode > Open Developer Tool > Simulator)"
    echo "  3. Drag the .app file to the simulator"
    echo ""
    echo "Or use:"
    echo "  xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*/Build/Products/${CONFIGURATION}-${SDK}/${PROJECT_NAME}.app"
else
    echo ""
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
