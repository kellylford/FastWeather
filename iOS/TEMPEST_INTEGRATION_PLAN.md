# Tempest Personal Weather Station Integration Plan

**Status**: Future Feature / Not Implemented  
**Platform**: iOS only (initially)  
**Last Updated**: February 6, 2026

## Overview

Add support for displaying real-time data from a user's Tempest Weather Station alongside Open-Meteo forecasts. Users configure their station once in Settings (Personal Access Token + Station ID), then see current conditions from their actual hardware sensor displayed in a dedicated "Personal Weather" section in CityDetailView.

**Integration Approach**: Supplement Open-Meteo data (show both side-by-side) rather than replacing it. This allows comparison between hyperlocal sensor data and regional forecasts.

## Background Research

### Tempest API Information

**Official Documentation**: https://weatherflow.github.io/Tempest/api/

**Authentication**: Requires Personal Access Token (PAT)
- Users generate tokens at: https://tempestwx.com/settings → Data Authorizations → Create Token
- Token must be stored securely in iOS Keychain (NOT UserDefaults)
- Alternative: OAuth 2.0 (more complex, designed for multi-user apps)

**Key API Endpoints**:
```
GET https://swd.weatherflow.com/swd/rest/stations?token=[PAT]
→ Returns list of user's stations with metadata

GET https://swd.weatherflow.com/swd/rest/observations/station/[station_id]?token=[PAT]
→ Returns latest observation from specified station
```

**WebSocket Alternative** (future enhancement):
```
wss://ws.weatherflow.com/swd/data?token=[PAT]
→ Real-time updates every minute (not needed for v1)
```

**Data Available from Tempest Sensors**:
- Air temperature (°C)
- Relative humidity (%)
- Station/sea level pressure (MB)
- Wind speed/direction (m/s, degrees)
- Wind gusts
- Rain accumulation (mm)
- UV index
- Solar radiation (W/m²)
- Lightning strikes
- Timestamp of observation

### Current FastWeather Architecture

**Findings from Codebase Analysis**:
- ❌ No existing Tempest/WeatherFlow integration
- ❌ No API abstraction layer (hardcoded to Open-Meteo)
- ❌ No plugin/provider architecture
- ❌ No settings for custom endpoints or API keys
- ✅ Secure storage pattern exists (can extend with Keychain)
- ✅ Settings system can handle new configuration fields
- ✅ Service layer pattern (WeatherService) can be replicated for TempestWeatherService

**Current API Integration**:
- Single provider: Open-Meteo API (no authentication required)
- Direct HTTP requests in `WeatherService.swift`
- No multi-provider support

## Design Decisions

### Scope
- **Platform**: iOS only for v1 (can extend to macOS later - share Swift code)
- **Authentication**: Personal Access Token (simpler than OAuth for single-user)
- **Station Limit**: Single station only (simplifies UX)
- **Integration Style**: Dedicated section (not mixed with Open-Meteo data)
- **Security**: Keychain storage for PAT (industry standard)

### User Experience
1. **Setup Flow**:
   - Settings → "Personal Weather Station (Advanced)"
   - Paste Personal Access Token
   - Tap "Fetch My Stations"
   - Select station from picker
   - Enable/disable toggle

2. **Display Location**:
   - New section in CityDetailView: "Personal Weather Station"
   - Appears between Marine Forecast and Location sections
   - Shows current conditions from user's sensor
   - Includes timestamp: "Updated X minutes ago"

3. **Data Presentation**:
   - Clearly labeled as from "My Tempest Station"
   - Formatted with user's unit preferences (F/C, mph/kmh, etc.)
   - Separate from Open-Meteo forecast data (no mixing)
   - Shows when station is offline or data is stale (>10 min)

### Technical Architecture

**New Components Needed**:
1. `TempestWeatherService.swift` - API client
2. `KeychainManager.swift` - Secure token storage
3. `PersonalWeatherSection.swift` - UI component
4. Settings model extensions - Store station ID/name
5. Settings UI additions - Configuration interface

