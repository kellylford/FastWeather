# Severe Weather Alerts Research & Implementation Options

**Document Date**: January 21, 2026  
**Status**: Research/Future Feature Consideration  
**Scope**: All FastWeather platforms (Python/wxPython, macOS, iOS, Web/PWA)

## Executive Summary

The current Open-Meteo API used across all FastWeather platforms **does not provide severe weather alerts, warnings, or watches**. This document evaluates alternative APIs and implementation strategies for adding official government-issued severe weather alerting capabilities to FastWeather.

---

## Current State: Open-Meteo Limitations

### What Open-Meteo Provides
- ✅ Comprehensive weather forecasts (temperature, precipitation, wind, etc.)
- ✅ WMO weather codes (0-99) for conditions
- ✅ Precipitation probability
- ✅ Extreme weather indicators (high winds, heavy precipitation)
- ✅ Free, no API key required

### What Open-Meteo Does NOT Provide
- ❌ Official severe weather alerts/warnings/watches
- ❌ Tornado warnings
- ❌ Flood warnings
- ❌ Heat advisories
- ❌ Winter storm warnings
- ❌ Any government-issued emergency weather notifications

### Near-Miss Features
Open-Meteo provides **forecasted conditions** but not **alerts**:
- Weather Code 95: Thunderstorm (slight or moderate)
- Weather Code 96/99: Thunderstorm with hail
- High precipitation probability (e.g., 90%+)
- Extreme wind speed values

These are **predictive data**, not official emergency alerts from meteorological agencies.

---

## Alternative Weather Alert APIs

### 🥇 Option 1: National Weather Service (NWS) API (US Only)

**URL**: https://www.weather.gov/documentation/services-web-api

#### Strengths
- ✅ **FREE** (no API key required)
- ✅ **Official US government alerts** (NWS/NOAA)
- ✅ Comprehensive alert types (tornado, severe thunderstorm, flood, heat, winter storm, etc.)
- ✅ JSON format with easy integration
- ✅ Point-based and zone-based queries
- ✅ Perfectly complements Open-Meteo (both free)
- ✅ High reliability and uptime

#### Limitations
- ❌ **United States only** (no coverage for international cities)
- ⚠️ Requires respecting User-Agent requirements
- ⚠️ No commercial use without attribution

#### API Endpoints
```
# Get active alerts for a specific location
GET https://api.weather.gov/alerts/active?point={latitude},{longitude}

# Get all active US alerts
GET https://api.weather.gov/alerts/active

# Get alerts by state
GET https://api.weather.gov/alerts/active?area={state_code}

# Example
GET https://api.weather.gov/alerts/active?point=43.0748,-89.3838
```

#### Sample Response
```json
{
  "features": [
    {
      "properties": {
        "event": "Tornado Warning",
        "severity": "Extreme",
        "certainty": "Observed",
        "urgency": "Immediate",
        "headline": "Tornado Warning issued January 21 at 3:15PM CST",
        "description": "At 315 PM CST, a severe thunderstorm capable of producing a tornado was located...",
        "instruction": "TAKE COVER NOW! Move to a basement or an interior room...",
        "onset": "2026-01-21T15:15:00-06:00",
        "expires": "2026-01-21T15:45:00-06:00",
        "areaDesc": "Madison; Dane County"
      }
    }
  ]
}
```

#### Alert Severity Levels
- **Extreme**: Extraordinary threat to life or property
- **Severe**: Significant threat to life or property
- **Moderate**: Possible threat to life or property
- **Minor**: Minimal threat to life or property
- **Unknown**: Unknown severity

---

### 🥈 Option 2: WeatherAPI.com (Global Coverage)

**URL**: https://www.weatherapi.com/

#### Strengths
- ✅ **Global coverage** (50+ countries)
- ✅ Free tier: 1,000,000 calls/month
- ✅ Weather alerts included in forecast response
- ✅ Similar API structure to Open-Meteo (easy integration)
- ✅ Could potentially replace Open-Meteo entirely

#### Limitations
- ⚠️ Requires API key (free tier available)
- ⚠️ Free tier limits (1M calls/month ≈ 1 call/2.5 seconds continuous)
- 💰 Paid plans after free tier ($4/month for 2M calls)

