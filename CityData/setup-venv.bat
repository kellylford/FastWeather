@echo off
REM FastWeather CityData Virtual Environment Setup
REM Creates and configures Python virtual environment for geocoding

echo ========================================
echo FastWeather CityData Setup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found!
    echo Please install Python 3.8 or later.
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv\" (
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo   Done: venv created
    echo.
) else (
    echo Virtual environment already exists
    echo.
)

REM Activate and install dependencies
echo Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)

echo.
echo Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Virtual environment is ready in: venv\
echo.
echo To activate it manually:
echo   venv\Scripts\activate
echo.
echo To run geocoding scripts:
echo   python build-international-cache.py
echo   python build-city-cache.py
echo.
echo To distribute caches to all platforms:
echo   distribute-caches.bat
echo.
pause