**Data Flow**:
```
User → Settings → Paste PAT → Keychain
User → Settings → Fetch Stations → TempestWeatherService
User → Settings → Select Station → Settings.tempestStationId
App Launch → Load PAT from Keychain → TempestWeatherService
City Detail View → Fetch Latest Observation → Display PersonalWeatherSection
```

## Implementation Plan

### Step 1: Tempest API Client Service
**File**: `iOS/FastWeather/Services/TempestWeatherService.swift`

**Class**: `TempestWeatherService: ObservableObject`

**Methods**:
```swift
func fetchStations(token: String) async throws -> [TempestStation]
func fetchLatestObservation(stationId: String, token: String) async throws -> TempestObservation
```

**Models**:
```swift
struct TempestStation: Codable, Identifiable {
    let stationId: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let devices: [Device]
}

struct TempestObservation: Codable {
    let timestamp: Date
    let airTemperature: Double          // °C
    let relativeHumidity: Double        // %
    let stationPressure: Double         // MB
    let seaLevelPressure: Double        // MB
    let windAvg: Double                 // m/s
    let windDirection: Double           // degrees
    let windGust: Double                // m/s
    let rainAccumulated: Double         // mm
    let uv: Double                      // index
    let solarRadiation: Double          // W/m²
}
```

**Error Handling**:
- Invalid token (401) → Clear error message in Settings
- Station offline → Show cached data with "offline" indicator
- Network failure → Use cached data if available
- Rate limiting → Respect API limits (cache responses)

**Caching Strategy**:
- Store latest observation with timestamp
- Refresh on pull-to-refresh or every 5 minutes
- Consider stale after 10 minutes (show warning)

---

### Step 2: Secure Credential Storage
**File**: `iOS/FastWeather/Services/KeychainManager.swift`

**Static Methods**:
```swift
static func saveTempestToken(_ token: String) throws
static func getTempestToken() -> String?
static func deleteTempestToken() throws
```

**Keychain Configuration**:
- Service: `com.fastweather.tempest`
- Account: `personalAccessToken`
- Accessibility: `kSecAttrAccessibleWhenUnlocked`

**Security Framework APIs**:
- `SecItemAdd` - Store token
- `SecItemCopyMatching` - Retrieve token
- `SecItemDelete` - Remove token

**Important**: NEVER store Personal Access Token in:
- UserDefaults
- Settings.swift codable struct
- Plaintext files
- App bundle

---

### Step 3: Settings Model Extensions
**File**: `iOS/FastWeather/Models/Settings.swift`

**Add Properties**:
```swift
struct Settings: Codable {
    // ... existing properties
    
    // Tempest Personal Weather Station
    var tempestEnabled: Bool = false
    var tempestStationId: String? = nil
    var tempestStationName: String? = nil
}
```

**Persistence**:
- Station ID/name/enabled → UserDefaults (via Settings)
- Personal Access Token → Keychain (via KeychainManager)

**Update Methods**:
- Add to `init()` defaults
- Add to `CodingKeys` enum
- Update `resetToDefaults()` to include Tempest settings

---

### Step 4: Settings UI
**File**: `iOS/FastWeather/Views/SettingsView.swift`

**Add Section** (after "About", before "Developer Settings"):
```swift
Section(header: Text("Personal Weather Station (Advanced)")) {
    Toggle("Enable Tempest Integration", isOn: $settingsManager.settings.tempestEnabled)
        .onChange(of: settingsManager.settings.tempestEnabled) {
            settingsManager.saveSettings()
        }
    
    if settingsManager.settings.tempestEnabled {
        SecureField("Personal Access Token", text: $tempestToken)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        
        Button("Fetch My Stations") {
            Task {
                await fetchTempestStations()
            }
        }
        .disabled(tempestToken.isEmpty)
        
        if !tempestStations.isEmpty {
            Picker("Station", selection: $selectedStationId) {
                ForEach(tempestStations) { station in
                    Text(station.name).tag(station.stationId)
                }
            }
            .onChange(of: selectedStationId) { oldValue, newValue in
                if let station = tempestStations.first(where: { $0.stationId == newValue }) {
                    settingsManager.settings.tempestStationId = "\(station.stationId)"
                    settingsManager.settings.tempestStationName = station.name
                    settingsManager.saveSettings()
                    try? KeychainManager.saveTempestToken(tempestToken)
                }
            }
        }
        
        if let stationName = settingsManager.settings.tempestStationName {
            Text("Selected: \(stationName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        Button("Clear Tempest Configuration", role: .destructive) {
            settingsManager.settings.tempestEnabled = false
            settingsManager.settings.tempestStationId = nil
            settingsManager.settings.tempestStationName = nil
            tempestToken = ""
            try? KeychainManager.deleteTempestToken()
            settingsManager.saveSettings()
        }
    }
}
```

