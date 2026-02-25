# View Menu Bug Report - Incomplete Refactoring

**Date**: February 25, 2026  
**Reporter**: User (Kelly Ford)  
**Severity**: HIGH - Breaks core UI functionality  
**Component**: View menu keyboard navigation  
**Affected Files**: `webapp/index.html`, `webapp/app.js`

---

## Problem Summary

The view menu (Alt+V) no longer functions correctly after the accessibility remediation:

**Before (Working)**:
- Press Alt+V → Menu opens AND focus moves to first menu item
- Up/Down arrow keys navigate between menu items
- Enter/Space selects an item

**After (Broken)**:
- Press Alt+V → Menu opens BUT focus stays on button
- Tab key required to reach menu items
- Arrow key navigation does not work

---

## Root Cause Analysis

### What Was Changed

**Commit**: `95d10f9` - "fix: comprehensive WCAG 2.2 Level AA accessibility remediation"

**Changed in HTML** (`webapp/index.html` lines 177-183):
```html
<!-- BEFORE -->
<button role="menuitem" data-view="flat" aria-checked="true">Flat</button>
<button role="menuitem" data-view="table" aria-checked="false">Table</button>
<button role="menuitem" data-view="list" aria-checked="false">List</button>

<!-- AFTER -->
<button role="menuitemradio" data-view="flat" aria-checked="true">Flat</button>
<button role="menuitemradio" data-view="table" aria-checked="false">Table</button>
<button role="menuitemradio" data-view="list" aria-checked="false">List</button>
```

**NOT Changed in JavaScript** (`webapp/app.js`):
- Lines 115, 346, 1936, 1951, 2006 still query for `[role="menuitem"]`
- Should have been updated to `[role="menuitemradio"]`

### Why This Change Was Made

**Source**: WEB-ACCESSIBILITY-AUDIT.md, Issue #1.2

**Audit Finding**:
```
**1.2 Menu Pattern Uses Wrong ARIA Attribute**
- Location: index.html:177-183
- Issue: role="menuitem" uses aria-checked (only valid on menuitemradio/menuitemcheckbox)
- Impact: Screen readers won't announce checked state. Users cannot determine current view selection
```

**Specialist Agent**: `aria-specialist`

**Reasoning**: The ARIA specification states that `aria-checked` is only valid on `role="menuitemradio"` or `role="menuitemcheckbox"`, not on plain `role="menuitem"`. Since the view menu has mutually exclusive options with checked states, `menuitemradio` is the correct role.

**This change was technically correct** according to WCAG and ARIA specifications.

---

## The Bug - Incomplete Refactoring

### Failed to Update JavaScript Selectors

The HTML role attribute was changed from `menuitem` to `menuitemradio`, but **5 locations in app.js** still query for the old role name, causing all menu functionality to break.

#### Location 1: Line 115 (Initialization)
```javascript
// CURRENT (BROKEN)
document.querySelectorAll('#view-menu [role="menuitem"]').forEach(item => {
    const isSelected = item.dataset.view === currentView;
    item.setAttribute('aria-checked', isSelected ? 'true' : 'false');
});

// SHOULD BE
document.querySelectorAll('#view-menu [role="menuitemradio"]').forEach(item => {
    const isSelected = item.dataset.view === currentView;
    item.setAttribute('aria-checked', isSelected ? 'true' : 'false');
});
```
**Impact**: Menu checkmarks not initialized on page load

#### Location 2: Line 346 (Event Listeners)
```javascript
// CURRENT (BROKEN)
document.querySelectorAll('#view-menu [role="menuitem"]').forEach(item => {
    item.addEventListener('click', (e) => {
        const view = e.target.dataset.view;
        switchView(view);
        closeViewMenu();
    });
});

// SHOULD BE
document.querySelectorAll('#view-menu [role="menuitemradio"]').forEach(item => {
    item.addEventListener('click', (e) => {
        const view = e.target.dataset.view;
        switchView(view);
        closeViewMenu();
    });
});
```
**Impact**: Click events not attached to menu items

