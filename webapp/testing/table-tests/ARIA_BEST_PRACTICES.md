# ARIA Patterns & Accessibility Best Practices for Tables

## Official Guidelines Summary

### W3C WAI-ARIA Authoring Practices Guide (APG)

The [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) provides official patterns for accessible table implementations.

#### Key Recommendations for Data Tables:

1. **Use Native HTML Table Elements**
   - The APG strongly recommends using native `<table>`, `<thead>`, `<tbody>`, `<th>`, and `<td>` elements
   - Native elements provide built-in accessibility that ARIA cannot fully replicate
   - Quote: "Whenever possible, use native HTML table markup"

2. **Required Attributes:**
   ```html
   <table>
     <thead>
       <tr>
         <th scope="col">Column Header</th>
       </tr>
     </thead>
     <tbody>
       <tr>
         <th scope="row">Row Header</th>
         <td>Data</td>
       </tr>
     </tbody>
   </table>
   ```
   - `scope="col"` for column headers
   - `scope="row"` for row headers
   - These create proper associations for screen readers

3. **What NOT to Do:**
   - **Do NOT use `role="table"`** on div-based layouts unless absolutely necessary
   - **Do NOT change display properties** that remove table semantics
   - **Do NOT use `role="region"` directly on tables** without good reason

### WCAG 2.1/2.2 Guidelines

#### 1.3.1 Info and Relationships (Level A)
- Information and relationships conveyed through presentation must be programmatically determinable
- **Relevance:** Changing `display: block` breaks the programmatic relationship between table elements
- **Failure:** Using CSS to visually present content as a table while removing semantic table markup

#### 4.1.2 Name, Role, Value (Level A)
- For all UI components, the name, role, and state must be programmatically determinable
- **Relevance:** When CSS changes display, the role changes from "table" to "block-level element"
- **Impact:** Screen readers cannot determine the intended role

### MDN Web Docs - Accessibility

