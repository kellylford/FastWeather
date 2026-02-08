# Manual Testing Guide for Dialog Focus Management

## Overview
This guide provides step-by-step instructions for manually testing the dialog focus management fixes in FastWeather webapp.

## Prerequisites
- A modern web browser (Chrome, Firefox, Safari, or Edge)
- Keyboard (for keyboard-only testing)
- Optional: Screen reader (NVDA, JAWS, or VoiceOver) for comprehensive accessibility testing

## Testing Method 1: Interactive Demo
The easiest way to test the focus management is using the demo file:

1. Open `focus-management-demo.html` in your browser
2. Follow the on-screen instructions to test each dialog
3. The demo provides immediate visual feedback when focus moves correctly

## Testing Method 2: Full Application Testing

### Setup
1. Start the webapp: `python -m http.server 8000` (or use `start-server.sh`)
2. Open `http://localhost:8000` in your browser
3. Add at least one city to test with

### Test 1: Historical Weather Dialog

**Steps:**
1. Navigate to a city card
2. Press Tab until you reach the "History" button
3. Press Enter or Space to activate the button
4. **VERIFY:** Focus should move to the "← Previous 20 Years" button in the dialog
5. Press Tab multiple times
6. **VERIFY:** Focus cycles through dialog elements and wraps back to the first element
7. Press Escape
8. **VERIFY:** Dialog closes and focus returns to the "History" button

**Alternative Close Test:**
1. Repeat steps 1-5
2. Tab to the "Close" button and press Enter
3. **VERIFY:** Dialog closes and focus returns to the "History" button

### Test 2: Precipitation Nowcast Dialog

**Steps:**
1. Navigate to a city card
2. Press Tab until you reach the "Precipitation" button
3. Press Enter or Space to activate the button
4. **VERIFY:** Focus should move to the "Close" button in the dialog
5. Press Shift+Tab
6. **VERIFY:** Focus should wrap to the last interactive element (pagination or close button)
7. Press Escape
8. **VERIFY:** Dialog closes and focus returns to the "Precipitation" button

### Test 3: Weather Around Me Dialog

**Steps:**
1. Navigate to a city card
2. Press Tab until you reach the "Around Me" button
3. Press Enter or Space to activate the button
4. **VERIFY:** Focus should move to the first radius selector button (80km or 50mi)
5. Press Tab to cycle through radius options
6. **VERIFY:** Focus stays within the dialog
7. Press Escape
8. **VERIFY:** Dialog closes and focus returns to the "Around Me" button

### Test 4: Weather Alert Dialog (if alerts are available)

**Steps:**
1. If a city has weather alerts, navigate to the alert badge
2. Press Enter or Space to activate the alert badge
3. **VERIFY:** Focus should move to the "Close" button in the alert dialog
4. Press Tab
5. **VERIFY:** Focus wraps back to the "Close" button (only one interactive element)
6. Press Escape
7. **VERIFY:** Dialog closes and focus returns to the alert badge

### Test 5: Configuration Dialog (Existing - Verify Still Works)

**Steps:**
1. Press Tab until you reach the "Configure weather" button
2. Press Enter or Space to activate the button
3. **VERIFY:** Focus should move to the "Current Weather" tab
4. Press Tab to cycle through configuration options
5. **VERIFY:** Focus stays within the dialog
6. Press Escape
7. **VERIFY:** Dialog closes and focus returns to the "Configure weather" button

## Accessibility Checklist

For each dialog, verify:

- [ ] **Focus Visible**: A clear focus indicator (outline) is visible on the focused element
- [ ] **Focus Order**: Focus moves in a logical, predictable order
- [ ] **Focus Trap**: Tab and Shift+Tab keep focus within the dialog
- [ ] **Focus Return**: Closing the dialog (Escape or Close button) returns focus to the trigger
- [ ] **Screen Reader**: Dialog purpose is announced when opened
- [ ] **Keyboard Only**: All functionality works without using a mouse
- [ ] **No Focus Loss**: Focus never becomes invisible or stuck

## Screen Reader Testing

### VoiceOver (macOS/iOS)
1. Enable VoiceOver: Cmd+F5
2. Navigate to a dialog trigger button: VO+Right Arrow
3. Activate button: VO+Space
4. Verify VoiceOver announces: "Dialog, [Dialog Title]"
5. Navigate through dialog: VO+Right Arrow
6. Close dialog: Escape or activate Close button
7. Verify focus returns and is announced

### NVDA (Windows)
1. Start NVDA
2. Navigate to a dialog trigger button: Tab
3. Activate button: Enter
4. Verify NVDA announces: "Dialog, [Dialog Title]"
5. Navigate through dialog: Tab
6. Close dialog: Escape or activate Close button
7. Verify focus returns and is announced

### JAWS (Windows)
1. Start JAWS
2. Navigate to a dialog trigger button: Tab
3. Activate button: Enter
4. Verify JAWS announces: "Dialog, [Dialog Title]"
5. Navigate through dialog: Tab
6. Close dialog: Escape or activate Close button
7. Verify focus returns and is announced

## Expected Behavior Summary

| Dialog | Focus Target on Open | Focus Return on Close |
|--------|---------------------|----------------------|
| Historical Weather | "← Previous 20 Years" button | "History" button |
| Precipitation | "Close" button | "Precipitation" button |
| Weather Around Me | First radius selector button | "Around Me" button |
| Weather Alert | "Close" button | Alert badge button |
| Configuration | "Current Weather" tab | "Configure weather" button |
| Weather Details | First tab or "Close" button | City name/details button |

## Common Issues to Look For

1. **Focus disappears**: After opening dialog, focus is not visible
2. **Focus escapes**: Tab key moves focus outside the dialog
3. **Focus doesn't return**: After closing, focus goes to the top of the page or disappears
4. **Focus returns to wrong element**: After closing, focus goes somewhere unexpected
5. **No visual indicator**: Can't see where focus is
6. **Trapped forever**: Can't close dialog with keyboard

## Reporting Issues

If you find any issues:
1. Note which dialog has the problem
2. Describe the expected vs actual behavior
3. List the exact steps to reproduce
4. Note your browser and OS
5. Include screen reader name/version if applicable

## Success Criteria

All tests pass when:
- ✅ Focus moves into every dialog when opened
- ✅ Focus is clearly visible at all times
- ✅ Tab and Shift+Tab cycle only through dialog elements
- ✅ Escape key closes dialog and returns focus
- ✅ Close button closes dialog and returns focus
- ✅ Focus always returns to the element that opened the dialog
- ✅ Screen readers announce dialog content appropriately
- ✅ No keyboard traps (can always close and navigate)
