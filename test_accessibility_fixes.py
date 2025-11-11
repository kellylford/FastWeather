#!/usr/bin/env python3
"""
Test script to verify accessibility fixes in FastWeather GUI
"""

import sys
from PyQt5.QtWidgets import QApplication
from PyQt5.QtTest import QTest
from PyQt5.QtCore import Qt, QTimer
from accessible_weather_gui import AccessibleWeatherApp

def test_focus_management():
    """Test initial focus behavior"""
    print("Testing focus management...")
    
    app = QApplication(sys.argv)
    window = AccessibleWeatherApp()
    
    # Check if focus is on city list when cities exist
    if window.city_data:
        print("✓ Cities exist - focus should be on city list")
        focused_widget = app.focusWidget()
        if focused_widget == window.city_list:
            print("✓ Focus correctly set to city list")
        else:
            print(f"✗ Focus is on {focused_widget} instead of city list")
    else:
        print("✓ No cities - focus should be on input field")
        focused_widget = app.focusWidget()
        if focused_widget == window.city_input:
            print("✓ Focus correctly set to city input")
        else:
            print(f"✗ Focus is on {focused_widget} instead of city input")
    
    app.quit()
    return True

def test_section_detection():
    """Test section header detection"""
    print("\nTesting section header detection...")
    
    app = QApplication(sys.argv)
    window = AccessibleWeatherApp()
    
    # Test various section headers
    test_headers = [
        "=== CURRENT WEATHER ===",
        "📊 HOURLY FORECAST - NEXT 12 HOURS",
        "🗓️ DAILY FORECAST - NEXT 7 DAYS",
        "Monday, July 24",
        "Tuesday, July 25",
        "Report generated: 2025-07-24"
    ]
    
    test_non_headers = [
        "Temperature: 75°F (24°C)",
        "Conditions: Clear sky",
        "Wind: 5.2 mph NW (315°)",
        "Humidity: 65%"
    ]
    
    for header in test_headers:
        if window.is_section_header(header):
            print(f"✓ Correctly identified section header: {header[:30]}...")
        else:
            print(f"✗ Failed to identify section header: {header[:30]}...")
    
    for non_header in test_non_headers:
        if not window.is_section_header(non_header):
            print(f"✓ Correctly identified non-header: {non_header[:30]}...")
        else:
            print(f"✗ Incorrectly identified as header: {non_header[:30]}...")
    
    app.quit()
    return True

def test_separator_detection():
    """Test separator line detection"""
    print("\nTesting separator line detection...")
    
    app = QApplication(sys.argv)
    window = AccessibleWeatherApp()
    
    separators = [
        "========================================",
        "----------------------------------------",
        "________________________________________",
        "************************",
        "####################################",
        "   ===   ",  # with whitespace
        ""  # empty line
    ]
    
    non_separators = [
        "Temperature: 75°F",
        "=== WEATHER REPORT ===",
        "Mixed content - not separator",
        "- Light drizzle expected"
    ]
    
    for sep in separators:
        if window.is_separator_line(sep):
            print(f"✓ Correctly identified separator: '{sep[:20]}...'")
        else:
            print(f"✗ Failed to identify separator: '{sep[:20]}...'")
    
    for non_sep in non_separators:
        if not window.is_separator_line(non_sep):
            print(f"✓ Correctly identified non-separator: '{non_sep[:20]}...'")
        else:
            print(f"✗ Incorrectly identified as separator: '{non_sep[:20]}...'")
    
    app.quit()
    return True

def main():
    """Run all tests"""
    print("FastWeather Accessibility Tests")
    print("=" * 40)
    
    try:
        test_focus_management()
        test_section_detection() 
        test_separator_detection()
        
        print("\n" + "=" * 40)
        print("All tests completed!")
        print("\nManual testing needed:")
        print("1. Delete key removes cities")
        print("2. Ctrl+Up/Down navigates sections in full weather")
        print("3. Escape/Alt+B/Alt+Left go back from full weather")
        
    except Exception as e:
        print(f"Test error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
