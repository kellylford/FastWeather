#!/usr/bin/env python3
"""
Build script for FastWeather
Creates a standalone Windows executable using PyInstaller
"""

import os
import sys
import shutil
import subprocess

def main():
    print("=" * 60)
    print("FastWeather Build Script")
    print("=" * 60)
    print()
    
    # Check if PyInstaller is installed
    try:
        import PyInstaller
        print("✓ PyInstaller found")
    except ImportError:
        print("✗ PyInstaller not found")
        print("\nInstalling PyInstaller...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
        print("✓ PyInstaller installed")

    # Check for app dependencies
    print("Checking dependencies...")
    missing_deps = []
    try:
        import wx
        print("✓ wxPython found")
    except ImportError:
        missing_deps.append("wxPython")
    
    try:
        import requests
        print("✓ requests found")
    except ImportError:
        missing_deps.append("requests")
        
    if missing_deps:
        print(f"✗ Missing dependencies: {', '.join(missing_deps)}")
        print("Installing dependencies...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✓ Dependencies installed")
    
    print()
    
    # Clean previous builds
    print("Cleaning previous builds...")
    for folder in ['build', 'dist']:
        if os.path.exists(folder):
            try:
                shutil.rmtree(folder)
                print(f"  Removed {folder}/")
            except Exception as e:
                print(f"  Warning: Could not remove {folder}/: {e}")

    
    # Remove spec file if it exists
    spec_file = "fastweather.spec"
    if os.path.exists(spec_file):
        os.remove(spec_file)
        print(f"  Removed {spec_file}")
    
    print("✓ Cleanup complete")
    print()
    
    # Build the executable
    print("Building executable...")
    print("-" * 60)
    
    # PyInstaller command
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm", # Overwrite output directory
        "--name=WeatherFast",
        "--windowed",  # No console window
        "--onefile",   # Single executable file
        "--icon=NONE", # No icon (you can add one later)
        "--add-data", "city.json;.", # Embed city.json as a resource
        "--add-data", "us-cities-cached.json;.", # Embed US cities cache
        "--add-data", "international-cities-cached.json;.", # Embed international cities cache
        "--hidden-import=wx", # Explicitly include wxPython
        "--collect-all=wx", # Collect all wxPython modules and resources
        "--exclude-module=tkinter", # Exclude unnecessary standard library GUI
        "fastweather.py"
    ]
    
    print(f"Running: {' '.join(cmd)}")
    print()
    
    try:
        subprocess.check_call(cmd)
    except subprocess.CalledProcessError as e:
        print(f"\n✗ Build failed with error code {e.returncode}")
        return 1
    
    print()
    print("-" * 60)
    print("✓ Build complete!")
    print()
    
    # Check output
    dist_dir = "dist"
    exe_path = os.path.join(dist_dir, "WeatherFast.exe")
    
    if os.path.exists(exe_path):
        print(f"Executable location: {os.path.abspath(exe_path)}")
        print()
        
        size_mb = os.path.getsize(exe_path) / (1024 * 1024)
        print(f"Executable size: {size_mb:.1f} MB")
        print()
        
        print("To distribute:")
        print(f"  Just share the 'WeatherFast.exe' file.")
        print()
    else:
        print("✗ Build output not found!")
        return 1
    
    print()
    print("=" * 60)
    print("Build successful! 🎉")
    print("=" * 60)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
