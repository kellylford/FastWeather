# View Menu Bug Report - Failed to Understand Intent Before Changing Code

**Date**: February 25, 2026  
**Reporter**: Kelly Ford  
**Severity**: CRITICAL - Broke working UI functionality  
**Component**: View menu keyboard navigation (Alt+V)  
**Affected Files**: `webapp/index.html`, `webapp/app.js`  
**Root Cause**: Agent changed working UX without understanding design intent or testing changes

---

## Executive Summary

An accessibility audit agent broke a fully functional, keyboard-accessible menu by:
1. Changing ARIA roles without understanding the intended user experience
2. Making incomplete multi-file refactoring (changed HTML but not JavaScript)
3. Not testing the changes before committing
4. Not offering to revert when breakage was reported

**The core failure**: Agent applied spec rules before understanding what the component was supposed to DO.

---

## Problem Summary

**Before the "fix" (Working correctly)**:
- Press Alt+V → Menu opens AND focus moves to first menu item
- Up/Down arrow keys navigate between menu items
- Enter/Space selects an item
- Escape closes and returns focus to button
- All documented in user guide, intentionally designed

**After the "fix" (Completely broken)**:
- Press Alt+V → Menu opens BUT focus stays on button
- Arrow keys don't work (JavaScript can't find menu items)
- Tab key required to reach menu items
- Checkmarks don't update when view changes
- Menu system completely non-functional

---

## What Went Wrong

### The Process Failure

**The agent's process**:
1. ❌ Spotted ARIA pattern that didn't match spec perfectly
2. ❌ Applied "fix" without understanding intended UX
3. ❌ Changed HTML but forgot to update JavaScript
4. ❌ Committed without testing
5. ❌ Broke fully working, documented functionality

**The correct process should have been**:
1. ✅ Notice pattern that doesn't match spec
2. ✅ **Ask: "What is this supposed to do? What's the intended UX?"**
3. ✅ Check documentation (user guide documented Alt+V behavior)
4. ✅ Test that it actually works before declaring it broken
5. ✅ Choose the right ARIA pattern to achieve that UX intent
6. ✅ Update HTML and JavaScript together atomically
7. ✅ **Test that nothing broke**
8. ✅ Only then commit

### Evidence the Original Code Was Intentional

**1. User guide documentation** (`user-guide.html` line 265):
```
Alt+V - Open view mode menu
```

**2. Original HTML explicitly declared the keyboard shortcut**:
```html
<button id="view-menu-btn" 
        aria-haspopup="menu" 
        aria-expanded="false"
        aria-keyshortcuts="Alt+V" 
        title="Change view mode (Alt+V)">
```

**3. Focus management was deliberately implemented**:
```javascript
function openViewMenu() {
    viewMenu.hidden = false;
    viewMenuBtn.setAttribute('aria-expanded', 'true');
    
    // Intentionally moves focus to first menu item
    const firstItem = viewMenu.querySelector('[role="menuitem"]');
    if (firstItem) {
        firstItem.focus();
    }
}
```

**4. Arrow key navigation was fully implemented**:
```javascript
function handleViewMenuKeydown(e) {
    const items = Array.from(e.currentTarget.querySelectorAll('[role="menuitem"]'));
    const currentIndex = items.indexOf(document.activeElement);
    
    switch(e.key) {
        case 'ArrowDown':
            // Navigate to next item
        case 'ArrowUp':
            // Navigate to previous item
        case 'Enter':
        case ' ':
            // Select item
        case 'Escape':
            // Close menu
    }
}
```

This was not accidental code - it was **fully implemented, tested, working, and documented**.

---

## The Two Bugs Introduced

### Bug #1: Changed Working Code Without Understanding Intent

**What the agent changed** (Commit `95d10f9`):

```html
<!-- BEFORE (working) -->
<button role="menuitem" data-view="flat" aria-checked="true">Flat</button>

<!-- AFTER (broken) -->
<button role="menuitemradio" data-view="flat" aria-checked="true">Flat</button>
```

**Why the agent changed it**:
- Audit finding claimed: "`role='menuitem'` uses `aria-checked` (only valid on menuitemradio/menuitemcheckbox)"
- Agent reasoning: "ARIA spec says `aria-checked` is for `menuitemradio`, so I'll change it"

**What the agent SHOULD have done**:
- Understand that `menuitemradio` IS the correct role for this use case
- But also understand that changing the role requires updating JavaScript selectors
- Test the original code to see if it works before declaring it broken
- **Ask the user about intended behavior if uncertain**

**The agent never asked**:
- "What is this menu supposed to do?"
- "Should focus move automatically to the menu when opened?"
- "Is this meant to be a menu or a radio group?"
- "The keyboard behavior works - do you want me to change the ARIA to match, or is there a reason for this pattern?"

### Bug #2: Incomplete Multi-File Refactoring

**The agent changed HTML** from `role="menuitem"` to `role="menuitemradio"` but **failed to update JavaScript**.

**5 locations in app.js still queried for the old role**, breaking everything:

1. **Line 115** - Initialization:
   ```javascript
   document.querySelectorAll('#view-menu [role="menuitem"]')
   ```

2. **Line 346** - Event listeners:
   ```javascript
   document.querySelectorAll('#view-menu [role="menuitem"]')
   ```

3. **Line 1936** - Focus management:
   ```javascript
   const firstItem = viewMenu.querySelector('[role="menuitem"]');
   ```

4. **Line 1951** - Arrow navigation:
   ```javascript
   const items = Array.from(e.currentTarget.querySelectorAll('[role="menuitem"]'));
   ```

5. **Line 2006** - State updates:
   ```javascript
   document.querySelectorAll('#view-menu [role="menuitem"]')
   ```

**Result**: JavaScript couldn't find any menu items, completely breaking:
- Focus management (focus didn't move to menu)
- Arrow key navigation (no items to navigate)
- Click handlers (not attached to anything)
- State updates (checkmarks didn't update)

**The agent also removed** documented attributes:
- Removed `aria-keyshortcuts="Alt+V"` from button
- Removed `title="Change view mode (Alt+V)"` from button

---

## The Fix

### What Was Fixed

**1. Restored the documented keyboard shortcut**:
```html
<button id="view-menu-btn" 
        aria-haspopup="menu" 
        aria-expanded="false"
        aria-keyshortcuts="Alt+V" 
        title="Change view mode (Alt+V)">
```

**2. Updated all 5 JavaScript selectors** from `[role="menuitem"]` to `[role="menuitemradio"]`:
- Line 115: Initialization
- Line 346: Event listeners
- Line 1936: Focus management
- Line 1951: Arrow navigation
- Line 2006: State updates

**3. Kept the correct ARIA pattern**:
- HTML has `role="menuitemradio"` (correct for mutually exclusive selections)
- JavaScript now queries for `menuitemradio` (matches HTML)
- All functionality restored

### The Right ARIA Pattern

**The correct pattern for this use case**:
```html
<button aria-haspopup="menu" aria-expanded="false" aria-keyshortcuts="Alt+V">
    View: Flat ▼
</button>
<ul role="menu">
    <li role="none">
        <button role="menuitemradio" aria-checked="true">Flat</button>
    </li>
    <li role="none">
        <button role="menuitemradio" aria-checked="false">Table</button>
    </li>
    <li role="none">
        <button role="menuitemradio" aria-checked="false">List</button>
    </li>
</ul>
```

**Why `menuitemradio` is correct**:
- This is a menu with mutually exclusive selections
- Only one view can be active at a time
- `aria-checked` indicates which option is selected
- ARIA 1.2 spec requires `menuitemradio` for this pattern
- Screen readers announce "Flat, menu item radio, checked" (perfect!)

**Original code was close** - just needed `menuitemradio` instead of plain `menuitem` to be fully spec-compliant. The UX design was exactly right.

---

## Critical Lessons for AI Agent Development

### 1. Understand Intent Before Changing Code

**When you see working code that doesn't match spec perfectly**:
- ✅ Test it first - does it work?
- ✅ Look for documentation - is this behavior intentional?
- ✅ Check for user complaints - is anyone reporting issues?
- ✅ **Ask: "What is this supposed to DO?"**
- ❌ Don't assume working code is broken just because it's not spec-perfect

**If you're unsure about intent, ASK**:
> "I see this menu uses `menuitem` with `aria-checked`. The spec says `aria-checked` requires `menuitemradio`. Should I update this to be spec-compliant? The current keyboard behavior will be preserved."

**Asking is infinitely better than breaking.**

### 2. Don't Change UX Without Permission

**Working accessibility is better than broken spec compliance**.

If fixing a spec violation requires changing user experience:
- Document what currently works
- Explain what would change
- Ask if the UX change is acceptable
- Only proceed with approval

**Never silently change working UX in the name of spec purity.**

### 3. Test Before Committing

**For any ARIA role change**:
- ✅ Test keyboard navigation still works
- ✅ Verify focus management still works
- ✅ Check that intended UX is preserved
- ✅ If you can't test, document what needs manual testing

**Never commit accessibility changes without functional verification.**

This is especially critical because:
- ARIA affects screen reader behavior (can't see in code review)
- Role changes can break JavaScript selectors (cascading failures)
- Focus management is fragile and breaks easily

### 4. Multi-File Changes Must Be Atomic

**When changing structural attributes (roles, IDs, classes)**:

```bash
# BEFORE changing HTML, search for references
grep -r 'role="menuitem"' .

# Find:
# - index.html: <button role="menuitem"> (3 occurrences)
# - app.js: querySelectorAll('[role="menuitem"]') (5 occurrences)

# Update ALL files together in same commit
```

**Principles**:
- Search ALL workspace files for attribute references
- Update HTML and JavaScript atomically
- You can't change HTML and expect JavaScript to magically update
- **Incomplete refactoring = broken code**

### 5. Revert First When You Break Things

**When user reports "you broke working functionality"**:

```
✅ DO THIS:
User: "You broke the menu."
Agent: "I'm sorry - let me revert immediately. What was the intended behavior?"

❌ NOT THIS:
User: "You broke the menu."
Agent: "Let me complete the refactoring by updating the JavaScript selectors."
```

**When you break working code**:
1. Revert first (restore working state)
2. Understand intent second
3. Re-implement correctly third

**Never try to "fix forward" a breaking change.** Get back to working state, then discuss.

### 6. Read Documentation Before Auditing

**Before declaring something broken**:
- Check for user guides, README files, documentation
- Look for code comments explaining unusual patterns
- Search for attributes like `aria-keyshortcuts` (indicates intentional design)
- Respect documented behavior as intended

**In this case**:
- User guide documented Alt+V menu behavior
- HTML had `aria-keyshortcuts="Alt+V"`
- Code had full focus management implementation
- All signals said "this is intentional"

**The agent ignored all of these signals and changed it anyway.**

---

## Recommendations

### For AI Accessibility Agents

**1. Intent-first workflow**:
```
BEFORE: See violation → Apply fix → Break code
AFTER:  See pattern → Understand intent → Choose right pattern for that intent → Implement → Test
```

**2. Clarifying questions checklist**:
When encountering non-standard ARIA:
- What is this component supposed to do?
- What keyboard behavior is expected?
- Is there documentation of this pattern?
- Are there user complaints?
- Would changing this alter user experience?

**3. Testing requirements**:
For any ARIA change:
- Document current behavior before changing
- Verify behavior preserved after changing
- Test keyboard navigation specifically
- Require manual verification if automated testing not possible

**4. Rollback policy**:
If user reports breakage:
- Offer immediate revert
- Ask about intended behavior
- Only re-implement after understanding intent

### For Project Maintainers

**Document your intent**:
- User guides should document keyboard shortcuts
- Use `aria-keyshortcuts` attribute to declare shortcuts in HTML
- Add code comments for unusual patterns
- Keep a "design decisions" document for non-standard choices

**This helps AI agents understand your intent and avoid breaking working code.**

---

## Conclusion

This bug exemplifies a critical failure in AI-assisted accessibility work: **applying spec rules without understanding user intent**.

**The agent was technically correct** that `aria-checked` belongs on `menuitemradio`, not plain `menuitem`.

**But the agent failed to**:
1. Understand what the component was supposed to do
2. Test that the current implementation worked
3. Ask clarifying questions about intent
4. Update all references when changing structural attributes
5. Test before committing
6. Offer to revert when breakage was reported

**The result**: Fully working, keyboard-accessible, documented functionality was completely broken by a "fix" that was:
- Unnecessary (code worked fine)
- Incomplete (HTML changed, JavaScript not updated)
- Untested (committed without verification)
- Destructive (broke working UX)

**Working accessibility > Spec purity with broken functionality.**

The lesson: **Understand intent first. Then apply the right technical solution to achieve that intent. Always test. Never break working code.**

---

## Timeline

1. **Original state**: Fully working menu with `role="menuitem"` + `aria-checked`
2. **Accessibility audit**: Agent identified as spec violation
3. **Commit 95d10f9**: Changed HTML to `menuitemradio`, didn't update JavaScript
4. **User testing**: "You broke the menu"
5. **Agent response**: Tried to "fix forward" instead of reverting
6. **User clarification**: "The original was working and intentional"
7. **Final fix**: Updated all 5 JavaScript selectors, restored `aria-keyshortcuts`
8. **Result**: Working again with correct ARIA pattern

**Total time broken**: Multiple hours across multiple user sessions  
**Could have been avoided**: Yes, with proper intent understanding and testing

---

## The Final Verdict: Zero Accessibility Benefit

**User tested with JAWS and NVDA screen readers** comparing:
- Original: `role="menuitem"` + `aria-checked`  
- "Fixed": `role="menuitemradio"` + `aria-checked`

**Result**: **THE EXPERIENCE WAS IDENTICAL.**

Screen readers announced the menu items the same way in both cases. The `menuitem` → `menuitemradio` change had **zero practical accessibility benefit** for actual users with screen readers.

**What the agent accomplished**:
- ❌ Broke working functionality
- ❌ Removed documented keyboard shortcuts  
- ❌ Required multiple sessions to fix
- ❌ Wasted hours of user time
- ✅ Achieved perfect spec compliance
- ❌ **Improved accessibility for exactly zero users**

**The lesson**: **Spec compliance without demonstrated user benefit is worthless.** 

Test with actual assistive technology before declaring something "broken." If the experience is identical, don't change working code.

---

**Status**: RESOLVED (but should never have happened)  
**Resolution**: All JavaScript selectors updated to match `menuitemradio`, keyboard shortcut attributes restored, functionality verified working by user.  
**Actual Accessibility Impact**: None. Screen reader experience identical before and after.  
**User Impact**: Negative. Working functionality broken, time wasted, zero benefit delivered.
