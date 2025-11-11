#!/usr/bin/env python3
"""
Build and Run Portable FastWeather - Development Task
Creates a portable version and optionally runs it for testing
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

def create_portable_package(run_after_build=False):
    """Create a portable package that includes the latest version and optionally run it"""
    
    current_dir = Path(__file__).parent
    portable_dir = current_dir / "portable_fastweather"
    
    print("FastWeather Portable Builder")
    print("=" * 40)
    print("Building portable package with latest changes...")
    
    # Clean previous
    if portable_dir.exists():
        print("Cleaning previous portable version...")
        shutil.rmtree(portable_dir)
    
    portable_dir.mkdir()
    
    # Copy the main script
    print("Copying latest accessible_weather_gui.py...")
    shutil.copy2(current_dir / "accessible_weather_gui.py", portable_dir)
    
    # Copy city data if it exists
    city_json = current_dir / "city.json"
    if city_json.exists():
        print("Copying city.json...")
        shutil.copy2(city_json, portable_dir)
    else:
        print("No city.json found - portable version will start with empty city list")
    
    # Create a launcher that uses system Python
    launcher_content = '''@echo off
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
'''
    
    launcher_path = portable_dir / "FastWeather_Portable.bat"
    with open(launcher_path, 'w') as f:
        f.write(launcher_content)
    
    # Create a README
    readme_content = '''# FastWeather Portable

## Quick Start:
Double-click "FastWeather_Portable.bat" to run FastWeather

## What's Included:
- FastWeather GUI application (accessible_weather_gui.py)
- Your saved cities (city.json)  
- Launcher script that handles dependencies

## Features:
- Add cities by name, zip code, or "City, State" format
- Move cities up/down with Alt+U/Alt+D or Shift+Arrow keys
- View detailed weather with Enter or "Full Weather" button  
- All data saved automatically

## System Requirements:
- Windows with Python 3.7+
- Internet connection (for initial setup and weather data)

## First Run:
The launcher will automatically install PyQt5 and requests if needed.
This only happens once - subsequent runs start immediately.

## Portable Use:
Copy this entire folder to any Windows PC with Python to use FastWeather there.
'''
    
    readme_path = portable_dir / "README.txt"
    with open(readme_path, 'w') as f:
        f.write(readme_content)
    
    print(f"\n✅ Portable package created successfully!")
    print(f"📁 Location: {portable_dir}")
    print("📋 Files included:")
    for file in sorted(portable_dir.iterdir()):
        print(f"   - {file.name}")
    
    print(f"\n🚀 To use: Double-click {launcher_path.name}")
    
    if run_after_build:
        print("\n🏃 Running portable version now...")
        try:
            # Run the portable version
            subprocess.run([str(launcher_path)], cwd=portable_dir, shell=True)
        except Exception as e:
            print(f"❌ Error running portable version: {e}")
            return 1
    
    return 0

def main():
    """Main function - can be called with --run to build and run"""
    run_after = "--run" in sys.argv or "-r" in sys.argv
    
    if run_after:
        print("Build and Run mode enabled")
    
    return create_portable_package(run_after_build=run_after)

if __name__ == "__main__":
    sys.exit(main())
