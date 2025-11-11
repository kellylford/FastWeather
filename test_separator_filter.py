#!/usr/bin/env python3
"""
Test the separator line filtering functionality
"""

def is_separator_line(line):
    """Check if a line is just a separator (dashes, equals, etc.)"""
    # Remove whitespace and check if line consists only of separator characters
    cleaned = line.strip()
    if not cleaned:
        return True
    
    # Check if line is made up entirely of separator characters
    separator_chars = {'-', '=', '_', '*', '#'}
    return len(set(cleaned)) == 1 and cleaned[0] in separator_chars

# Test cases
test_lines = [
    "====================================",
    "--------------------", 
    "___________",
    "***********",
    "############",
    "Temperature: 75°F",
    "CURRENT WEATHER",
    "Wind: 10 mph N",
    "",
    "   ",
    "12-HOUR FORECAST",
    "- - - - - - -",  # This should NOT be filtered (has spaces)
    "Mixed content ---- more content",  # This should NOT be filtered
]

print("Testing separator line detection:")
print("=" * 50)

for line in test_lines:
    result = is_separator_line(line)
    status = "FILTER OUT" if result else "KEEP"
    print(f"{status:10} | '{line}'")

print("\n" + "=" * 50)
print("Expected results:")
print("- Pure separator lines (===, ---, etc.) should be FILTER OUT")
print("- Weather content lines should be KEEP")
print("- Empty lines should be FILTER OUT")
