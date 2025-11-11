@echo off
echo Testing FastWeather Portable Builder
echo.

echo Building portable version...
python create_portable.py

echo.
echo Checking if portable folder was created...
if exist "portable_fastweather" (
    echo ✅ Portable folder exists
    dir portable_fastweather
) else (
    echo ❌ Portable folder not found
)

echo.
echo Build test complete
pause