**Help Text**:
```swift
.footer(Text("Generate a Personal Access Token at tempestwx.com → Settings → Data Authorizations → Create Token. This allows FastWeather to display real-time data from your Tempest weather station."))
```

**Accessibility**:
- Add `.accessibilityLabel()` for all controls
- Add `.accessibilityHint()` for token field and buttons
- Test with VoiceOver navigation

---

### Step 5: Personal Weather Display Component
**File**: `iOS/FastWeather/Views/PersonalWeatherSection.swift`

**Structure**:
```swift
struct PersonalWeatherSection: View {
    let observation: TempestObservation
    let stationName: String
    
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        GroupBox(label: Label("My Tempest Station", systemImage: "antenna.radiowaves.left.and.right")) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with station name and timestamp
                HStack {
                    Text(stationName)
                        .font(.headline)
                    Spacer()
                    Text("Updated \(timeAgo(observation.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Current conditions grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    PersonalWeatherDataRow(
                        label: "Temperature",
                        value: formatTemperature(observation.airTemperature),
                        icon: "thermometer"
                    )
                    PersonalWeatherDataRow(
                        label: "Humidity",
                        value: "\(Int(observation.relativeHumidity))%",
                        icon: "humidity"
                    )
                    PersonalWeatherDataRow(
                        label: "Pressure",
                        value: formatPressure(observation.seaLevelPressure),
                        icon: "barometer"
                    )
                    PersonalWeatherDataRow(
                        label: "Wind",
                        value: formatWind(observation.windAvg, observation.windDirection),
                        icon: "wind"
                    )
                    if observation.rainAccumulated > 0 {
                        PersonalWeatherDataRow(
                            label: "Rain Today",
                            value: formatRain(observation.rainAccumulated),
                            icon: "cloud.rain"
                        )
                    }
                    if observation.uv > 0 {
                        PersonalWeatherDataRow(
                            label: "UV Index",
                            value: "\(Int(observation.uv))",
                            icon: "sun.max"
                        )
                    }
                }
                
                // Data source footer
                Text("Data from my personal weather station")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
    
    // Helper formatting methods
    private func formatTemperature(_ celsius: Double) -> String {
        // Use SettingsManager.settings.temperatureUnit
    }
    
    private func formatPressure(_ mb: Double) -> String {
        // Convert to user's pressure unit (inHg, mb, hPa)
    }
    
    private func formatWind(_ speed: Double, _ direction: Double) -> String {
        // Convert m/s to user's wind speed unit + cardinal direction
    }
    
    private func timeAgo(_ date: Date) -> String {
        // "2 min ago", "5 hours ago", etc.
    }
}
```

**States to Handle**:
- Loading: Show ProgressView
- Loaded: Display data
- Stale (>10 min): Show warning icon/text
- Offline: "Station offline - last updated X hours ago"
- Error: "Unable to load station data"

**Accessibility**:
- `.accessibilityElement(children: .ignore)` + custom label for each data row
- Combine values: "Temperature, 72 degrees Fahrenheit"
- Announce timestamp in VoiceOver-friendly format

---

### Step 6: Integrate into CityDetailView
**File**: `iOS/FastWeather/Views/CityDetailView.swift`

**Add Environment Object**:
```swift
@EnvironmentObject var tempestService: TempestWeatherService
```

**Add State**:
```swift
@State private var tempestObservation: TempestObservation?
@State private var tempestLoading = false
@State private var tempestError: String?
```

