# Dialog Focus Management - Visual Flow Diagram

## Focus Flow for Opening a Dialog

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: User on Trigger Button                                 │
│                                                                 │
│   [City Card]                                                   │
│   ┌──────────────────────────────────────────────────┐         │
│   │  San Diego, California                            │         │
│   │  72°F - Clear                                     │         │
│   │                                                    │         │
│   │  [Details] [History] [Precipitation] [Around Me]  │         │
│   │              ^^^^^^^^                              │         │
│   │           (Focus is here)                          │         │
│   └──────────────────────────────────────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ User presses Enter/Space
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: Save Focus Location                                    │
│                                                                 │
│   JavaScript: focusReturnElement = document.activeElement      │
│                                                                 │
│   Saved: "History" button reference                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: Show Dialog & Set Up Focus Trap                        │
│                                                                 │
│   JavaScript:                                                   │
│   1. closeAllModals()         // Close any open dialogs        │
│   2. dialog.hidden = false    // Show the dialog               │
│   3. trapFocus(dialog)        // Prevent Tab from escaping     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Move Focus Into Dialog                                 │
│                                                                 │
│   ┌────────────────────────────────────────────────┐           │
│   │ Historical Weather - San Diego                  │           │
│   ├────────────────────────────────────────────────┤           │
│   │                                                  │           │
│   │  [← Previous 20 Years] [Today] [Next 20 Years →]│           │
│   │   ^^^^^^^^^^^^^^^^^^                             │           │
│   │   (Focus moved here automatically)               │           │
│   │                                                  │           │
│   │  [Historical data displays here...]              │           │
│   │                                                  │           │
│   │                                      [Close]     │           │
│   └────────────────────────────────────────────────┘           │
│                                                                 │
│   User can now Tab through dialog elements.                    │
│   Focus is TRAPPED - cannot escape the dialog.                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Focus Trap Behavior (Inside Dialog)

```
Dialog with 4 buttons:

┌────────────────────────────────────────────────────┐
│ Historical Weather Dialog                          │
│                                                    │
│  ┌─────────────┐  ┌────────┐  ┌─────────────┐   │
│  │ ← Prev 20Y  │  │ Today  │  │ Next 20Y →  │   │
│  └─────────────┘  └────────┘  └─────────────┘   │
│       ① ─Tab→        ② ─Tab→       ③             │
│                                                    │
│  [Data container]                                  │
│                                                    │
│  ┌───────────┐                                    │
│  │   Close   │                                    │
│  └───────────┘                                    │
│       ④                                            │
└────────────────────────────────────────────────────┘

Tab Navigation:
  ① → ② → ③ → ④ → ① (wraps back to first)

Shift+Tab Navigation:
  ④ → ③ → ② → ① → ④ (wraps back to last)

Focus cannot escape the dialog while it's open!
```

## Focus Flow for Closing a Dialog

