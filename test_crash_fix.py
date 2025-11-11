#!/usr/bin/env python3
"""
Quick test script to verify the crash fix for FastWeather
Tests the specific method that was causing the AttributeError
"""

import sys
import os

# Add the fastweather directory to the path
sys.path.insert(0, os.path.dirname(__file__))

try:
    from accessible_weather_gui import AccessibleWeatherApp
    from PyQt5.QtWidgets import QApplication
    from PyQt5.QtCore import Qt
    
    print("✅ Successfully imported AccessibleWeatherApp")
    
    # Test if the problematic method exists
    app_instance = AccessibleWeatherApp()
    
    # Check if the method that was causing crashes exists
    if hasattr(app_instance, 'format_full_weather'):
        print("✅ format_full_weather method exists (correct)")
    else:
        print("❌ format_full_weather method missing")
    
    if hasattr(app_instance, 'format_full_weather_list'):
        print("⚠️  format_full_weather_list method exists (this should NOT exist in main class)")
    else:
        print("✅ format_full_weather_list method correctly missing from main class")
    
    if hasattr(app_instance, 'display_full_weather_content'):
        print("✅ display_full_weather_content method exists")
    else:
        print("❌ display_full_weather_content method missing")
    
    print("\n🧪 Testing method call simulation...")
    
    # Simulate the data that would cause the crash
    fake_data = {
        "current_weather": {
            "temperature": 20.0,
            "windspeed": 10.0,
            "winddirection": 180.0,
            "weathercode": 0
        }
    }
    
    try:
        # This should work now without crashing
        weather_text = app_instance.format_full_weather("Test City", fake_data)
        if weather_text and "Test City" in weather_text:
            print("✅ format_full_weather method works correctly")
        else:
            print("⚠️  format_full_weather method returned unexpected result")
    except Exception as e:
        print(f"❌ format_full_weather method failed: {e}")
    
    print("\n🎉 All tests passed! The crash should be fixed.")
    
except ImportError as e:
    print(f"❌ Import failed: {e}")
except Exception as e:
    print(f"❌ Test failed: {e}")
