# FastWeather User Guide

FastWeather is a lightweight, accessible, and customizable weather app for iPhone and iPad. It provides current conditions, hourly forecasts, and daily outlooks for cities around the world without requiring an API key or account.

An in-app version of this guide is available under **Settings → User Guide**.

---

## Getting Started

### Adding Cities
1. Open the **My Cities** tab and tap **+** (Add City).
2. Type a city name (e.g., "Madison, WI" or "London, UK").
3. Select from the search results. The city is added to your list immediately.

Alternatively, use the **Browse** tab to explore cities by U.S. state or international country and add ones you find interesting.

### Default Cities
The first time you launch, a set of default cities is pre-loaded. You can remove or reorder these at any time.

### Data Storage
Your city list and settings are stored on-device via iOS standard storage. They persist across app updates and device restarts. To clear everything, go to **Settings → Data Management**.

---

## The Three Tabs

### My Cities
Your saved city list. Each city shows current temperature, conditions, and (optionally) additional fields you configure.

- **Tap** a city to open its full detail view
- **Pull down** to refresh all cities
- **Swipe left** on a city row to delete it (List view), or use the **VoiceOver actions menu**
- **Drag** the reorder handle to rearrange cities (List/Table view)
- **Long-press** or use the Actions menu (Flat view) for Move Up/Down/Top/Bottom and Remove

Three view modes are available in **Settings → Display Options**:
- **List** — Compact rows, swipe-to-delete, drag-to-reorder
- **Table** — Accessible data table with configurable columns; supports VoiceOver table navigation rotor
- **Flat** — Cards grouped per city with an Actions menu

### Browse Cities
Explore the full directory of cities without adding them to your list.

- Browse by **U.S. States** or **International** countries
- Tap a state or country to see its city list with live weather
- Tap a city to view its weather; tap **+** to add it to My Cities
- Sort cities within a state/country by name, geographic order (N→S, S→N, E→W, W→E), or temperature

### Settings
All preferences are here. Changes save immediately — there is no Save or Apply button.

