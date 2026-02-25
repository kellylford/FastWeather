# Color Contrast Fixes - Quick Reference

## Critical Fixes (WCAG AA Blockers)

### Fix 1: Light Mode Border Contrast
**File:** [styles.css](styles.css#L21)  
**Change:**
```css
/* BEFORE */
--border-color: #d0d0d0;  /* 1.52:1 - FAILS */

/* AFTER */
--border-color: #959595;  /* 3.0:1 - PASSES */
```
**Impact:** Makes form inputs, card boundaries, and table borders visible to users with low vision

---

### Fix 2: Dark Mode Border Contrast
**File:** [styles.css](styles.css#L1344)  
**Change:**
```css
/* BEFORE */
--border-color: #404040;  /* 1.49:1 - FAILS */

/* AFTER */
--border-color: #6b6b6b;  /* 3.01:1 - PASSES */
```
**Impact:** Makes form inputs and UI boundaries visible in dark mode

---

### Fix 3: Dark Mode Muted Text
**File:** [styles.css](styles.css#L1343)  
**Change:**
```css
/* BEFORE */
--text-muted: #888888;  /* 3.93:1 - FAILS */

/* AFTER */
--text-muted: #a0a0a0;  /* 4.92:1 - PASSES */
```
**Impact:** Makes placeholder text and secondary labels readable in dark mode

---

## Major Fixes (Strengthen Critical Feedback)

### Fix 4: Severe Alert Badge Background
**File:** [styles.css](styles.css#L1390)  
**Change:**
```css
/* BEFORE */
.alert-badge.severe {
    background-color: #fd7e14;  /* 3.07:1 - fails for small text */
    color: white;
}

/* AFTER */
.alert-badge.severe {
    background-color: #c75d00;  /* 4.58:1 - PASSES */
    color: white;
}
```
**Also update:** [styles.css](styles.css#L1428) (`.alert-severity-header.severe`)

---

### Fix 5: Dark Mode Primary Button Hover
**File:** [styles.css](styles.css#L1353)  
**Change:**
```css
/* BEFORE */
--button-primary-hover: #4da3ff;  /* 3.84:1 - borderline */

/* AFTER */
--button-primary-hover: #2196f3;  /* 4.52:1 - PASSES */
```
**Impact:** Ensures button text remains readable on hover in dark mode

---

### Fix 6: Light Mode Error Text (Strengthen)
**File:** [styles.css](styles.css#L26)  
**Change:**
```css
/* BEFORE */
--error-text: #c00;  /* #cc0000, 5.67:1 - passes but minimal */

/* AFTER */
--error-text: #a00000;  /* 7.12:1 - stronger for critical errors */
```
**Impact:** Makes critical error messages more readable under all conditions

---

## Optional Enhancements (Increase Safety Margins)

### Enhancement 1: Light Mode Muted Text
**File:** [styles.css](styles.css#L20)  
**Change:**
```css
/* BEFORE */
--text-muted: #6a6a6a;  /* 5.34:1 - passes but close */

/* AFTER */
--text-muted: #5a5a5a;  /* 6.73:1 - better margin */
```

---

### Enhancement 2: Success Text  
**File:** [styles.css](styles.css#L28)  
**Change:**
```css
/* BEFORE */
--success-text: #060;  /* #006600, 7.79:1 - already good */

/* AFTER */
--success-text: #005500;  /* 8.21:1 - slightly stronger */
```

---

### Enhancement 3: Extreme Alert Badge
**File:** [styles.css](styles.css#L1385)  
**Change:**
```css
/* BEFORE */
.alert-badge.extreme {
    background-color: #dc3545;  /* 4.53:1 - minimal margin */
    color: white;
}

/* AFTER */
.alert-badge.extreme {
    background-color: #b71c1c;  /* 7.03:1 - AAA level for safety */
    color: white;
}
```
**Also update:** [styles.css](styles.css#L1423) (`.alert-severity-header.extreme`)

---

## Documentation Corrections

### Update ACCESSIBILITY.md
**File:** [ACCESSIBILITY.md](ACCESSIBILITY.md#L24-L30)  

**Change line 26:**
```markdown
<!-- BEFORE -->
- Light mode primary text: #1a1a1a on #ffffff = 19.56:1 ✓

<!-- AFTER -->
- Light mode primary text: #1a1a1a on #ffffff = 16.25:1 ✓
```

**Change line 30:**
```markdown
<!-- BEFORE -->
- Dark mode temperature: #66b3ff on #2a2a2a = 4.92:1 ✓ (large text)

<!-- AFTER -->
- Dark mode temperature: #66b3ff on #2a2a2a = 5.66:1 ✓ (large text)
```

**Remove lines 34-35:**
```markdown
<!-- REMOVE -->
- Borders: #d0d0d0 on #ffffff = 1.8:1 (enhanced with 2px width)
```

**Add replacement:**
```markdown
<!-- ADD -->
- UI Component Borders: #959595 on #ffffff = 3.0:1 ✓ (meets WCAG 1.4.11)
- Dark mode borders: #6b6b6b on #1a1a1a = 3.01:1 ✓
```

---

## Implementation Order

### Phase 1: Critical (Deploy ASAP)
1. ✅ Light mode border color → `#959595`
2. ✅ Dark mode border color → `#6b6b6b`  
3. ✅ Dark mode muted text → `#a0a0a0`

### Phase 2: Major (Deploy within 1 week)
4. ✅ Severe alert badge → `#c75d00`
5. ✅ Dark mode button hover → `#2196f3`
6. ✅ Error text → `#a00000`

### Phase 3: Documentation (Deploy with Phase 2)
7. ✅ Update ACCESSIBILITY.md with corrected ratios

### Phase 4: Enhancements (Optional, next release)
8. ⭕ Muted text → `#5a5a5a`
9. ⭕ Success text → `#005500`
10. ⭕ Extreme alert → `#b71c1c`

---

## Testing Checklist

After implementing fixes:

- [ ] Run axe DevTools on all pages
- [ ] Test form inputs in both light and dark mode
- [ ] Verify alert badge readability
- [ ] Test with Chrome DevTools color vision simulators:
  - [ ] Protanopia (red-blind)
  - [ ] Deuteranopia (green-blind)
  - [ ] Tritanopia (blue-blind)
  - [ ] Achromatopsia (total color blindness)
- [ ] Test with Windows High Contrast Mode
- [ ] Verify focus indicators are visible on all backgrounds
- [ ] Check responsive views (320px, 768px, 1024px widths)

---

## Color Palette Reference (After Fixes)

### Light Mode
```css
:root {
    --primary-bg: #ffffff;
    --secondary-bg: #f5f5f5;
    --card-bg: #ffffff;
    --text-primary: #1a1a1a;      /* 16.25:1 */
    --text-secondary: #4a4a4a;    /* 9.21:1 */
    --text-muted: #5a5a5a;        /* 6.73:1 - UPDATED */
    --border-color: #959595;      /* 3.0:1 - UPDATED */
    --focus-outline: #0066cc;     /* 6.29:1 */
    --link-color: #0066cc;        /* 6.29:1 */
    --link-hover: #004999;        /* 8.59:1 */
    --error-bg: #fee;
    --error-text: #a00000;        /* 7.12:1 - UPDATED */
    --success-bg: #efe;
    --success-text: #005500;      /* 8.21:1 - UPDATED */
    --button-primary: #0066cc;    /* white = 6.29:1 */
    --button-primary-hover: #0052a3; /* white = 7.35:1 */
    --button-secondary: #6c757d;  /* white = 4.54:1 */
    --button-secondary-hover: #545b62; /* white = 5.67:1 */
    --button-danger: #dc3545;     /* white = 4.53:1 */
    --button-danger-hover: #c82333; /* white = 5.26:1 */
    --temperature-color: #0066cc; /* 6.29:1 */
}
```

### Dark Mode
```css
@media (prefers-color-scheme: dark) {
    :root {
        --primary-bg: #1a1a1a;
        --secondary-bg: #2a2a2a;
        --card-bg: #2a2a2a;
        --text-primary: #e0e0e0;      /* 12.65:1 */
        --text-secondary: #b0b0b0;    /* 7.21:1 */
        --text-muted: #a0a0a0;        /* 4.92:1 - UPDATED */
        --border-color: #6b6b6b;      /* 3.01:1 - UPDATED */
        --focus-outline: #4da3ff;     /* 7.83:1 */
        --link-color: #4da3ff;        /* 7.83:1 */
        --link-hover: #7ab8ff;        /* 9.72:1 */
        --error-bg: #4a1a1a;
        --error-text: #ff6b6b;        /* 6.34:1 */
        --success-bg: #1a4a1a;
        --success-text: #6bff6b;      /* 7.89:1 */
        --button-primary: #0066cc;    /* white = 6.29:1 */
        --button-primary-hover: #2196f3; /* white = 4.52:1 - UPDATED */
        --button-secondary: #4a4a4a;  /* white = 9.21:1 */
        --button-secondary-hover: #5a5a5a; /* white = 7.35:1 */
        --button-danger: #dc3545;     /* white = 4.53:1 */
        --button-danger-hover: #e74c3c; /* white = 3.97:1 */
        --temperature-color: #66b3ff; /* 5.66:1 */
    }
}
```

### Alert Badges
```css
.alert-badge.extreme,
.alert-severity-header.extreme {
    background-color: #b71c1c;  /* white = 7.03:1 - UPDATED */
    color: white;
}

.alert-badge.severe,
.alert-severity-header.severe {
    background-color: #c75d00;  /* white = 4.58:1 - UPDATED */
    color: white;
}

.alert-badge.moderate,
.alert-severity-header.moderate {
    background-color: #ffc107;  /* #1a1a1a = 10.34:1 */
    color: #1a1a1a;
}

.alert-badge.minor,
.alert-severity-header.minor {
    background-color: #0dcaf0;  /* #1a1a1a = 8.29:1 */
    color: #1a1a1a;
}

.alert-badge.unknown,
.alert-severity-header.unknown {
    background-color: #6c757d;  /* white = 4.54:1 */
    color: white;
}
```

---

## Automation Recommendations

Add to your build process:

```bash
# Install axe-core CLI
npm install -g @axe-core/cli

# Run automated checks
axe http://localhost:8000 --rules color-contrast --save audit.json

# Or use pa11y
npm install -g pa11y
pa11y http://localhost:8000 --standard WCAG2AA --reporter cli
```

Add to package.json:
```json
{
  "scripts": {
    "test:a11y": "axe --rules color-contrast http://localhost:8000",
    "test:contrast": "pa11y-ci --threshold 0"
  }
}
```

---

**Questions or need help implementing?**  
Refer to [COLOR_CONTRAST_AUDIT.md](COLOR_CONTRAST_AUDIT.md) for detailed analysis including calculation formulas, impact assessments, and specific line numbers for each fix.
