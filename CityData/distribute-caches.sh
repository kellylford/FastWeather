#!/bin/bash
# FastWeather City Cache Distribution Script (Bash version)
# Copies cached coordinate files to all platform locations

echo "========================================"
echo "FastWeather Cache Distribution"
echo "========================================"
echo ""

# Check if cached files exist
if [ ! -f "international-cities-cached.json" ]; then
    echo "ERROR: international-cities-cached.json not found!"
    echo "Run build-international-cache.py first."
    exit 1
fi

if [ ! -f "us-cities-cached.json" ]; then
    echo "ERROR: us-cities-cached.json not found!"
    echo "Run build-city-cache.py first."
    exit 1
fi

echo "Distributing cached coordinate files..."
echo ""

# Copy to root (for Windows .exe bundle)
echo "[1/4] Copying to root directory..."
cp -v international-cities-cached.json ../
cp -v us-cities-cached.json ../
if [ $? -eq 0 ]; then
    echo "  ✓ Done: ../international-cities-cached.json"
    echo "  ✓ Done: ../us-cities-cached.json"
else
    echo "  ⚠ WARNING: Failed to copy to root directory"
fi
echo ""

# Copy to macOS
echo "[2/4] Copying to macOS (FastWeatherMac/)..."
if [ ! -d "../FastWeatherMac/" ]; then
    echo "  ⊘ SKIPPED: FastWeatherMac directory not found"
else
    cp -v international-cities-cached.json ../FastWeatherMac/
    cp -v us-cities-cached.json ../FastWeatherMac/
    if [ $? -eq 0 ]; then
        echo "  ✓ Done: ../FastWeatherMac/international-cities-cached.json"
        echo "  ✓ Done: ../FastWeatherMac/us-cities-cached.json"
    else
        echo "  ⚠ WARNING: Failed to copy to FastWeatherMac"
    fi
fi
echo ""

# Copy to iOS
echo "[3/4] Copying to iOS (iOS/FastWeather/Resources/)..."
if [ ! -d "../iOS/FastWeather/Resources/" ]; then
    echo "  ⊘ SKIPPED: iOS Resources directory not found"
    echo "  You may need to add these files manually via Xcode"
else
    cp -v international-cities-cached.json "../iOS/FastWeather/Resources/"
    cp -v us-cities-cached.json "../iOS/FastWeather/Resources/"
    if [ $? -eq 0 ]; then
        echo "  ✓ Done: ../iOS/FastWeather/Resources/international-cities-cached.json"
        echo "  ✓ Done: ../iOS/FastWeather/Resources/us-cities-cached.json"
    else
        echo "  ⚠ WARNING: Failed to copy to iOS Resources"
    fi
fi
echo ""

# Copy to webapp (source location)
echo "[4/4] Copying to Web/PWA (webapp/)..."
if [ ! -d "../webapp/" ]; then
    echo "  ⊘ SKIPPED: webapp directory not found"
else
    cp -v international-cities-cached.json ../webapp/
    cp -v us-cities-cached.json ../webapp/
    if [ $? -eq 0 ]; then
        echo "  ✓ Done: ../webapp/international-cities-cached.json"
        echo "  ✓ Done: ../webapp/us-cities-cached.json"
    else
        echo "  ⚠ WARNING: Failed to copy to webapp"
    fi
fi
echo ""

echo "========================================"
echo "Distribution Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Test each platform with Browse Cities feature"
echo "2. Rebuild distribution packages if needed:"
echo "   - Windows: python build.py"
echo "   - macOS: cd FastWeatherMac && ./create-dmg.sh"
echo "   - Web/PWA: Reload with Ctrl+Shift+R to clear cache"
echo ""
echo "For Web/PWA: The service worker cache has been updated."
echo "Hard refresh (Ctrl+Shift+R) to see new countries."
echo ""
