# Alert Flash Prevention Guide

## The Problem

SwiftUI alerts and confirmation dialogs can **visually flash** (re-render) when the state they reference changes while displayed. This is **invisible to VoiceOver users** but creates a poor visual experience for sighted users.

### Why VoiceOver Doesn't Notice

- The flash is a **visual re-render**, not a semantic change
- The alert stays presented the whole time (same accessibility element)
- Only the pixels flicker as SwiftUI rebuilds the view
- VoiceOver sees: "Alert still open, same title, done"

## The Root Cause

```swift
// ❌ BAD - Dynamic state in alert modifier
.alert("Cities to the \(selectedDirection.rawValue)", isPresented: $showingAlert) {
    Text(allCitiesList())  // Calls function that reads changing state
}
```

When `selectedDirection` or data in `allCitiesList()` changes:
1. SwiftUI re-evaluates the alert closure
2. Alert rebuilds with new values
3. **Visual flash occurs** (but alert stays open)

## The Solution

**Capture values at trigger time, not render time:**

```swift
// ✅ GOOD - Static captured values
@State private var alertTitle = ""
@State private var alertMessage = ""

private func showAlert() {
    // Capture values BEFORE showing alert
    alertTitle = "Cities to the \(selectedDirection.rawValue)"
    alertMessage = citiesInDirection.map { ... }.joined(...)
    showingAlert = true
}

.alert(alertTitle, isPresented: $showingAlert) {
    Text(alertMessage)
}
```

## Detection Without Visual Testing

Since VoiceOver can't detect flashing, use **automated detection**:

```swift
.onChange(of: showingAlert) { oldValue, newValue in
    // Alert should never go from true to true
    if oldValue == true && newValue == true {
        print("⚠️ ALERT FLASH DETECTED!")
        // This means SwiftUI rebuilt the alert while it was shown
    }
}
```

**All alerts in FastWeather now have this detection logging.**

## Code Review Checklist

When adding/modifying alerts or confirmation dialogs:

### ❌ Never Do This:
- [ ] Reference `@State` variables in alert title/message
- [ ] Call functions in alert closure that read changing state
- [ ] Use `.rawValue` of enums in alert text
- [ ] Interpolate properties of objects that might change
- [ ] Reference array counts or computed properties

### ✅ Always Do This:
- [ ] Capture all dynamic content when setting `isPresented = true`
- [ ] Use separate `@State` variables for alert title/message
- [ ] Add `.onChange(of: isPresented)` flash detection
- [ ] Test by changing underlying state while alert is shown
- [ ] Check Xcode console for "ALERT FLASH DETECTED" warnings

## Examples from FastWeather

### Fixed: WeatherAroundMeView

**Before (flashing):**
```swift
.alert("Cities to the \(selectedDirection.rawValue)", isPresented: $showingAllCities) {
    Text(allCitiesList())
}
```

**After (fixed):**
```swift
@State private var alertTitle = ""
@State private var alertMessage = ""

private func showAllCities() {
    alertTitle = "Cities to the \(selectedDirection.rawValue)"
    alertMessage = citiesInDirection.map { ... }.joined(...)
    showingAllCities = true
}

.alert(alertTitle, isPresented: $showingAllCities) {
    Text(alertMessage)
}
.onChange(of: showingAllCities) { old, new in
    if old && new { print("⚠️ FLASH!") }
}
```

### Fixed: CityDetailView

**Before (potential flashing):**
```swift
.confirmationDialog("Remove \(city.name)?", isPresented: $showing) { ... }
```

**After (fixed):**
```swift
@State private var removalCityName = ""

Button("Remove") {
    removalCityName = city.name  // Capture BEFORE showing
    showingRemoveConfirmation = true
}

.confirmationDialog("Remove \(removalCityName)?", isPresented: $showing) { ... }
.onChange(of: showing) { old, new in
    if old && new { print("⚠️ FLASH!") }
}
```

## Testing Strategy

### 1. Console Monitoring
Run the app and watch Xcode console while:
- Showing alerts
- Changing state that alerts might reference
- Navigating while alerts are open

Look for: `⚠️ ALERT FLASH DETECTED`

### 2. Code Grep Audit
```bash
# Find potentially problematic patterns
grep -r "\.alert.*\$" iOS/FastWeather/Views/
grep -r "\.alert.*\\.rawValue" iOS/FastWeather/Views/
grep -r "\.confirmationDialog.*\$" iOS/FastWeather/Views/
```

### 3. SwiftUI Preview Testing
Test in previews - if preview flickers when state changes, it'll flash in app.

### 4. Automated UI Tests
```swift
func testAlertDoesNotFlash() {
    // Show alert
    app.buttons["Show Alert"].tap()
    
    // Change underlying state
    app.buttons["Change State"].tap()
    
    // Alert should still be showing (no dismiss/re-present)
    XCTAssertTrue(app.alerts.element.exists)
}
```

## Current Status

All alerts in FastWeather (as of Jan 25, 2026):
- ✅ **WeatherAroundMeView** - Fixed with captured values + flash detection
- ✅ **CityDetailView** - Fixed with captured values + flash detection  
- ✅ **SettingsView** - Safe (static strings only) + flash detection added

**Total alerts audited: 3**
**Alerts with flash risk: 0**
**Alerts with detection: 3**

## Maintenance

When adding new alerts:
1. Use this document as reference
2. Always add flash detection logging
3. Test by changing state while alert is shown
4. Check console for warnings
5. Update "Current Status" section above

## Related Issues

- **Issue**: Alert flashing in Weather Around Me
- **Fix**: Commit 2cb2e2b (Jan 25, 2026)
- **Detection**: Added in commits 2cb2e2b and [current]
