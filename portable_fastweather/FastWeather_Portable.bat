@echo off
echo FastWeather Portable Launcher
echo.

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ from python.org
    echo.
    pause
    exit /b 1
)

REM Check if PyQt5 is available
python -c "import PyQt5" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing PyQt5 and requests...
    echo This may take a moment on first run...
    python -m pip install PyQt5 requests
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install PyQt5
        echo Please check your internet connection and try again
        pause
        exit /b 1
    )
    echo Dependencies installed successfully!
    echo.
)

REM Launch the application
echo Starting FastWeather...
cd /d "%~dp0"
python accessible_weather_gui.py
