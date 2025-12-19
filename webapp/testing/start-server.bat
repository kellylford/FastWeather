@echo off
REM Change to the directory where this batch file is located
cd /d "%~dp0"

echo Starting FastWeather Test Server...
echo Serving from: %CD%
echo Server will be available at http://localhost:8000
echo Press Ctrl+C to stop the server
echo.
python -m http.server 8000