#### Location 3: Line 1936 (Focus Management)
```javascript
// CURRENT (BROKEN) - openViewMenu() function
const firstItem = viewMenu.querySelector('[role="menuitem"]');
if (firstItem) {
    firstItem.focus();
}

// SHOULD BE
const firstItem = viewMenu.querySelector('[role="menuitemradio"]');
if (firstItem) {
    firstItem.focus();
}
```
**Impact**: Focus does not move to first menu item when menu opens (THIS IS THE USER'S PRIMARY COMPLAINT)

#### Location 4: Line 1951 (Arrow Key Navigation)
```javascript
// CURRENT (BROKEN) - handleViewMenuKeydown() function
const items = Array.from(e.currentTarget.querySelectorAll('[role="menuitem"]'));
const currentIndex = items.indexOf(document.activeElement);

// SHOULD BE
const items = Array.from(e.currentTarget.querySelectorAll('[role="menuitemradio"]'));
const currentIndex = items.indexOf(document.activeElement);
```
**Impact**: Arrow keys do not navigate between menu items

#### Location 5: Line 2006 (View Switching)
```javascript
// CURRENT (BROKEN) - switchView() function
document.querySelectorAll('#view-menu [role="menuitem"]').forEach(item => {
    const isSelected = item.dataset.view === currentView;
    item.setAttribute('aria-checked', isSelected ? 'true' : 'false');
});

// SHOULD BE
document.querySelectorAll('#view-menu [role="menuitemradio"]').forEach(item => {
    const isSelected = item.dataset.view === currentView;
    item.setAttribute('aria-checked', isSelected ? 'true' : 'false');
});
```
**Impact**: Menu checkmarks not updated after view change

---

## Agent Behavior Analysis

### What Went Wrong

1. **HTML Change (Correct)**: The `aria-specialist` agent correctly identified that `menuitem` with `aria-checked` is invalid ARIA and should be `menuitemradio`

2. **JavaScript Update (Missed)**: The agent changed the HTML but **failed to search for and update all JavaScript code** that references the old role name

3. **Testing (Not Performed)**: Changes were committed without functional testing to verify the menu still works

### Why This Happened

**Multi-file refactoring coordination failure**: When a structural change affects both HTML and JavaScript:
- The agent must search ALL files for references to the changed attribute
- Pattern: `[role="menuitem"]` appears in 5 different functions across app.js
- The agent only modified index.html and did not update app.js selectors

**No verification step**: After making the change, the agent did not:
- Search for `role="menuitem"` in JavaScript files
- Test the menu functionality
- Verify that event listeners are attached
- Verify that keyboard navigation works

---

## Cascade of Failures

Due to the 5 missed selector updates, the menu experiences a **complete functional breakdown**:

1. ❌ **No click handlers** (line 346) → Menu items don't respond to clicks
2. ❌ **No focus management** (line 1936) → Focus stays on button when menu opens
3. ❌ **No arrow navigation** (line 1951) → Up/Down arrows do nothing
4. ❌ **No checkmark initialization** (line 115) → Current view not indicated on load
5. ❌ **No checkmark updates** (line 2006) → Checkmarks don't update after switching

**User must use Tab key** because:
- Focus doesn't move to menu (item 2)
- Arrow keys don't work (item 3)
- Tab is the only remaining keyboard navigation method

---

## Reproduction Steps

1. Open FastWeather webapp
2. Press Alt+V (or click View button)
3. **Expected**: Menu opens AND focus moves to "Flat" menu item
4. **Actual**: Menu opens BUT focus stays on "View: Flat ▼" button
5. Press Down Arrow
6. **Expected**: Focus moves to next menu item
7. **Actual**: Nothing happens
8. Press Tab
9. **Observed**: Focus NOW moves into menu (wrong pattern)

---

## Fix Requirements

Update all 5 JavaScript selector instances from `[role="menuitem"]` to `[role="menuitemradio"]`:

1. Line 115: Initialization checkmarks
2. Line 346: Click event listeners
3. Line 1936: Focus first item on open
4. Line 1951: Arrow key navigation
5. Line 2006: Update checkmarks on view change

**Verification**: After fix, confirm:
- Alt+V opens menu AND moves focus to first item
- Arrow keys navigate between items
- Enter/Space selects item
- Checkmarks show current selection
- Escape closes menu and returns focus to button

---

## Recommendations for Agent Improvement

### 1. Multi-File Refactoring Awareness
When changing a structural attribute (role, ID, class, data attribute):
- Search ALL workspace files for references to the old value
- Update ALL occurrences, not just the definition
- Use tools like `grep_search` to find all references

### 2. Selector Update Verification
After changing HTML attributes that JavaScript queries:
- Search for the old selector pattern in all .js files
- List all locations that need updating
- Update them in a single batch with `multi_replace_string_in_file`

### 3. Functional Testing Requirements
For interactive components (menus, dialogs, forms):
- Document expected behavior before changes
- Verify behavior still works after changes
- Test keyboard navigation specifically

### 4. Change Impact Analysis
Before committing:
- Ask: "What code might reference this attribute?"
- Search for: Attribute selectors, querySelectorAll, querySelector
- Check: Event listener attachment, initialization code, state management

### 5. Atomic Refactoring
Changes that span HTML + JavaScript should be:
- Identified as "multi-file refactoring" operations
- Executed atomically (all files updated together)
- Verified together before commit

---

## Recommended Agent Workflow

```
WHEN changing HTML role/attribute:
1. Identify the change (menuitem → menuitemradio)
2. Search workspace for old selector: grep '[role="menuitem"]'
3. List ALL files that reference it
4. Update HTML file
5. Update ALL JavaScript references in parallel
6. Verify no references to old value remain
7. Document the change in commit message
8. Test functionality
```

---

## Files Requiring Fix

**File**: `webapp/app.js`  
**Lines to change**: 115, 346, 1936, 1951, 2006  
**Pattern**: `[role="menuitem"]` → `[role="menuitemradio"]`  
**Tool**: Use `multi_replace_string_in_file` to update all 5 in one operation

---

## Agent Accountability

**Agent**: accessibility-lead (orchestrator)  
**Sub-agents involved**: aria-specialist  
**Session**: February 25, 2026 accessibility remediation  
**Commit**: 95d10f9  

**Issue classification**: Incomplete implementation of correct ARIA pattern  
**Skill gap**: Multi-file coordination, refactoring verification  

---

**Status**: Bug identified and documented  
**Next step**: Apply fix to webapp/app.js (5 selector updates)

---

## Appendix: Git Diff Evidence

### What Changed in HTML (commit 95d10f9)

```diff
--- a/webapp/index.html (67952ec - before)
+++ b/webapp/index.html (95d10f9 - after)

 <ul id="view-menu" role="menu" aria-labelledby="view-menu-btn" hidden>
     <li role="none">
-        <button role="menuitem" data-view="flat" aria-checked="true">Flat</button>
+        <button role="menuitemradio" data-view="flat" aria-checked="true">Flat</button>
     </li>
     <li role="none">
-        <button role="menuitem" data-view="table" aria-checked="false">Table</button>
+        <button role="menuitemradio" data-view="table" aria-checked="false">Table</button>
     </li>
     <li role="none">
-        <button role="menuitem" data-view="list" aria-checked="false">List</button>
+        <button role="menuitemradio" data-view="list" aria-checked="false">List</button>
     </li>
 </ul>
```

### What Did NOT Change (but should have)

**File**: `webapp/app.js`  
**Status**: NO CHANGES to menuitem selectors in commit 95d10f9

All 5 references to `[role="menuitem"]` remain unchanged:
- Line 115: `document.querySelectorAll('#view-menu [role="menuitem"]')`
- Line 346: `document.querySelectorAll('#view-menu [role="menuitem"]')`
- Line 1936: `viewMenu.querySelector('[role="menuitem"]')`
- Line 1951: `e.currentTarget.querySelectorAll('[role="menuitem"]')`
- Line 2006: `document.querySelectorAll('#view-menu [role="menuitem"]')`

**Result**: JavaScript now queries for elements that do not exist, causing complete menu failure.

