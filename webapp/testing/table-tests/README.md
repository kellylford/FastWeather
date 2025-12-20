# Table Accessibility Test Suite

This directory contains individual test pages to isolate iOS VoiceOver table navigation issues.

## Test Pages

1. **baseline.html** - Pure HTML table with no CSS modifications (control)
2. **with-overflow-hidden.html** - Adds `overflow: hidden` to table
3. **with-sticky-headers.html** - Adds `position: sticky` to headers
4. **with-display-block.html** - Adds `display: block` (mobile pattern)
5. **with-role-region.html** - Wraps table in `role="region"` container
6. **with-links.html** - Adds links inside table cells
7. **full-app-styles.html** - All problematic styles combined (like production)
8. **recommended-fix.html** - Accessible alternative using wrapper div

## Testing Instructions

1. Open each page on your iOS device in Safari, Chrome, and Edge
2. Enable VoiceOver (Settings > Accessibility > VoiceOver)
3. Navigate to the table
4. Test the following:
   - Does VoiceOver announce table dimensions when first encountered?
   - After swiping into the table, does it maintain table context?
   - Can you navigate by rows using the rotor?
   - Can you navigate by columns using the rotor?
   - Are row/column headers announced when moving between cells?
   - Does direct touch on cells announce position correctly?

## Expected Results

- **baseline.html** - Should work perfectly
- **with-display-block.html** - Most likely to break table navigation
- **with-sticky-headers.html** - Likely to break table navigation
- **with-overflow-hidden.html** - May break table navigation
- **recommended-fix.html** - Should work well while maintaining scrolling

## Notes

Each page uses the same sample weather data. Record which specific behaviors break on which pages to identify the root cause.
