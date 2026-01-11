# FastWeather Accessibility Guide

This document provides detailed information about FastWeather's accessibility features and how to use them effectively.

## Overview

FastWeather for macOS is designed to be fully accessible to everyone, including users who rely on assistive technologies. Every feature is keyboard accessible, properly labeled for screen readers, and meets WCAG 2.2 AA standards.

## VoiceOver Usage

### Getting Started with VoiceOver

1. **Enable VoiceOver**: Press **⌘F5** or go to System Settings → Accessibility → VoiceOver
2. **Launch FastWeather**: The app announces "FastWeather" when opened
3. **Navigate**: Use **VO + arrow keys** to navigate through elements

### VoiceOver Navigation Tips

#### Main Window
- **VO + Right/Left Arrow**: Move between elements
- **VO + Shift + Down**: Interact with groups (like the city list)
- **VO + Shift + Up**: Stop interacting
- **VO + Space**: Activate buttons and select items

#### City List
```
"Add New City" (Heading)
"City search field" - Enter a city name or zip code, then press Add City button
"Add City button" - Add [city name] to your city list

"Your Cities" (Heading)
"Cities list" - 5 cities. Select a city to view weather details.
"Madison, Wisconsin, United States, 12°C, Clear sky" (Button)
"San Diego, California, United States, 18°C, Mainly clear" (Button)
...
```

#### Weather Detail View
```
"Madison, Wisconsin, United States, Last updated: Dec 12, 2025 at 2:30 PM"

"Current Conditions" (Heading)
"Temperature: 12°C"
"Clear sky"
"Feels Like: 10°C"
"Humidity: 65%"
"Wind: 15 km/h N"
...

"Hourly Forecast" (Heading)
"Hourly forecast for the next 12 hours"
"2PM: 12°, Clear sky"
"3PM: 13°, Mainly clear"
...

"7-Day Forecast" (Heading)
"Thu, Dec 12: Clear sky. High 15°, Low 8°, Precipitation: 2mm"
...
```

### Status Announcements

FastWeather announces important events:
- **"5 cities found"** - After searching for cities
- **"Added Madison, Wisconsin to your cities"** - When adding a city
- **"Loading weather data for Madison, Wisconsin"** - When loading weather
- **"Weather updated"** - After refresh completes

### VoiceOver Rotor

Use the **VO + U** rotor to quickly jump to:
- **Headings**: Jump between major sections
- **Buttons**: List all interactive buttons
- **Links**: Access help and info links

## Keyboard Navigation

### Full Keyboard Access

Enable **Full Keyboard Access** in System Settings → Keyboard → Keyboard navigation to tab through all controls.

### Navigation Patterns

#### Tab Order
1. Search field
2. Add City button
3. City list
4. Toolbar buttons
5. Detail view content
6. Unit toggle

#### Within City List
- **Up/Down Arrows**: Navigate cities
- **Enter**: Select city and view weather
- **Delete**: Remove selected city
- **⌘ + Drag**: Reorder (with mouse)

#### Within Detail View
- **Tab**: Move through weather sections
- **Shift + Tab**: Move backwards
- **Space**: Toggle unit preference
- **⌘R**: Refresh weather

### Keyboard Shortcuts

#### Global
- **⌘N**: Open city search
- **⌘R**: Refresh selected city
- **⌘,**: Open settings
- **⌘?**: Show help
- **⌘W**: Close window
- **⌘Q**: Quit app

#### Navigation
- **⌘[**: Go back (in sheets)
- **⌘]**: Go forward
- **Esc**: Close sheets/dialogs

#### Editing
- **Delete**: Remove selected city
- **Enter**: Confirm selection
- **Esc**: Cancel operation

## Visual Accessibility

### Contrast Ratios

All text and UI elements meet WCAG 2.2 AA standards:

| Element Type | Required Ratio | FastWeather Ratio |
|-------------|----------------|-------------------|
| Normal text | 4.5:1 | 7.2:1 |
| Large text (18pt+) | 3:1 | 5.8:1 |
| UI components | 3:1 | 4.5:1 |
| Active elements | 3:1 | 6.1:1 |

### High Contrast Mode

FastWeather automatically adapts to macOS High Contrast mode:
- System Settings → Accessibility → Display → Increase contrast
- All colors and borders adjust automatically
- Focus indicators become more prominent

### Dynamic Type

Text scales with system preferences:
- System Settings → Accessibility → Display → Text size
- All text in the app scales proportionally
- Layouts adapt to prevent clipping

### Reduce Motion

If you have "Reduce Motion" enabled:
- System Settings → Accessibility → Display → Reduce motion
- Animations are minimized or removed
- Transitions are instant

## Screen Magnification

### Zoom Support

FastWeather works perfectly with macOS Zoom:
- **⌘ + Option + 8**: Toggle Zoom
- **⌘ + Option + +/-**: Zoom in/out
- All content remains readable and functional when zoomed

### Cursor Tracking

Enable "Follow keyboard focus" in Zoom settings for the zoom window to automatically follow:
- Tab navigation
- Arrow key navigation
- Text input

