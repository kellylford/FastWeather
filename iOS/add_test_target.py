#!/usr/bin/env python3
"""
Add FastWeatherTests target to Xcode project
"""

import sys
import os

try:
    from pbxproj import XcodeProject
except ImportError:
    print("Error: pbxproj module not found. Installing...")
    os.system("pip3 install pbxproj")
    from pbxproj import XcodeProject

def add_test_target():
    project_path = "FastWeather.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print(f"Error: {project_path} not found")
        return False
    
    print(f"Loading project: {project_path}")
    project = XcodeProject.load(project_path)
    
    # Add test files
    test_files = [
        'FastWeatherTests/DateParserTests.swift',
        'FastWeatherTests/FormatHelperTests.swift',
        'FastWeatherTests/Info.plist'
    ]
    
    print("Adding test files to project...")
    for file in test_files:
        if os.path.exists(file):
            project.add_file(file, force=False)
            print(f"  Added: {file}")
        else:
            print(f"  Warning: {file} not found")
    
    # Save project
    print("Saving project...")
    project.save()
    print("✅ Test target setup complete!")
    print("\nNext steps:")
    print("1. Open FastWeather.xcodeproj in Xcode")
    print("2. File → New → Target → iOS Unit Testing Bundle")
    print("3. Name it 'FastWeatherTests'")
    print("4. Add the test files from the Project Navigator")
    print("5. In Build Settings, set 'Defines Module' to YES for FastWeather target")
    print("6. Run tests with Cmd+U")
    
    return True

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    success = add_test_target()
    sys.exit(0 if success else 1)