Key sections:
- **Units** — °F/°C, mph/km/h, in/mm, inHg/hPa, mi/km
- **Display Options** — View mode (List/Table/Flat), List Content Display
- **City List View** — Toggle and reorder weather fields; Glance Ahead time (1–8 hours)
- **Current Weather Detail View** — Toggle and reorder detail sections (Today's Forecast, Current Conditions, 24-Hour Forecast, 16-Day Forecast, Marine Forecast, Weather Alerts, Location, Astronomy)
- **Features** — Toggle Expected Precipitation, Weather Around Me, International Weather Alerts
- **Weather Around Me** — Distance, exploration mode, arc/corridor width, display toggles
- **Data Management** — Clear All Cities, Reset Settings to Default

---

## City Detail View

Tap any city to see its full weather report. Sections are collapsible and can be reordered in Settings.

### Today's Forecast
Conditions icon, temperature range, precipitation alert (if >20% chance), UV warning (if ≥6), wind alert, sunrise/sunset times, daylight and sunshine duration.

### Current Conditions
Temperature, Feels Like, Humidity, Wind (speed, direction, gusts), UV Index (daytime only), Dew Point, Pressure, Visibility, Cloud Cover, current precipitation rate (if active).

**UV Index levels:**
- 0–2 Low — minimal protection needed
- 3–5 Moderate — SPF 30+ sunscreen
- 6–7 High — SPF 30+, seek shade
- 8–10 Very High — SPF 50+, avoid midday sun
- 11+ Extreme — stay indoors if possible

**Dew Point comfort levels:**
- Below 55°F (13°C) — Dry
- 55–60°F (13–16°C) — Comfortable
- 60–65°F (16–18°C) — Slightly humid
- 65–70°F (18–21°C) — Muggy/Uncomfortable
- Above 70°F (21°C) — Oppressive

### 24-Hour Forecast
Hourly cards (horizontal scroll) or headings layout. Configurable fields include temperature, conditions, precipitation, rain chance, UV Index, wind, humidity, and more.

### 16-Day Forecast
Daily rows showing high/low, conditions, precipitation, sunrise/sunset, daylight/sunshine duration, UV Index. Tap any day row (cards layout) to open a full Day Detail view with that day's hourly breakdown.

### Marine Forecast
Available for coastal locations. Includes sea level height (tidal), wave height/direction/period, sea surface temperature, swell conditions, and ocean current velocity. Enable and customize in **Settings → Marine Forecast**.

### Weather Alerts
Active NWS alerts for U.S. cities. International alert support available via Settings → Features → International Weather Alerts.

### Astronomy
Moon phase name, illumination percentage, moonrise, and moonset.

---

## Weather in Time

View weather for all your cities on a different day — up to 7 days in the past or future.

- **VoiceOver:** Focus the date display at the top of My Cities, then swipe up for the next day or down for the previous day
- **Alternative:** Use the left/right arrow buttons in the toolbar
- Tap **Return to Today** (calendar icon in toolbar) to snap back to the current date
- The app does not automatically revert to today when backgrounded — check the date display if conditions look unexpected

---

## Weather Around Me

See weather in cities surrounding any city in your list, useful for tracking approaching weather systems and building a spatial picture of regional conditions.

Access via the **Actions menu** on any city (three-dot button) → **Weather Around Me**.

### What You'll See
- Weather in 8 compass directions (N, NE, E, SE, S, SW, W, NW)
- Distance, bearing, and offset from center line for each city
- Wind movement analysis (approaching / moving away / parallel)
- Pressure trends between consecutive cities

### Exploring a Direction
Tap any direction to see cities along that path. Swipe up for cities farther away, swipe down for closer cities. Tap **List All** to see all cities at once.

### VoiceOver Example Announcement
> "Milwaukee, Wisconsin, 80 miles, 5 degrees, 3 miles east of center line, 72°F, Overcast, Alert: Tornado Warning, Approaching at 15 mph, Pressure steady, 2 of 15"

### Exploration Modes
Configure in **Settings → Weather Around Me** or tap the gear icon inside Weather Around Me:

**Arc Mode** (default) — fan-shaped search that expands outward.
| Arc Width | Width at 100 mi |
| :--- | :--- |
| Narrow (10°) | 17 mi |
| Standard (22.5°) | 39 mi |
| Medium (45°) | 77 mi |
| Wide (90°) | 141 mi |

**Straight Line Corridor** — fixed-width band along the center line.
| Corridor Width | Coverage |
| :--- | :--- |
| 10 miles | ±5 mi from center |
| 20 miles | ±10 mi from center (default) |
| 30 miles | ±15 mi from center |
| 50 miles | ±25 mi from center |

**VoiceOver Quick Cycle:** Focus the gear icon and swipe up/down to cycle through all mode combinations without opening Settings.

---

## Historical Weather

Access from the **Actions menu** on any city → **View Historical Weather**. Data is available back to 1940 for most locations.

Modes:
- **Single Day** — pick a specific date
- **Multi-Year** — compare the same date across multiple years
- **Daily Browse** — scroll through a month view

---

## Expected Precipitation

A precipitation forecast timeline showing intensity over the coming hours. Enable in **Settings → Features**. Access via the Actions menu on any city.

The timeline is a visual chart for sighted users. VoiceOver users can explore the same data through the audio graph below it, which provides tones representing intensity and individual data points accessible by swiping.

---

## Weather Icons

Icons change between day and night for the two clearest conditions:

| Condition | Day | Night |
| :--- | :--- | :--- |
| Clear sky / Mainly clear | ☀️ Sun | 🌙 Moon with stars |
| Partly cloudy | 🌤 Cloud with sun | ☁️🌙 Cloud with moon |
| Overcast | ☁️ Cloud | ☁️ Cloud |
| Fog / Depositing rime fog | Fog cloud | Fog cloud |
| Drizzle (light/moderate/dense) | Drizzle cloud | Drizzle cloud |
| Freezing drizzle / Freezing rain | Sleet cloud | Sleet cloud |
| Slight / Moderate / Heavy rain | Rain cloud | Rain cloud |
| Snow fall / Snow grains / Snow showers | Snow cloud | Snow cloud |
| Rain showers (slight/moderate/violent) | Heavy rain cloud | Heavy rain cloud |
| Thunderstorm / with hail | Lightning cloud | Lightning cloud |

VoiceOver always announces the exact condition by name (e.g., "Conditions: Clear sky"). The icon is decorative and hidden from VoiceOver.

---

## Accessibility

FastWeather is designed primarily for VoiceOver users.

- All features are accessible without seeing the screen
- Descriptive, context-aware VoiceOver labels throughout
- Weather icons are decorative — conditions are always announced by name
- Dynamic Type supported — text scales with your system font size setting
- High contrast — readable in all lighting conditions
- VoiceOver custom actions for city reordering (Move Up, Move Down, Move to Top, Move to Bottom)
- VoiceOver table rotor navigation in Table view

**Why doesn't the UV Index show at night?**
UV radiation only exists during daylight hours. The field is hidden automatically when the API reports nighttime (`is_day = 0`).

**What's the difference between Daylight Duration and Sunshine Duration?**
Daylight Duration is the total time from sunrise to sunset. Sunshine Duration is expected hours of actual direct sunlight. If sunshine duration is much lower than daylight, expect mostly cloudy skies.

**The hourly forecast seems to start at the wrong time.**
The forecast is based on your device's current time and the city's local time zone. Ensure your device clock is correct.

**I want to reset everything.**
Go to **Settings → Data Management** and use **Clear All Cities** and/or **Reset Settings to Default**.

---

## Keyboard Shortcuts (iPad with external keyboard)

| Action | Shortcut |
| :--- | :--- |
| Add new city | `⌘⇧N` |

More shortcuts will be added in future updates.

---

## Data Sources

- **[Open-Meteo](https://open-meteo.com/)** (CC BY 4.0) — current conditions, hourly, daily, and historical forecast data
- **[OpenStreetMap Nominatim](https://nominatim.org/)** — city geocoding
- **National Weather Service** — U.S. weather alerts

No API key required. No account required. No data tracking.

---

## Reporting Issues

[https://github.com/kellylford/WeatherFast/issues](https://github.com/kellylford/WeatherFast/issues)

