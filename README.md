# FastWeather

A fast, accessibility-first weather application available across three platforms — iOS, Web/PWA, and Windows Desktop. All versions provide current conditions and detailed forecasts without the clutter, and share pre-geocoded city coordinate data for consistent location search.

## Platform Overview

| Platform | Directory | Language/Stack |
|----------|-----------|----------------|
| iOS | [`iOS/`](iOS/) | Swift / SwiftUI (iOS 17+) |
| Web/PWA | [`webapp/`](webapp/) | Vanilla HTML/CSS/JS |
| Windows Desktop | [`windows/`](windows/) | Python + wxPython |
| City Data | [`CityData/`](CityData/) | Python (shared geocoding scripts) |

All platforms use [Open-Meteo](https://open-meteo.com/) (no API key required for free tier) for weather data and share pre-geocoded city coordinate files.

## Features

- **Fast & Simple**: Current weather at a glance, detailed forecasts on demand.
- **Comprehensive Data**: Temperature, feels-like, humidity, wind, precipitation, UV index, visibility, cloud cover, and more.
- **Accessible**: Fully compatible with screen readers and keyboard navigation on all platforms.
- **No API Key Required**: Uses the free Open-Meteo weather service.
- **Privacy First**: No tracking, no analytics, your cities stored locally.
- **Multi-Platform**: Native iOS app, progressive web app, and Windows desktop executable.

## Quick Start

### iOS

Open `iOS/FastWeather.xcodeproj` in Xcode, create `iOS/FastWeather/Services/Secrets.swift` (see [`iOS/README.md`](iOS/README.md)), then build and run.

### Web/PWA

```bash
cd webapp
npm run serve        # starts local server on port 8000
```

### Windows Desktop

```bash
cd windows
pip install -r requirements.txt
python fastweather.py
```

To build a standalone executable:

```bash
cd windows
python build.py      # produces dist/ executable via PyInstaller
```

## City Data (Shared Across Platforms)

Pre-geocoded city files live in `CityData/` and are copied to each platform. Rebuild only when adding cities or countries.

```bash
cd CityData
pip install -r requirements.txt
python build-city-cache.py            # US cities
python build-international-cache.py   # International cities
```

## License

This project is licensed under the MIT License.

Data provided by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0).
Geocoding provided by [OpenStreetMap](https://www.openstreetmap.org/).
Geocoding provided by [OpenStreetMap](https://www.openstreetmap.org/).