## Color and Appearance

### Color Information

FastWeather never relies on color alone:
- Weather conditions have **icons + text**
- Temperatures include **numbers + labels**
- Alerts use **symbols + descriptions**

### Dark Mode

Full support for macOS Dark Mode:
- System Settings → Appearance → Dark
- Contrast ratios maintained in both modes
- Icons and colors adapt automatically

### Color Blindness

Accessible to users with color vision deficiencies:
- Distinct shapes for weather icons
- Text labels for all color-coded information
- Patterns in addition to colors where applicable

## Assistive Technologies

### Switch Control

Use Switch Control to navigate FastWeather:
- System Settings → Accessibility → Switch Control
- All interactive elements are reachable
- Proper grouping for efficient navigation

### Voice Control

Navigate and control with voice commands:
- "Click Add City"
- "Show settings"
- "Select Madison"
- All buttons and controls have clear names

### Dictation

Use dictation for text input:
- Enable in System Settings → Keyboard → Dictation
- Works in city search field
- Press **fn fn** (or globe key twice) to activate

## Settings for Accessibility

### Enhanced Descriptions

Enable in Settings → Accessibility:
- Provides more detailed weather descriptions
- Includes contextual information
- Better comprehension for screen reader users

Example:
- Standard: "15°C, Clear sky"
- Enhanced: "Current temperature is 15 degrees Celsius with clear sky conditions. Feels like 13 degrees. Light winds from the north at 10 kilometers per hour. Humidity is 65 percent."

## Tips for Optimal Use

### For VoiceOver Users

1. **Use headings**: Press **VO + ⌘H** to jump between sections
2. **Interact with lists**: Press **VO + Shift + Down** when on the city list
3. **Quick Nav**: Enable Quick Nav (**Left + Right arrows**) for faster navigation
4. **Item Chooser**: Press **VO + I** to search for specific items

### For Keyboard-Only Users

1. **Enable Full Keyboard Access** for complete tab navigation
2. **Learn shortcuts**: Memorize common shortcuts for faster access
3. **Use spacebar**: Activates buttons and toggles
4. **Arrow keys**: Navigate within lists and groups

### For Low Vision Users

1. **Increase text size**: System Settings → Accessibility → Display
2. **Enable high contrast**: Improves visibility of edges
3. **Use zoom**: Magnify specific areas
4. **Try Dark Mode**: May be more comfortable for some users

## Testing Your Setup

### Quick Accessibility Check

1. **Close your eyes** and use VoiceOver to add a city
2. **Unplug your mouse** and navigate using only keyboard
3. **Enable high contrast** and verify readability
4. **Zoom to 200%** and check layout remains usable

### Expected Behavior

✅ **Every element** should be reachable by keyboard  
✅ **All information** should be available via VoiceOver  
✅ **Focus indicators** should always be visible  
✅ **Text** should remain readable at 200% zoom  
✅ **No information** conveyed by color alone  

## Common Issues and Solutions

### VoiceOver not announcing correctly

**Solution**:
1. Restart VoiceOver (**⌘F5** twice)
2. Quit and relaunch FastWeather
3. Check System Settings → Accessibility → VoiceOver is enabled

### Can't navigate with keyboard

**Solution**:
1. Enable Full Keyboard Access: System Settings → Keyboard → Keyboard navigation
2. Press Tab or Shift+Tab to move between elements
3. Check that keyboard shortcuts are not conflicting with system shortcuts

### Text too small even after scaling

**Solution**:
1. Increase system text size: System Settings → Accessibility → Display → Text size
2. Use Zoom feature: ⌘ + Option + 8
3. Try a larger display resolution

### Focus indicator not visible

**Solution**:
1. Enable "Increase contrast": System Settings → Accessibility → Display
2. Check display color calibration
3. Try switching between Light and Dark mode

## Accessibility Feedback

We're committed to making FastWeather accessible to everyone. If you encounter accessibility issues:

1. **Document the issue**: What happened? What did you expect?
2. **Include context**: Which assistive tech? macOS version?
3. **Provide steps**: How can we reproduce it?
4. **Contact us**: Open a GitHub issue or email support

## Resources

### macOS Accessibility
- [Apple Accessibility Support](https://www.apple.com/accessibility/mac/)
- [VoiceOver User Guide](https://support.apple.com/guide/voiceover/welcome/mac)
- [Keyboard Shortcuts](https://support.apple.com/en-us/HT201236)

### WCAG Guidelines
- [WCAG 2.2 Overview](https://www.w3.org/WAI/WCAG22/quickref/)
- [Understanding WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/)

### Testing Tools
- **Accessibility Inspector** (Xcode → Developer Tools)
- **VoiceOver Utility** (Applications → Utilities)
- **Color Contrast Analyzer** (Third-party tool)

---

**Last Updated**: December 12, 2025  
**WCAG Conformance Level**: AA  
**Verified Compatible With**: VoiceOver, Zoom, Switch Control, Voice Control, Keyboard Navigation
