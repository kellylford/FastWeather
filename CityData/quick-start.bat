@echo off
REM Quick Start for FastWeather CityData
REM This script will set up everything and guide you through the process

echo ========================================
echo FastWeather CityData Quick Start
echo ========================================
echo.
echo This script will:
echo 1. Set up a Python virtual environment
echo 2. Install required dependencies
echo 3. Show you how to run the geocoding script
echo 4. Show you how to distribute the cached files
echo.
echo Press any key to begin, or Ctrl+C to cancel...
pause >nul
echo.

REM Step 1: Setup virtual environment
echo ========================================
echo Step 1: Setting up virtual environment
echo ========================================
call setup-venv.bat
if errorlevel 1 (
    echo.
    echo ERROR: Virtual environment setup failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo The virtual environment is now ready.
echo.
echo NEXT STEPS:
echo.
echo 1. Run the geocoding script to add 45 new countries:
echo    venv\Scripts\activate
echo    python build-international-cache.py
echo.
echo    This will take about 15-20 minutes for 45 countries.
echo    The script respects the 1 request/second rate limit.
echo.
echo 2. After geocoding completes, distribute the cached files:
echo    distribute-caches.bat
echo.
echo 3. Test on each platform:
echo    - Web: Browse Cities -^> International -^> [New Country]
echo    - Windows: Alt+W -^> International -^> [New Country]
echo    - macOS: Browse Cities -^> International -^> [New Country]
echo    - iOS: Add City -^> Browse -^> International -^> [New Country]
echo.
echo NEW COUNTRIES ADDED (45 total):
echo   Latin America: Colombia, Peru, Chile, Ecuador, Bolivia,
echo                  Uruguay, Paraguay, Venezuela, Cuba
echo   Central America/Caribbean: Dominican Republic, Panama,
echo                  Costa Rica, Guatemala, El Salvador, Honduras,
echo                  Jamaica, Trinidad and Tobago
echo   Europe: Greece, Portugal, Czech Republic, Hungary, Romania,
echo           Croatia, Serbia, Bulgaria, Slovakia, Slovenia
echo   Central/South Asia: Kazakhstan, Uzbekistan, Azerbaijan,
echo                       Georgia, Armenia
echo   Southeast Asia: Cambodia, Laos, Myanmar
echo   Middle East: Lebanon, Oman, Bahrain
echo   Africa: Algeria, Tunisia, Ghana, Tanzania, Uganda,
echo           Cameroon, Senegal, Côte d'Ivoire, Zimbabwe,
echo           Mozambique, Angola
echo.
echo For detailed instructions, see ADDING_COUNTRIES_GUIDE.md
echo.
pause
