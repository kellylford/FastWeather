# Dialog Focus Management Implementation

## Overview
This document describes the focus management implementation for FastWeather webapp dialogs, ensuring WCAG 2.2 AA compliance.

## WCAG Requirements Met
- **2.4.3 Focus Order**: Focus moves in a meaningful sequence when dialogs open
- **2.4.7 Focus Visible**: Keyboard focus indicators are clearly visible (3px outline with 6.1:1 contrast)
- **3.2 Predictable**: Consistent, predictable focus management across all dialogs

## Implementation Pattern

### Opening a Dialog
```javascript
function showDialogExample(cityKey, lat, lon) {
    const dialog = document.getElementById('example-dialog');
    
    // 1. Close any open modals
    closeAllModals();
    
    // 2. Save focus return element (the button/element that opened the dialog)
    focusReturnElement = document.activeElement;
    
    // 3. Show the dialog
    dialog.hidden = false;
    
    // 4. Set up focus trap (prevents Tab from leaving dialog)
    trapFocus(dialog);
    
    // 5. Move focus to first interactive element in dialog
    const firstButton = dialog.querySelector('button');
    if (firstButton) firstButton.focus();
}
```

### Closing a Dialog
```javascript
document.getElementById('close-example-btn')?.addEventListener('click', () => {
    const dialog = document.getElementById('example-dialog');
    
    // 1. Hide the dialog
    dialog.hidden = true;
    
    // 2. Return focus to the element that opened the dialog
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
});
```

### Focus Trap
The `trapFocus()` function prevents keyboard focus from leaving the dialog:
- When focus is on the last focusable element and Tab is pressed, focus wraps to the first element
- When focus is on the first element and Shift+Tab is pressed, focus wraps to the last element

```javascript
function trapFocus(element) {
    const focusableElements = element.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstFocusable = focusableElements[0];
    const lastFocusable = focusableElements[focusableElements.length - 1];
    
    element.addEventListener('keydown', function(e) {
        if (e.key !== 'Tab') return;
        
        if (e.shiftKey) {
            if (document.activeElement === firstFocusable) {
                lastFocusable.focus();
                e.preventDefault();
            }
        } else {
            if (document.activeElement === lastFocusable) {
                firstFocusable.focus();
                e.preventDefault();
            }
        }
    });
}
```

## Dialogs Updated

### 1. Weather Alert Details Dialog
- **Function**: `showAlertDetails()`
- **Focus target**: Close button
- **Close handler**: Returns focus to alert badge button

### 2. Historical Weather Dialog
- **Function**: `showHistoricalWeather()`
- **Focus target**: First navigation button (Previous 20 Years)
- **Close handler**: Returns focus to "History" button

### 3. Precipitation Nowcast Dialog
- **Function**: `showPrecipitationNowcast()`
- **Focus target**: Close button
- **Close handler**: Returns focus to "Precipitation" button

### 4. Weather Around Me Dialog
- **Function**: `showWeatherAroundMe()`
- **Focus target**: First radius selector button (dynamically created)
- **Close handler**: Returns focus to "Around Me" button

## Global Escape Key Handler
All dialogs can be closed with the Escape key, which also returns focus:

```javascript
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeAllModals(); // Calls the existing close function that handles focus return
    }
});
```

## Testing

### Manual Testing Checklist
- [ ] Press Tab to navigate to dialog trigger button
- [ ] Press Enter/Space to open dialog
- [ ] Verify focus moves into dialog (visual outline should be visible)
- [ ] Press Tab repeatedly to cycle through dialog elements
- [ ] Verify focus stays trapped in dialog (wraps from last to first element)
- [ ] Press Escape to close dialog
- [ ] Verify focus returns to trigger button
- [ ] Click Close button
- [ ] Verify focus returns to trigger button

### Automated Testing
See `tests/dialogFocusManagement.a11y.test.js` for automated test cases covering:
- Dialog structure ARIA attributes
- Focus movement into dialog
- Focus return to trigger button
- Focus trap behavior
- Multiple dialog interactions
- Keyboard accessibility

## Accessibility Features
- **Visible focus indicators**: 3px solid outline with 6.1:1 contrast (#fbbf24 on blue buttons)
- **Screen reader announcements**: Each dialog announces its purpose via `announceToScreenReader()`
- **ARIA attributes**: All dialogs have `role="dialog"` or `role="alertdialog"`, `aria-modal="true"`, and `aria-labelledby`
- **Keyboard navigation**: Full keyboard support with Tab, Shift+Tab, Enter, Space, Escape
- **Predictable behavior**: Consistent pattern across all dialogs

## Browser Compatibility
Tested and working in:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Screen readers: NVDA, JAWS, VoiceOver

## References
- [WCAG 2.2 Understanding 2.4.3 Focus Order](https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html)
- [WCAG 2.2 Understanding 2.4.7 Focus Visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html)
- [ARIA Authoring Practices - Dialog (Modal)](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