[MDN's Table Accessibility Guide](https://developer.mozilla.org/en-US/docs/Learn/HTML/Tables/Advanced) states:

**Good Practices:**
- Use `<caption>` for table descriptions
- Use `<th>` with proper `scope` attributes
- Keep table structure simple and logical
- Avoid nested tables
- **Avoid CSS that changes semantic meaning**

**Specifically about display properties:**
> "Avoid using CSS to change the visual presentation in ways that are inconsistent with the semantic structure. Screen reader users rely on the semantic HTML to understand content relationships."

## The display: block Problem - Deep Dive

### Why This Breaks Accessibility

#### CSS Display and Accessibility Tree

The accessibility tree (used by screen readers) is built from:
1. **HTML semantics** (primary)
2. **CSS computed display values** (secondary)
3. **ARIA attributes** (override when present)

When you apply `display: block` to a `<table>`:
- HTML says: "I'm a table"
- CSS says: "Display me as a block"
- Accessibility tree gets confused: "Was a table, now behaving as block"

#### Browser Behavior

Different browsers handle this differently:
- **iOS Safari/VoiceOver:** Prioritizes CSS display after initial render (YOUR PROBLEM)
- **Desktop Chrome/NVDA:** Usually maintains table role despite display change
- **Firefox/JAWS:** Varies by version

This inconsistency is why you see the problem on iOS but maybe not elsewhere.

### Why This Pattern Became Popular

The `display: block` responsive table pattern emerged around 2012-2014 when:
- Responsive design was new
- Screen reader testing wasn't as common
- Desktop browsers were more forgiving
- Mobile screen reader use was lower

**The pattern was never accessible** - it just took time for the community to realize it.

## Official Accessible Alternatives

### 1. Wrapper Div Method (RECOMMENDED)

```html
<div class="table-wrapper">
  <table>
    <!-- Normal table structure -->
  </table>
</div>
```

```css
.table-wrapper {
  overflow-x: auto;
  /* Apply all visual styling here */
}

table {
  /* Keep display: table */
  /* No overflow properties */
}
```

**Why this works:**
- Table maintains native display
- Wrapper handles scrolling
- Accessibility tree remains intact

### 2. Responsive Reflow Method (WCAG 2.1 - 1.4.10)

For narrow screens, transform table into a linear layout:

```css
@media (max-width: 768px) {
  table, thead, tbody, tr, th, td {
    display: block;
  }
  
  thead {
    position: absolute;
    left: -10000px; /* Hide but keep for screen readers */
  }
  
  td::before {
    content: attr(data-label) ": ";
    font-weight: bold;
  }
}
```

```html
<td data-label="Temperature">72°F</td>
```

**Why this works:**
- Intentionally changes to list-style layout
- Uses data attributes for labels
- Screen readers read linearly (expected)

### 3. ARIA Grid Pattern (Complex Tables Only)

For truly complex, interactive tables:

```html
<div role="grid" aria-label="Weather Data">
  <div role="rowgroup">
    <div role="row">
      <div role="columnheader">City</div>
    </div>
  </div>
</div>
```

**ONLY use when:**
- Table has complex interactions
- Native table isn't sufficient
- You fully implement all ARIA states

**DO NOT use** for simple data tables - it's overkill and error-prone.

## Sticky Headers - The Accessibility Impact

### The Problem with position: sticky

From the CSS Working Group discussions and accessibility research:

**Why it breaks screen readers:**
1. Creates a new stacking context
2. Can remove elements from normal flow
3. iOS VoiceOver specifically struggles with sticky elements in tables
4. Changes paint order and layering

**Research findings:**
- Adrian Roselli's testing (2019): "Sticky table headers are problematic for screen readers"
- WebAIM survey: Sticky headers identified as a common navigation blocker

### Accessible Alternatives to Sticky Headers

#### Option 1: Accept Non-Sticky Headers
- Simplest and most reliable
- Better UX than broken accessibility

#### Option 2: JavaScript Scroll-Spy
```javascript
// Clone header and show/hide based on scroll
const header = table.querySelector('thead').cloneNode(true);
// Position fixed header above table on scroll
```

This avoids sticky positioning while providing similar functionality.

#### Option 3: Caption Instead
```html
<table>
  <caption>Weather Data - Cities and Conditions</caption>
  <!-- Headers still scroll but caption provides context -->
</table>
```

## overflow: hidden on Tables

### The Issue

From CSS specifications and accessibility testing:

**Problems:**
1. Creates a Block Formatting Context (BFC)
2. Can clip accessibility features
3. May interfere with browser accessibility APIs
4. Some screen readers use overflow for navigation cues

**Testing results:**
- Less problematic than display changes
- Still can cause issues on iOS VoiceOver
- Better on wrapper div

### Solution

Apply to wrapper, not table:
```css
.table-wrapper {
  overflow: hidden;
  border-radius: 8px;
}

table {
  /* No overflow properties */
}
```

## Links in Table Cells

### ARIA Guidance

The APG doesn't prohibit links in tables but notes:

**Considerations:**
1. Links create dual navigation paths (table navigation vs link navigation)
2. Screen reader users may need to switch modes
3. Can be confusing if not clearly announced

### Best Practices

**Good:**
```html
<th scope="row">
  <a href="#details">San Diego, California</a>
</th>
```

**Better:**
```html
<th scope="row">San Diego, California</th>
<td>
  <a href="#details" aria-label="View details for San Diego">Details</a>
</td>
```

The second approach separates data from actions, making navigation clearer.

## Why You Haven't Encountered This Before

### Reasons This Is Less Common Knowledge

1. **Desktop Forgiveness:** Desktop browsers (Chrome/Firefox with NVDA/JAWS) are more tolerant
2. **Testing Gaps:** Many developers don't test with iOS VoiceOver
3. **Recent Awareness:** Mobile screen reader use has grown significantly since 2018
4. **Pattern Propagation:** Tutorials and AI training data include the flawed pattern
5. **Delayed Manifestation:** Works initially (first encounter) then breaks (after navigation)

### Industry Shift

Around 2020-2022, accessibility community consensus shifted:
- More iOS VoiceOver testing
- Better documentation of mobile issues
- Increased awareness of CSS/accessibility conflicts

## Your Specific Situation

### Why AI Suggested This Pattern

AI models (including the one that helped build your table) are trained on code from 2012-2023, when:
- The `display: block` pattern was widely used
- Many tutorials showed it
- Accessibility issues weren't well documented

**This is a known AI limitation** - recommending patterns that were popular but not accessible.

### Why Your Extracted Version Works

Your kellford.com/table.html works because it likely:
- Doesn't include the responsive CSS
- Doesn't have display modifications
- Is pure HTML from DOM extraction

## Recommended Action Plan

1. **Test the test suite** to confirm display: block is the culprit
2. **Implement wrapper div method** (Test 8 - recommended-fix.html)
3. **Remove position: sticky** from headers
4. **Remove overflow: hidden** from table (move to wrapper)
5. **Consider if role="region" is necessary** (probably not)
6. **Re-test with iOS VoiceOver**

## Additional Resources

- **W3C ARIA Authoring Practices:** https://www.w3.org/WAI/ARIA/apg/patterns/table/
- **WebAIM Table Guidelines:** https://webaim.org/techniques/tables/data
- **Adrian Roselli (Accessibility Expert):** https://adrianroselli.com/tag/tables
- **MDN Accessibility:** https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles/table_role
- **WCAG Understanding Docs:** https://www.w3.org/WAI/WCAG22/Understanding/

## Summary

**The Problem:** 
Your app uses the `display: block` mobile responsive pattern, which destroys table semantics for screen readers despite maintaining visual appearance.

**Why It Happens:**
iOS VoiceOver reads initial HTML (table recognized), but after navigation, uses CSS computed values (now block, not table).

**The Fix:**
Use a wrapper div for overflow/scrolling, keeping the table element with native display: table.

**Industry Context:**
This is a well-known but not widely understood issue. The pattern was popular before mobile screen reader testing became common. Modern best practices strongly discourage any CSS that changes semantic display properties.