```
┌─────────────────────────────────────────────────────────────────┐
│ User closes dialog (Press Escape OR Click Close button)        │
│                                                                 │
│   Option 1: Escape key                                         │
│   ┌─────────────────────────────────────────────┐             │
│   │ Global keyboard handler detects Escape      │             │
│   │ Calls: closeAllModals()                      │             │
│   └─────────────────────────────────────────────┘             │
│                                                                 │
│   Option 2: Close button                                       │
│   ┌─────────────────────────────────────────────┐             │
│   │ Button click handler executes                │             │
│   │ Sets: dialog.hidden = true                   │             │
│   └─────────────────────────────────────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Both paths lead to...
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Restore Focus to Trigger Button                                │
│                                                                 │
│   JavaScript:                                                   │
│   if (focusReturnElement) {                                    │
│       focusReturnElement.focus();  // Move focus back          │
│       focusReturnElement = null;   // Clean up                 │
│   }                                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ User is back where they started!                               │
│                                                                 │
│   [City Card]                                                   │
│   ┌──────────────────────────────────────────────────┐         │
│   │  San Diego, California                            │         │
│   │  72°F - Clear                                     │         │
│   │                                                    │         │
│   │  [Details] [History] [Precipitation] [Around Me]  │         │
│   │              ^^^^^^^^                              │         │
│   │           (Focus restored here)                    │         │
│   └──────────────────────────────────────────────────┘         │
│                                                                 │
│   User can continue navigating with keyboard!                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Complete Dialog List with Focus Targets

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Dialog Name              │ Trigger Button       │ Initial Focus Target      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Historical Weather       │ "History"            │ "← Previous 20 Years" btn │
│ Precipitation Nowcast    │ "Precipitation"      │ "Close" button            │
│ Weather Around Me        │ "Around Me"          │ First radius selector btn │
│ Weather Alert Details    │ Alert badge          │ "Close" button            │
│ Configuration Settings   │ "Configure weather"  │ "Current Weather" tab     │
│ Full Weather Details     │ City name/Details    │ First tab or Close button │
│ City Selection           │ Search results       │ First city option         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Error Prevention

### What happens if focus element is removed from DOM?

```javascript
// Before closing dialog:
if (focusReturnElement) {
    // Check if element still exists in DOM
    if (document.contains(focusReturnElement)) {
        focusReturnElement.focus();  // Safe to focus
    } else {
        // Element was removed - fallback to document body
        document.body.focus();
    }
    focusReturnElement = null;
}
```

### What happens if multiple dialogs open?

```javascript
// closeAllModals() handles this:
function closeAllModals() {
    // Hide all visible dialogs
    document.querySelectorAll('.modal:not([hidden])').forEach(modal => {
        modal.hidden = true;
    });
    
    // Return focus only once, to the most recent trigger
    if (focusReturnElement) {
        focusReturnElement.focus();
        focusReturnElement = null;
    }
}
```

## WCAG Success Criteria Mapping

```
┌──────────────────────────────────────────────────────────────────┐
│ WCAG 2.2 Criterion     │ How Our Implementation Meets It        │
├──────────────────────────────────────────────────────────────────┤
│ 2.4.3 Focus Order      │ • Focus moves in logical sequence      │
│                        │ • Tab order follows visual layout      │
│                        │ • Focus never gets lost                │
│                        │                                        │
│ 2.4.7 Focus Visible    │ • 3px outline on all focused elements  │
│                        │ • 6.1:1 contrast ratio (yellow/blue)   │
│                        │ • Focus always visible                 │
│                        │                                        │
│ 3.2 Predictable        │ • Same pattern across all dialogs      │
│                        │ • Focus always returns to trigger      │
│                        │ • Escape key works consistently        │
│                        │ • No unexpected focus changes          │
└──────────────────────────────────────────────────────────────────┘
```

## Implementation Consistency

All dialogs follow the same pattern:

```javascript
// PATTERN: Opening a dialog
async function showSomeDialog(cityKey, lat, lon) {
    const dialog = document.getElementById('some-dialog');
    
    // ... setup dialog content ...
    
    closeAllModals();                          // 1. Close others
    focusReturnElement = document.activeElement; // 2. Save focus
    dialog.hidden = false;                     // 3. Show dialog
    trapFocus(dialog);                         // 4. Trap focus
    
    // 5. Move focus to first interactive element
    const firstElement = document.getElementById('first-element');
    if (firstElement) firstElement.focus();
}

// PATTERN: Closing a dialog
document.getElementById('close-btn')?.addEventListener('click', () => {
    const dialog = document.getElementById('some-dialog');
    dialog.hidden = true;                      // 1. Hide dialog
    
    if (focusReturnElement) {                  // 2. Restore focus
        focusReturnElement.focus();
        focusReturnElement = null;
    }
});
```

This consistency makes the codebase:
- ✅ Easy to maintain
- ✅ Predictable for users
- ✅ Reliable for assistive technology
- ✅ WCAG 2.2 AA compliant