**Display Logic** (add after Marine Forecast, before Location):
```swift
// Personal Weather Station (if configured)
if settingsManager.settings.tempestEnabled,
   let stationId = settingsManager.settings.tempestStationId,
   let stationName = settingsManager.settings.tempestStationName {
    
    if tempestLoading {
        GroupBox(label: Label("My Tempest Station", systemImage: "antenna.radiowaves.left.and.right")) {
            ProgressView("Loading station data...")
                .frame(minHeight: 100)
                .padding()
        }
        .padding(.horizontal)
    } else if let observation = tempestObservation {
        PersonalWeatherSection(observation: observation, stationName: stationName)
    } else if let error = tempestError {
        GroupBox(label: Label("My Tempest Station", systemImage: "antenna.radiowaves.left.and.right")) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 100)
            .padding()
        }
        .padding(.horizontal)
    }
}
```

**Fetch on Load**:
```swift
.task(id: "\(city.id)-\(dateOffset)") {
    // ... existing weather fetch
    
    if settingsManager.settings.tempestEnabled,
       let stationId = settingsManager.settings.tempestStationId,
       let token = KeychainManager.getTempestToken() {
        tempestLoading = true
        do {
            tempestObservation = try await tempestService.fetchLatestObservation(
                stationId: stationId,
                token: token
            )
            tempestError = nil
        } catch {
            tempestError = "Unable to load station data"
        }
        tempestLoading = false
    }
}
```

---

### Step 7: App Initialization
**File**: `iOS/FastWeather/FastWeatherApp.swift`

**Add State Object**:
```swift
@StateObject private var tempestService = TempestWeatherService()
```

**Add to Environment**:
```swift
ContentView()
    .environmentObject(weatherService)
    .environmentObject(settingsManager)
    .environmentObject(tempestService)  // Add this
```

**Optional**: Pre-fetch on launch if configured (not critical for v1)

---

### Step 8: Unit Conversion Helpers
**File**: Extension in `TempestWeatherService.swift` or create `TempestDataFormatters.swift`

**Convert Tempest Data to User Preferences**:
```swift
extension TempestObservation {
    func temperature(in unit: TemperatureUnit) -> Double {
        // Tempest returns Celsius
        switch unit {
        case .celsius:
            return airTemperature
        case .fahrenheit:
            return airTemperature * 9/5 + 32
        }
    }
    
    func windSpeed(in unit: WindSpeedUnit) -> Double {
        // Tempest returns m/s
        let kmh = windAvg * 3.6
        switch unit {
        case .kmh:
            return kmh
        case .mph:
            return kmh * 0.621371
        }
    }
    
    func pressure(in unit: PressureUnit) -> Double {
        // Tempest returns MB
        switch unit {
        case .mb, .hPa:
            return seaLevelPressure
        case .inHg:
            return seaLevelPressure * 0.02953
        }
    }
    
    func precipitation(in unit: PrecipitationUnit) -> Double {
        // Tempest returns mm
        switch unit {
        case .mm:
            return rainAccumulated
        case .inches:
            return rainAccumulated * 0.0393701
        }
    }
}
```

**Reuse Existing Helpers**:
- Cardinal direction conversion (already exists in CityDetailView)
- Time ago formatting (can extract from existing code)
- Unit preference access via SettingsManager

---

## Testing Plan

### Setup Prerequisites
1. Own a Tempest Weather Station
2. Generate Personal Access Token:
   - Go to https://tempestwx.com/settings
   - Navigate to Data Authorizations
   - Click "Create Token"
   - Copy token to clipboard
3. Note your Station ID (visible in Tempest app)

### Test Cases

**1. Initial Setup**
- [ ] Open Settings → Personal Weather Station section appears
- [ ] Toggle "Enable Tempest Integration" → fields appear
- [ ] Paste invalid token → "Fetch My Stations" shows error
- [ ] Paste valid token → "Fetch My Stations" succeeds
- [ ] Station picker shows correct station names
- [ ] Select station → name appears in "Selected: ..." text

**2. Data Display**
- [ ] Navigate to any City Detail view
- [ ] "My Tempest Station" section appears before Location
- [ ] Temperature matches Tempest app/website
- [ ] Humidity matches Tempest app/website
- [ ] Wind speed/direction matches Tempest app/website
- [ ] Pressure matches Tempest app/website
- [ ] Timestamp shows recent time ("Updated 2 min ago")
- [ ] Units match Settings preferences (F/C, mph/kmh, etc.)

