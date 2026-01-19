@echo off
REM FastWeather City Cache Distribution Script
REM Copies cached coordinate files to all platform locations

echo ========================================
echo FastWeather Cache Distribution
echo ========================================
echo.

REM Check if cached files exist
if not exist "international-cities-cached.json" (
    echo ERROR: international-cities-cached.json not found!
    echo Run build-international-cache.py first.
    pause
    exit /b 1
)

if not exist "us-cities-cached.json" (
    echo ERROR: us-cities-cached.json not found!
    echo Run build-city-cache.py first.
    pause
    exit /b 1
)

echo Distributing cached coordinate files...
echo.

REM Copy to root (for Windows .exe bundle)
echo [1/4] Copying to root directory...
copy /Y international-cities-cached.json ..\
copy /Y us-cities-cached.json ..\
if errorlevel 1 (
    echo WARNING: Failed to copy to root directory
) else (
    echo   Done: ..\international-cities-cached.json
    echo   Done: ..\us-cities-cached.json
)
echo.

REM Copy to macOS
echo [2/4] Copying to macOS (FastWeatherMac\)...
if not exist "..\FastWeatherMac\" (
    echo   SKIPPED: FastWeatherMac directory not found
) else (
    copy /Y international-cities-cached.json ..\FastWeatherMac\
    copy /Y us-cities-cached.json ..\FastWeatherMac\
    if errorlevel 1 (
        echo   WARNING: Failed to copy to FastWeatherMac
    ) else (
        echo   Done: ..\FastWeatherMac\international-cities-cached.json
        echo   Done: ..\FastWeatherMac\us-cities-cached.json
    )
)
echo.

REM Copy to iOS
echo [3/4] Copying to iOS (iOS\FastWeather\Resources\)...
if not exist "..\iOS\FastWeather\Resources\" (
    echo   SKIPPED: iOS Resources directory not found
    echo   You may need to add these files manually via Xcode
) else (
    copy /Y international-cities-cached.json "..\iOS\FastWeather\Resources\"
    copy /Y us-cities-cached.json "..\iOS\FastWeather\Resources\"
    if errorlevel 1 (
        echo   WARNING: Failed to copy to iOS Resources
    ) else (
        echo   Done: ..\iOS\FastWeather\Resources\international-cities-cached.json
        echo   Done: ..\iOS\FastWeather\Resources\us-cities-cached.json
    )
)
echo.

REM Copy to webapp (source location)
echo [4/4] Copying to Web/PWA (webapp\)...
if not exist "..\webapp\" (
    echo   SKIPPED: webapp directory not found
) else (
    copy /Y international-cities-cached.json ..\webapp\
    copy /Y us-cities-cached.json ..\webapp\
    if errorlevel 1 (
        echo   WARNING: Failed to copy to webapp
    ) else (
        echo   Done: ..\webapp\international-cities-cached.json
        echo   Done: ..\webapp\us-cities-cached.json
    )
)
echo.

echo ========================================
echo Distribution Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Test each platform with Browse Cities feature
echo 2. Rebuild distribution packages if needed:
echo    - Windows: python build.py
echo    - macOS: cd FastWeatherMac ^&^& ./create-dmg.sh
echo    - Web/PWA: No rebuild needed (static files)
echo.
pause
