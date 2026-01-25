# TestApp - VoiceOver Accessibility Testing

## Purpose

This is a minimal test application created to experiment with Mac Catalyst VoiceOver accessibility improvements before applying them to the main FastWeather app.

## Mac Catalyst VoiceOver Issues Being Investigated

1. **Tab Navigation Order**: Tab row appears before content in VoiceOver navigation
2. **Explore by Touch**: Trackpad hover doesn't read content when hovering over elements
3. **Tab Announcements**: Tabs not announced as "Tabs" by VoiceOver

## Structure

The app replicates FastWeather's basic structure:
- **TabView** with 3 tabs (Home, Lists, Settings)
- **HomeView**: Counter with buttons and toggle
- **ListsView**: Simple List of items
- **SettingsView**: Form with text input and picker

## Testing Approach

1. Build and run on Mac Catalyst (My Mac - Designed for iPad)
2. Enable VoiceOver (Cmd+F5)
3. Test baseline behavior - should exhibit same issues as FastWeather
4. Experiment with accessibility modifiers:
   - `.accessibilityAddTraits(.isTab)` on TabView items
   - `.accessibilitySortPriority()` for navigation order
   - `.accessibilityLabel()` for Explore by Touch
   - `.accessibilityElement(children: .combine)` on complex views
5. Once fixes proven, apply to FastWeather

## Building

```bash
cd /Users/kellyford/Documents/GitHub/FastWeather/iOS/TestApp
open TestApp.xcodeproj

# Or from command line:
xcodebuild -project TestApp.xcodeproj -scheme TestApp -destination 'platform=macOS,variant=Mac Catalyst' build
```

## Key Settings

- **Mac Catalyst**: Enabled (`SUPPORTS_MACCATALYST = YES`)
- **iOS Deployment Target**: 17.0
- **Bundle ID**: com.test.testapp
- **Version**: 1.0 (build 1)

## Accessibility Modifiers to Test

### Tab Navigation Order
```swift
.accessibilitySortPriority(1) // Higher priority = read first
```

### Tab Trait Announcement
```swift
.accessibilityAddTraits(.isTab)
```

### Explore by Touch Labels
```swift
.accessibilityLabel("Detailed description")
.accessibilityElement(children: .ignore) // Prevent combining with visual text
```

### Complex View Grouping
```swift
.accessibilityElement(children: .combine)
```

## Notes

- This is NOT part of the production FastWeather app
- Safe space for breaking changes during experimentation
- No weather logic - just UI testing