**3. Refresh & Persistence**
- [ ] Pull to refresh → timestamp updates
- [ ] Force quit app → relaunch → Tempest data still loads
- [ ] Token persists in Keychain (not lost on restart)
- [ ] Station selection persists in Settings

**4. Toggle On/Off**
- [ ] Settings → Toggle OFF → section disappears from City Detail
- [ ] Toggle back ON (without reconfiguring) → section reappears
- [ ] Data loads from cached token

**5. Error Handling**
- [ ] Invalid token → Settings shows clear error message
- [ ] Network offline → Shows cached data OR "Unable to load"
- [ ] Station offline (>10 min since update) → Shows warning
- [ ] "Clear Tempest Configuration" → Removes all data, clears token

**6. Accessibility (VoiceOver)**
- [ ] Navigate to Settings → Tempest section announced correctly
- [ ] Token field labeled as "secure text field"
- [ ] "Fetch My Stations" button purpose clear
- [ ] Station picker announces selected station
- [ ] City Detail → "My Tempest Station" heading announced
- [ ] Each data row (temp, humidity, etc.) announced with label + value
- [ ] Timestamp announced in natural language

**7. Edge Cases**
- [ ] No rain today → Rain row doesn't appear
- [ ] UV index = 0 → UV row doesn't appear
- [ ] Multiple cities → Tempest section appears in all (same station data)
- [ ] Change station in Settings → City Detail updates on next refresh
- [ ] Token expires → Clear error in Settings, prompt to regenerate

---

## Future Enhancements

### Phase 2 Improvements
1. **WebSocket Integration**
   - Real-time updates every minute (vs polling on refresh)
   - Live weather ticker in app
   - Push notifications for significant changes (e.g., rain starts)

2. **Multiple Station Support**
   - Allow users to configure multiple Tempest stations
   - Per-city station assignment (match closest station to city location)
   - Station picker in City Detail view

3. **Historical Data from Tempest**
   - Fetch past observations (Tempest API supports this)
   - Compare personal history vs Open-Meteo historical data
   - Graph view of station data over time

4. **macOS Support**
   - Port TempestWeatherService to macOS (90% code reuse)
   - Shared Settings sync via iCloud (if implemented)
   - Keychain sharing between iOS/macOS

5. **Advanced Features**
   - Lightning strike detection alerts
   - Haptic rain start (Tempest detects first drops)
   - Solar radiation graph (for solar panel owners)
   - Barometric pressure trend analysis

6. **Web/Python Integration**
   - Requires separate API client implementations
   - Web: JavaScript fetch API, localStorage for token (not as secure)
   - Python: requests library, encrypted credential storage

### Alternative Station Integrations
If this works well, consider supporting other personal weather station APIs:
- **Ambient Weather** (similar REST API)
- **Davis WeatherLink** (requires separate API key)
- **Netatmo** (OAuth 2.0, more complex)
- **CWOP/APRS** (public data, no authentication)

---

## Security Considerations

### Token Storage
✅ **DO**:
- Store Personal Access Token in iOS Keychain
- Use `kSecAttrAccessibleWhenUnlocked` accessibility level
- Clear token on "Clear Configuration" action
- Validate token format before saving

❌ **DON'T**:
- Store token in UserDefaults (plaintext)
- Log token to console (even in debug builds)
- Include token in error messages
- Transmit token over insecure connections

### API Communication
- Always use HTTPS (Tempest API enforces this)
- Handle 401 Unauthorized gracefully (expired/invalid token)
- Rate limit requests (respect Tempest API limits)
- Cache responses to minimize API calls

### User Privacy
- Only fetch data for user's own station (PAT scopes this automatically)
- Don't share station data with third parties
- Don't log location data from station
- Respect user's delete request (clear all data + token)

---

## Known Limitations

