#!/usr/bin/env python3
"""
Simple test to verify PyQt5 is working
"""
import sys
print("Python version:", sys.version)
print("Python executable:", sys.executable)

try:
    print("Testing PyQt5 import...")
    from PyQt5.QtWidgets import QApplication, QMessageBox
    print("✅ PyQt5 import successful")
    
    print("Testing QApplication creation...")
    app = QApplication(sys.argv)
    print("✅ QApplication created successfully")
    
    print("Testing QMessageBox...")
    msg = QMessageBox()
    msg.setWindowTitle("Test")
    msg.setText("PyQt5 is working!")
    print("✅ QMessageBox created successfully")
    
    # Don't show the dialog in this test, just verify it can be created
    print("✅ All PyQt5 components working correctly")
    
except Exception as e:
    print(f"❌ PyQt5 test failed: {e}")
    import traceback
    traceback.print_exc()

print("Test completed.")
