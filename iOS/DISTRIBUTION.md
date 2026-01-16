# Weather Fast iOS - Distribution Guide

This guide explains how to prepare and distribute the Weather Fast iOS application.

## Prerequisites

- **Xcode 15.0 or later** installed
- **Apple Developer Account** (required for App Store distribution)
- **Mac** with macOS Sonoma or later
- **iOS device or simulator** for testing

## Build Configurations

### Debug Build (Development)
```bash
cd iOS
./build.sh
```

Or using xcodebuild directly:
```bash
xcodebuild -project FastWeather.xcodeproj \
    -scheme FastWeather \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
    build
```

### Release Build (Distribution)
```bash
xcodebuild -project FastWeather.xcodeproj \
    -scheme FastWeather \
    -configuration Release \
    -sdk iphoneos \
    archive \
    -archivePath ./build/FastWeather.xcarchive
```

## App Store Distribution

### 1. Update App Information

Edit `Info.plist` to update:
- `CFBundleVersion` - Build number (increment for each submission)
- `CFBundleShortVersionString` - Version number (e.g., "1.0.0")

### 2. Configure Code Signing

In Xcode:
1. Select the FastWeather project
2. Select the FastWeather target
3. Go to "Signing & Capabilities"
4. Check "Automatically manage signing"
5. Select your Team
6. Xcode will generate provisioning profiles

For manual signing:
1. Create an App ID in the Apple Developer Portal
2. Create Distribution Certificate
3. Create App Store Provisioning Profile
4. Configure in Xcode under "Signing & Capabilities"

### 3. Archive the App

Using Xcode:
1. Select "Any iOS Device" as the destination
2. Product > Archive
3. Wait for the archive to complete

Using command line:
```bash
xcodebuild -project FastWeather.xcodeproj \
    -scheme FastWeather \
    -configuration Release \
    -destination generic/platform=iOS \
    archive \
    -archivePath ./build/FastWeather.xcarchive
```

### 4. Prepare for Upload

In Xcode Organizer (Window > Organizer):
1. Select the archive
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Follow the wizard
5. Upload to App Store Connect

Using command line:
```bash
xcodebuild -exportArchive \
    -archivePath ./build/FastWeather.xcarchive \
    -exportPath ./build/FastWeather \
    -exportOptionsPlist ExportOptions.plist
```

### 5. App Store Connect Setup

1. Create a new app in [App Store Connect](https://appstoreconnect.apple.com)
2. Fill in app information:
   - **Name**: Weather Fast
   - **Bundle ID**: com.weatherfast.app (or your chosen ID)
   - **SKU**: Unique identifier
   - **Primary Language**: English

3. Prepare app metadata:
   - Description
   - Keywords
   - Screenshots (required sizes)
   - App Icon
   - Privacy Policy URL
   - Support URL

4. Upload screenshots for:
   - 6.7" iPhone (iPhone 15 Pro Max)
   - 6.5" iPhone (iPhone 11 Pro Max)
   - 5.5" iPhone (iPhone 8 Plus)
   - 12.9" iPad Pro

5. Submit for review

## TestFlight Distribution

### Internal Testing

1. Archive your app (see above)
2. In Organizer, select "Distribute App"
3. Choose "App Store Connect"
4. Upload the build
5. In App Store Connect:
   - Go to TestFlight tab
   - Select the build
   - Add internal testers
   - Testers receive email to install TestFlight

### External Testing

1. Complete internal testing
2. In App Store Connect TestFlight:
   - Create external test group
   - Add external testers
   - Provide test information
   - Submit for beta review
3. Once approved, testers can install

## Ad Hoc Distribution

For distribution to specific devices:

1. Register device UDIDs in Apple Developer Portal
2. Create Ad Hoc Provisioning Profile
3. Archive the app
4. Export with Ad Hoc distribution
5. Distribute .ipa file to testers
6. Install via Xcode, Apple Configurator, or direct install

## Enterprise Distribution

If you have an Apple Enterprise Developer account:

1. Create Enterprise Distribution Certificate
2. Create In-House Provisioning Profile
3. Archive the app
4. Export for Enterprise Distribution
5. Host on internal server or MDM solution
6. Distribute installation manifest

## Updating the App

### Version Updates

1. Increment `CFBundleShortVersionString` in Info.plist (e.g., 1.0.0 → 1.1.0)
2. Increment `CFBundleVersion` (e.g., 1 → 2)
3. Follow App Store distribution steps
4. In App Store Connect, create new version
5. Upload new build
6. Submit for review

### Bug Fix Updates

1. Keep `CFBundleShortVersionString` the same (e.g., 1.0.0)
2. Increment `CFBundleVersion` (e.g., 1 → 2)
3. Follow distribution steps
4. Submit as update

## Pre-Submission Checklist

- [ ] All features tested on physical device
- [ ] No build warnings or errors
- [ ] Accessibility tested with VoiceOver
- [ ] Dark mode tested
- [ ] All orientations tested (if supported)
- [ ] Memory leaks checked with Instruments
- [ ] App icon set (all required sizes)
- [ ] Launch screen configured
- [ ] Privacy Policy created and linked
- [ ] Support URL provided
- [ ] App Store screenshots prepared
- [ ] App description written
- [ ] Keywords selected
- [ ] Age rating selected
- [ ] Export compliance documented

## App Store Review Guidelines

Ensure compliance with:
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- No private API usage
- No misleading functionality
- Appropriate age rating
- Privacy policy if collecting data
- Proper error handling
- No crashes

## Code Signing Troubleshooting

### Common Issues

**"No signing certificate found"**
- Go to Xcode > Preferences > Accounts
- Add your Apple ID
- Download certificates

**"Provisioning profile doesn't match"**
- Enable "Automatically manage signing"
- Or create new provisioning profile in Developer Portal

**"Code signing error"**
- Clean build folder (Cmd+Shift+K)
- Restart Xcode
- Check certificate validity in Keychain Access

## Privacy and Permissions

This app requires:
- **Internet Access** - For weather data API calls
- No location services
- No camera/microphone
- No photo library access
- No contacts access

Privacy manifest (PrivacyInfo.xcprivacy) should declare:
- API usage for weather data
- No data collection
- No tracking

## Required Assets

### App Icon
Create app icons for all required sizes in Assets.xcassets:
- 1024x1024 (App Store)
- 180x180 (iPhone 3x)
- 120x120 (iPhone 2x)
- 167x167 (iPad Pro)
- 152x152 (iPad 2x)
- 76x76 (iPad 1x)

### Screenshots
Required screenshot sizes:
- 6.7" Display (1290 x 2796 pixels)
- 6.5" Display (1242 x 2688 pixels)
- 5.5" Display (1242 x 2208 pixels)
- 12.9" iPad Pro (2048 x 2732 pixels)

## Support

For distribution issues:
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)

## Version History

### 1.0.0 (Build 1)
- Initial release
- City browsing by state and country
- Three view modes (Flat, Table, List)
- Full accessibility support
- Weather data from Open-Meteo API