1. **Single Platform**: iOS only for v1 (macOS/Web/Python require separate work)
2. **Single Station**: Cannot configure multiple stations or assign different stations per city
3. **Polling Only**: No real-time WebSocket updates (refresh required)
4. **Current Conditions Only**: No historical data from Tempest (only latest observation)
5. **No Forecasting**: Tempest provides observations, not forecasts (still need Open-Meteo)
6. **Station Proximity**: Shows same station data for all cities (doesn't match closest station)
7. **Offline Handling**: Limited offline mode (requires network for first fetch)

---

## API Rate Limits & Best Practices

**Tempest API Limits** (from documentation):
- No explicit rate limit published
- Recommended: Cache responses, avoid polling faster than 1 min
- WebSocket preferred for real-time updates (v2 feature)

**FastWeather Strategy**:
- Cache latest observation with 5-minute TTL
- Refresh only on:
  - User-initiated pull-to-refresh
  - App foreground return (if cache expired)
  - Manual refresh button (if added)
- Show cached data with timestamp if network fails

---

## Resources

### Official Documentation
- Tempest API Docs: https://weatherflow.github.io/Tempest/api/
- REST API Reference: https://weatherflow.github.io/Tempest/api/swagger/
- WebSocket Reference: https://weatherflow.github.io/Tempest/api/ws.html
- OAuth 2.0 Guide: https://weatherflow.github.io/Tempest/api/oauth.html

### Community
- Tempest Developers Forum: https://community.weatherflow.com/c/developers/5
- Third-Party Apps List: https://community.weatherflow.com/t/tempest-weather-system-third-party-applications/873

### Apple Developer
- Keychain Services: https://developer.apple.com/documentation/security/keychain_services
- URLSession: https://developer.apple.com/documentation/foundation/urlsession
- SwiftUI Environment Objects: https://developer.apple.com/documentation/swiftui/environmentobject

---

## Questions & Answers

**Q: Why not use the public station page URL instead of API?**  
A: The public webpage (e.g., tempestwx.com/station/12345) is HTML for humans, not a JSON API. Would require scraping which is fragile and violates Tempest's terms. The REST API is designed for this use case and requires minimal setup (just a PAT).

**Q: Can users access stations they don't own?**  
A: No. Personal Access Tokens scope permissions to the authenticated user's stations only. This is a security feature.

**Q: What if user doesn't want to share their token?**  
A: Feature is optional (disabled by default). Users who don't want to provide a token simply don't enable Tempest integration. All existing functionality works without it.

**Q: How does this affect battery/data usage?**  
A: Minimal impact. REST API requests are small (~1-2 KB JSON). With 5-minute caching and refresh-only-on-demand, typical usage = 1-2 requests per app session. WebSocket (future) would use more data for real-time updates.

**Q: What if Tempest changes their API?**  
A: Monitor Tempest API release notes (https://weatherflow.github.io/Tempest/releases/). API is stable (in production since 2020). Breaking changes are rare and announced in advance. Service layer abstraction makes updates easier.

**Q: Will this work with the older WeatherFlow Smart Weather Station?**  
A: Likely yes - same API, different device type. Would need testing to confirm data formats match. The API supports both Tempest and legacy AIR/SKY devices.

---

## Decision Log

**Date**: February 6, 2026

1. **iOS-only for v1**: Faster iteration, proven Swift patterns, can extend later
2. **Personal Access Token over OAuth**: Simpler UX for personal use case (Tempest's recommendation)
3. **Keychain storage**: Industry standard for sensitive credentials on iOS
4. **Single station limit**: Simplified UX, covers 95% of use cases
5. **Separate section in detail view**: Clear data source attribution, no confusion with forecasts
6. **Supplement vs replace**: Show both Tempest + Open-Meteo for comparison
7. **REST polling for v1**: Simpler than WebSocket, sufficient for refresh-on-demand
8. **Display before Location section**: Logical flow (forecasts → actual sensor data → metadata)

---

## Contact & Support

**For Tempest API Questions**:
- Community Forum: https://community.weatherflow.com/c/developers/5
- Email Support: https://weatherflow.com/partner-inquiry/

**For FastWeather Implementation**:
- See main project README.md
- Accessibility requirements: iOS/ACCESSIBILITY.md
- Architecture notes: iOS/ARCHITECTURE.md (once created)
