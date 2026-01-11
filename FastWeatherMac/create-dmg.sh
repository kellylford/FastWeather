#!/bin/bash
# Script to create a DMG for FastWeather Mac

APP_NAME="FastWeatherMac"
VERSION="1.0.0"
DMG_NAME="FastWeather-${VERSION}"
APP_PATH="build/Build/Products/Release/${APP_NAME}.app"
DMG_TEMP="temp-dmg"
DMG_FINAL="${DMG_NAME}.dmg"

echo "Creating DMG for FastWeather Mac..."

# Remove existing DMG if it exists
if [ -f "$DMG_FINAL" ]; then
    echo "Removing existing DMG..."
    rm -f "$DMG_FINAL"
fi

# Remove temp folder if exists
if [ -d "$DMG_TEMP" ]; then
    rm -rf "$DMG_TEMP"
fi

# Create temp folder
echo "Setting up DMG contents..."
mkdir -p "$DMG_TEMP"

# Copy app to temp folder
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create Applications symlink for drag-and-drop
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
echo "Creating disk image..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_FINAL"

# Clean up
echo "Cleaning up..."
rm -rf "$DMG_TEMP"

echo ""
echo "✅ DMG created successfully: $DMG_FINAL"
echo ""
echo "To distribute:"
echo "1. Test the DMG by mounting it (double-click)"
echo "2. Code sign it with: codesign --deep --force --verify --verbose --sign \"Developer ID Application: YOUR NAME\" \"$DMG_FINAL\""
echo "3. Notarize it with Apple (recommended to avoid Gatekeeper warnings)"
echo ""
echo "Note: Currently signed with ad-hoc signature (for testing only)."
echo "For distribution, you'll need to:"
echo "  - Open Xcode project"
echo "  - Select your Team in Signing & Capabilities"
echo "  - Rebuild with: xcodebuild -project FastWeatherMac.xcodeproj -scheme FastWeatherMac -configuration Release clean build"
echo "  - Then run this script again"
