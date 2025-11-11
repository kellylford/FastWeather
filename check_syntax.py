#!/usr/bin/env python3
"""
Quick syntax check for the weather GUI app
"""

try:
    print("Checking syntax of accessible_weather_gui.py...")
    
    # Try to compile the file
    with open("accessible_weather_gui.py", "r") as f:
        code = f.read()
    
    compile(code, "accessible_weather_gui.py", "exec")
    print("✅ Syntax check passed!")
    
    # Try to import key modules
    print("Checking imports...")
    import sys
    import json
    import requests
    print("✅ Core imports available!")
    
    try:
        from PyQt5.QtWidgets import QApplication
        print("✅ PyQt5 available!")
    except ImportError:
        print("❌ PyQt5 not available - install with: pip install PyQt5")
    
    print("\n🚀 App should be safe to run now!")
    
except SyntaxError as e:
    print(f"❌ Syntax error found:")
    print(f"   Line {e.lineno}: {e.text}")
    print(f"   Error: {e.msg}")
except Exception as e:
    print(f"❌ Error during check: {e}")

input("Press Enter to continue...")