#### API Example
```
GET https://api.weatherapi.com/v1/forecast.json
  ?key=YOUR_API_KEY
  &q={latitude},{longitude}
  &alerts=yes
```

#### Sample Alert Response
```json
{
  "alerts": {
    "alert": [
      {
        "headline": "Flood Warning issued January 21",
        "msgtype": "Alert",
        "severity": "Moderate",
        "urgency": "Expected",
        "areas": "Madison, WI",
        "category": "Met",
        "certainty": "Likely",
        "event": "Flood Warning",
        "effective": "2026-01-21T06:00:00-06:00",
        "expires": "2026-01-22T18:00:00-06:00",
        "desc": "The National Weather Service in Madison has issued a Flood Warning...",
        "instruction": "Turn around, don't drown..."
      }
    ]
  }
}
```

---

### 🥉 Option 3: Weatherbit.io

**URL**: https://www.weatherbit.io/

#### Strengths
- ✅ Global coverage
- ✅ Severe weather alerts API
- ✅ Active fire alerts
- ✅ Supports 47 languages

#### Limitations
- ⚠️ Free tier: 500 calls/day
- 💰 Paid plans: $0.0005/call (commercial use)
- ⚠️ Less generous free tier than WeatherAPI.com

---

### Option 4: Tomorrow.io (formerly ClimaCell)

**URL**: https://www.tomorrow.io/

#### Strengths
- ✅ Global coverage
- ✅ Predictive severe weather alerts
- ✅ Custom alert rules/thresholds
- ✅ High-resolution forecasts

#### Limitations
- ⚠️ Free tier: 500 calls/day
- 💰 Paid plans: $99/month for commercial use
- ⚠️ More complex API structure

---

### Option 5: MeteoAlarm API (Europe Only)

**URL**: https://meteoalarm.org/

#### Strengths
- ✅ **FREE**
- ✅ Official European weather warnings
- ✅ 30+ European meteorological services
- ✅ Color-coded alert levels (green/yellow/orange/red)

#### Limitations
- ❌ **Europe only**
- ⚠️ XML format (requires parsing)
- ⚠️ Less comprehensive API documentation

---

## Recommended Implementation Strategy

### 🎯 Hybrid Approach: Open-Meteo + Regional Alert APIs

**Rationale**: Maintain current Open-Meteo integration for weather data, add complementary alert APIs for coverage.

```
┌─────────────────────────────────────────────────┐
│         FastWeather Architecture                │
├─────────────────────────────────────────────────┤
│                                                 │
│  Open-Meteo API (Keep Current)                 │
│  └─ Weather forecasts (current, hourly, daily) │
│  └─ All platforms, all locations               │
│                                                 │
│  + NWS API (Add for US alerts)                 │
│  └─ Severe weather alerts (US only)            │
│  └─ FREE, no API key                           │
│                                                 │
│  + MeteoAlarm (Add for Europe alerts)          │
│  └─ Severe weather alerts (Europe only)        │
│  └─ FREE, official warnings                    │
│                                                 │
│  (Optional) WeatherAPI.com (Add for global)    │
│  └─ Alerts for remaining countries             │
│  └─ Free tier: 1M calls/month                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Benefits
- ✅ Maintains current free, no-API-key Open-Meteo integration
- ✅ Adds official government alerts where available (US, Europe)
- ✅ Minimal cost (NWS and MeteoAlarm are free)
- ✅ Graceful degradation (alerts only show where supported)
- ✅ No breaking changes to existing codebase

---

## Implementation Considerations

### 1. Data Model Changes

Add optional `alerts` array to weather response models:

#### Swift (iOS/macOS)
```swift
struct WeatherResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather?
    let daily: DailyWeather?
    let alerts: [WeatherAlert]? // NEW
}

struct WeatherAlert: Codable, Identifiable {
    let id: String
    let event: String           // "Tornado Warning"
    let severity: AlertSeverity // Extreme, Severe, Moderate, Minor
    let headline: String
    let description: String
    let instruction: String?
    let onset: Date
    let expires: Date
    let areas: String?          // Affected areas/counties
}

