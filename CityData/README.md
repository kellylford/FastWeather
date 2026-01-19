# FastWeather CityData Directory

This directory contains all the tools and data for managing city coordinates across all FastWeather platforms.

## Contents

- **international-cities-data.js** - Source data with city names by country
- **us-cities-data.js** - Source data with city names by US state
- **build-international-cache.py** - Script to geocode international cities
- **build-city-cache.py** - Script to geocode US cities
- **international-cities-cached.json** - Cached coordinates for international cities
- **us-cities-cached.json** - Cached coordinates for US cities
- **ADDING_COUNTRIES_GUIDE.md** - Complete guide for adding new countries
- **distribute-caches.bat** - Batch file to copy cached files to all platforms
- **requirements.txt** - Python dependencies for geocoding scripts

## Quick Start

### 1. Set Up Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Build City Caches

Only run this if adding new cities or countries:

```bash
# Build international cities cache (~40-50 minutes)
python build-international-cache.py

# Build US cities cache (~2-3 hours for all 50 states)
python build-city-cache.py
```

### 3. Distribute to All Platforms

After building caches, run the distribution script:

```bash
distribute-caches.bat
```

This copies the cached JSON files to:
- Root directory (for Windows .exe)
- FastWeatherMac/ (for macOS app)
- iOS/FastWeather/Resources/ (for iOS app)
- webapp/ (for web/PWA - source location)

## Current Coverage

- **International:** 93 countries with ~20 cities each
- **United States:** 50 states with 50 cities each
- **Total Cities:** ~4,360 pre-geocoded locations

## Adding New Countries

See `ADDING_COUNTRIES_GUIDE.md` for detailed instructions.

Quick steps:
1. Edit `international-cities-data.js` - add country and cities
2. Edit `build-international-cache.py` - add ISO country code
3. Run `python build-international-cache.py`
4. Run `distribute-caches.bat`
5. Test on each platform

## Notes

- Geocoding respects Nominatim's 1 request/second rate limit
- Script saves progress after each country (resumable)
- Cache files are ~166KB (international) + ~395KB (US) = ~561KB total
- All platforms share the same cached coordinate files