enum AlertSeverity: String, Codable {
    case extreme = "Extreme"
    case severe = "Severe"
    case moderate = "Moderate"
    case minor = "Minor"
    case unknown = "Unknown"
}
```

#### Python (wxPython Desktop)
```python
@dataclass
class WeatherAlert:
    id: str
    event: str              # "Tornado Warning"
    severity: str           # "Extreme", "Severe", etc.
    headline: str
    description: str
    instruction: str | None
    onset: datetime
    expires: datetime
    areas: str | None

# Add to weather data structure
weather_data = {
    'current': {...},
    'hourly': {...},
    'daily': {...},
    'alerts': [WeatherAlert(...), ...]  # NEW
}
```

#### JavaScript (Web/PWA)
```javascript
// Add to weather data object
weatherData = {
    current: {...},
    hourly: {...},
    daily: {...},
    alerts: [  // NEW
        {
            id: "urn:oid:2.49.0.1.840.0.xxx",
            event: "Tornado Warning",
            severity: "Extreme",
            headline: "Tornado Warning issued...",
            description: "At 315 PM CST...",
            instruction: "TAKE COVER NOW!...",
            onset: "2026-01-21T15:15:00-06:00",
            expires: "2026-01-21T15:45:00-06:00",
            areas: "Madison; Dane County"
        }
    ]
};
```

### 2. Service Layer Changes

Add alert-fetching logic to weather services:

#### Swift Example
```swift
class WeatherService {
    func fetchWeather(for city: City) async throws -> WeatherResponse {
        // Existing Open-Meteo call
        let weather = try await fetchOpenMeteoWeather(city)
        
        // NEW: Fetch alerts based on location
        var alerts: [WeatherAlert] = []
        
        if city.country == "United States" {
            alerts = try await fetchNWSAlerts(lat: city.latitude, lon: city.longitude)
        } else if isEuropeanCountry(city.country) {
            alerts = try await fetchMeteoAlarmAlerts(city)
        }
        
        return WeatherResponse(
            current: weather.current,
            hourly: weather.hourly,
            daily: weather.daily,
            alerts: alerts.isEmpty ? nil : alerts
        )
    }
}
```

### 3. UI/UX Considerations

#### Alert Display Priority
- **Extreme/Severe alerts**: Show prominently at top of weather view
- **Banner/notification**: Red/orange background for urgent alerts
- **Sound**: Optional audio alert for extreme warnings (user configurable)
- **Accessibility**: Screen reader announces alert severity and headline

#### Alert Visual Design
```
┌─────────────────────────────────────────────┐
│ ⚠️ TORNADO WARNING - EXTREME               │
│ Dane County - Expires 3:45 PM              │
│ TAKE COVER NOW! Move to basement...        │
│ [View Details] [Dismiss]                    │
└─────────────────────────────────────────────┘
```

#### Alert Colors (Accessible Contrast)
- **Extreme**: Red (#CC0000) with white text (WCAG AAA)
- **Severe**: Orange (#FF6600) with black text
- **Moderate**: Yellow (#FFD700) with black text
- **Minor**: Light blue (#87CEEB) with black text

#### Accessibility Requirements
- VoiceOver/screen reader support with priority announcement
- High contrast ratios (WCAG 2.2 AA minimum)
- Keyboard navigation to view/dismiss alerts
- Alert history for review

### 4. Caching & Performance

- **Cache alerts separately** from weather data (different expiration)
- **Alert polling interval**: Every 5-10 minutes (alerts change less frequently)
- **Weather polling interval**: Every 10 minutes (current implementation)
- **User notification**: Only notify on NEW alerts (track seen alert IDs)

### 5. Privacy Considerations

- **NWS API**: No API key, no user tracking
- **User location**: Already shared with Open-Meteo for forecasts
- **Alert notifications**: Opt-in user preference (off by default?)
- **Data retention**: Don't store alert history server-side

### 6. Platform-Specific Implementation Notes

#### Python/wxPython Desktop
- Use threading for async alert fetches (existing pattern)
- Show alerts in `wx.InfoBar` at top of window
- Audio alert via `winsound` (Windows) or platform-specific libs

#### macOS SwiftUI
- Use native SwiftUI alerts for extreme warnings
- Show alerts banner in `ContentView`
- Local notifications for background alerts (requires notification permission)

#### iOS SwiftUI
- Similar to macOS implementation
- Local notifications for severe alerts
- Consider widget showing active alerts

#### Web/PWA
- Browser notifications (requires user permission)
- Alert banner at top of page
- Store dismissed alerts in `localStorage` to avoid re-showing

---

## Testing Strategy

### Test Scenarios
1. **No active alerts**: UI shows no alert banner
2. **Single moderate alert**: Shows yellow banner with details
3. **Multiple alerts**: Shows highest severity first, count indicator
4. **Expired alert**: Auto-dismiss after expiration time
5. **Network failure**: Gracefully handle alert API errors (show stale alerts)
6. **Non-US location**: No alerts shown (or show if global API added)

### Test Locations (US Cities with Frequent Alerts)
- **Tornado Alley**: Oklahoma City, OK (35.4676, -97.5164)
- **Hurricane Coast**: Miami, FL (25.7617, -80.1918)
- **Winter Storms**: Minneapolis, MN (44.9778, -93.2650)
- **Coastal Floods**: Charleston, SC (32.7765, -79.9311)

---

## Cost Analysis

### Option A: NWS Only (US) + MeteoAlarm (Europe)
- **Monthly Cost**: $0 (FREE)
- **Coverage**: US + Europe (~70% of user base?)
- **API Calls**: Unlimited (NWS), Unlimited (MeteoAlarm)
- **Best for**: Non-commercial, budget-conscious

### Option B: NWS + WeatherAPI.com Free Tier
- **Monthly Cost**: $0 (1M calls/month free)
- **Coverage**: Global
- **API Calls**: ~1 call/2.5 sec (1M/month = 33,333/day)
  - Example: 100 cities × 144 checks/day = 14,400 calls/day ✅
- **Best for**: Small-to-medium user base

### Option C: Full Commercial (WeatherAPI.com Paid)
- **Monthly Cost**: $4/month (2M calls), $12/month (10M calls)
- **Coverage**: Global
- **Best for**: Large user base, commercial deployment

---

## Phased Rollout Recommendation

### Phase 1: US Alerts Only (NWS)
**Timeline**: 1-2 weeks development  
**Scope**: Add NWS alerts for US cities  
**Risk**: Low (free API, well-documented)  
**User Impact**: High (US users get official alerts)

### Phase 2: European Alerts (MeteoAlarm)
**Timeline**: 1 week development  
**Scope**: Add MeteoAlarm for European cities  
**Risk**: Medium (XML parsing, less docs)  
**User Impact**: Medium (European users get alerts)

### Phase 3: Global Alerts (WeatherAPI.com)
**Timeline**: 1-2 weeks development  
**Scope**: Add WeatherAPI.com for remaining countries  
**Risk**: Low (JSON API, good docs)  
**User Impact**: Medium (global users get alerts)  
**Decision Point**: Evaluate user demand before implementing

---

## Open Questions

1. **User Preference**: Should alerts be opt-in or opt-out?
2. **Notification Sound**: Default sound for severe alerts? User configurable?
3. **Alert History**: Show expired alerts in a history view?
4. **Background Polling**: Desktop/mobile apps check alerts when not in foreground?
5. **Multi-City Alerts**: User has 10 cities - show alerts for all or just selected?
6. **International Coverage**: Implement Phase 3 immediately or wait for user requests?

---

## References

- [National Weather Service API Documentation](https://www.weather.gov/documentation/services-web-api)
- [WeatherAPI.com Documentation](https://www.weatherapi.com/docs/)
- [Weatherbit.io API Docs](https://www.weatherbit.io/api)
- [MeteoAlarm Website](https://meteoalarm.org/)
- [Open-Meteo Documentation](https://open-meteo.com/en/docs)
- [WCAG 2.2 Accessibility Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)

---

## Document Changelog

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-21 | Research | Initial document creation |

---

**Next Steps**: Review with team, prioritize phases, begin Phase 1 implementation if approved.
