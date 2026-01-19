# Adding New Countries to FastWeather

This guide explains how to add support for new countries across all FastWeather platforms (Web/PWA, Windows Desktop, macOS, and iOS).

## Overview

FastWeather uses a cached coordinate system to avoid slow API calls during initial load. City coordinates are pre-geocoded and stored in JSON files that all platforms share.

**Current Support:** 47 international countries + United States (with 50 states)

## System Architecture

### 1. Data Source Files (Web Only)
- **Location:** `webapp/international-cities-data.js`
- **Purpose:** JavaScript object containing city names grouped by country
- **Format:** Plain city names as strings (no coordinates yet)

### 2. Build Scripts (Web Only)
- **Location:** `webapp/build-international-cache.py`
- **Purpose:** Geocodes all cities using OpenStreetMap Nominatim API
- **Output:** `international-cities-cached.json`
- **Runtime:** ~40-50 minutes for 47 countries × ~20 cities × 1.1 sec/city

### 3. Cached Coordinate Files (All Platforms)
Generated files used by all platforms:
- `webapp/international-cities-cached.json` (source)
- `international-cities-cached.json` (root - copied for Windows)
- `FastWeatherMac/international-cities-cached.json` (macOS)
- iOS uses the root copy via cloud sync/manual copy

### 4. Platform Integration

**Web/PWA:** `app.js` loads cached JSON directly  
**Windows:** `fastweather.py` loads cached JSON from root or bundled with PyInstaller  
**macOS:** Loads from `FastWeatherMac/` directory  
**iOS:** Manual copy to project resources

## Step-by-Step: Adding New Countries

### Step 1: Add City Names to Data Source

Edit `webapp/international-cities-data.js`:

```javascript
const INTERNATIONAL_CITIES_BY_COUNTRY = {
    // ... existing countries ...
    
    "New Country Name": [
        "Major City 1", "Major City 2", "Capital City", "Port City",
        "City 5", "City 6", "City 7", "City 8", "City 9", "City 10",
        // Add 15-20 major cities for best coverage
        "City 11", "City 12", "City 13", "City 14", "City 15",
        "City 16", "City 17", "City 18", "City 19", "City 20"
    ],
};
```

**Guidelines for city selection:**
- Include capital city
- Include largest cities by population
- Include major tourist destinations
- Include diverse geographic regions
- Aim for 15-20 cities per country (minimum)
- Use official English names (not romanizations if possible)

### Step 2: Add Country Code Mapping

Edit `webapp/build-international-cache.py`:

Find the `COUNTRY_CODES` dictionary and add your country's ISO 3166-1 alpha-2 code:

```python
COUNTRY_CODES = {
    # ... existing countries ...
    'New Country Name': 'xx',  # ISO 3166-1 alpha-2 code (lowercase)
}
```

**ISO Country Code Reference:** [https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)

Examples:
- Colombia → `'co'`
- Peru → `'pe'`
- Chile → `'cl'`
- Greece → `'gr'`
- Portugal → `'pt'`

### Step 3: Run the Geocoding Script

**IMPORTANT:** This script respects Nominatim's rate limit of 1 request/second. Do NOT modify the delays.

```bash
cd webapp
python build-international-cache.py
```

**What happens:**
1. Loads existing cache (so you can resume if interrupted)
2. Skips already-geocoded countries
3. Geocodes new cities at 1 request/second
4. Saves progress after each country
5. Updates `webapp/international-cities-cached.json`

**Estimated time per country:** ~25-30 seconds for 20 cities

**Output example:**
```
[1/48] Processing New Country Name (xx)...
  [1/20] Geocoding Major City 1... ✓
  [2/20] Geocoding Major City 2... ✓
  ...
  ✓ Saved 20 cities for New Country Name
```

### Step 4: Distribute Cached Files to Other Platforms

After building the cache, copy the file to other platform locations:

**Windows (Root):**
```bash
copy webapp\international-cities-cached.json .
```

**macOS:**
```bash
cp webapp/international-cities-cached.json FastWeatherMac/
```

**iOS:**
```bash
cp webapp/international-cities-cached.json iOS/FastWeather/Resources/
# Or add via Xcode: Right-click Resources folder → Add Files
```

### Step 5: Test on Each Platform

**Web/PWA:**
```bash
cd webapp
python -m http.server 8000
# Open http://localhost:8000
# Test: Browse Cities → International → New Country Name
```

**Windows:**
```bash
python fastweather.py
# Test: Alt+W → International → New Country Name
```

**macOS:**
```bash
cd FastWeatherMac
./build-and-launch.sh
# Test: Browse Cities by State/Country → International → New Country Name
```

**iOS:**
- Build and run in Xcode
- Test: Add City → Browse by Location → International → New Country Name

### Step 6: Rebuild Distribution Packages (Optional)

If distributing to end users:

**Windows .exe:**
```bash
python build.py
```

**macOS .dmg:**
```bash
cd FastWeatherMac
./create-dmg.sh
```

**Web/PWA:**
- No rebuild needed (static files)
- Service worker will auto-update on next visit

## Current Countries Supported

### 47 International Countries:
Argentina, Australia, Austria, Bangladesh, Belgium, Brazil, Canada, China, Denmark, Egypt, Ethiopia, Finland, France, Germany, India, Indonesia, Iran, Iraq, Ireland, Israel, Italy, Japan, Jordan, Kenya, Kuwait, Malaysia, Mexico, Morocco, Netherlands, New Zealand, Nigeria, Norway, Pakistan, Philippines, Poland, Qatar, Russia, Saudi Arabia, Singapore, South Africa, South Korea, Spain, Sweden, Switzerland, Taiwan, Thailand, Turkey, Ukraine, United Arab Emirates, United Kingdom, Vietnam

### U.S. Coverage:
All 50 states with 50 cities each (2,500 total cities)

## Troubleshooting

### "City not found" during geocoding
- Check city name spelling (use official English names)
- Verify country code is correct in `COUNTRY_CODES`
- Try alternative city names (e.g., "Ho Chi Minh City" vs "Saigon")
- Some small cities may not be in OpenStreetMap database

### Script interrupted/network error
- The script saves progress after each country
- Simply re-run `python build-international-cache.py`
- It will skip already-geocoded countries and resume

### Rate limit errors
- DO NOT reduce the 1.1 second delay in the script
- Nominatim requires 1 request/second maximum
- Violating this may result in IP ban

### File not found on other platforms
- Ensure you copied the cached JSON to all platform directories
- Check file paths are correct (case-sensitive on macOS/iOS)
- For bundled apps (Windows .exe, macOS .app), rebuild after adding cache

## Performance Impact

**Without cache (all API calls):**
- 20 cities × 1.1 sec = ~22 seconds load time per country
- User experiences significant delay

**With cache (pre-geocoded):**
- Instant load from local JSON
- Only weather API calls needed (~1-2 sec per city)
- Much better user experience

## API Compliance

**Nominatim Usage Policy:**
- Maximum 1 request per second (enforced in script)
- User-Agent header required: `FastWeather CacheBuilder/1.0`
- Bulk geocoding must be done offline (pre-cached)
- See: [https://operations.osmfoundation.org/policies/nominatim/](https://operations.osmfoundation.org/policies/nominatim/)

**Open-Meteo Weather API:**
- No API key required
- No rate limits for non-commercial use
- Attribution required (already included in all platforms)

## Suggested Countries to Add Next

Based on global population and FastWeather user requests:

1. **Colombia** (co) - Major cities: Bogotá, Medellín, Cali, Barranquilla
2. **Peru** (pe) - Lima, Cusco, Arequipa, Trujillo
3. **Chile** (cl) - Santiago, Valparaíso, Concepción, La Serena
4. **Greece** (gr) - Athens, Thessaloniki, Patras, Heraklion
5. **Portugal** (pt) - Lisbon, Porto, Braga, Coimbra
6. **Czech Republic** (cz) - Prague, Brno, Ostrava, Plzeň
7. **Hungary** (hu) - Budapest, Debrecen, Szeged, Miskolc
8. **Romania** (ro) - Bucharest, Cluj-Napoca, Timișoara, Iași
9. **Venezuela** (ve) - Caracas, Maracaibo, Valencia, Barquisimeto
10. **Kazakhstan** (kz) - Almaty, Astana, Shymkent, Karaganda

## Questions?

If you encounter issues or need help adding a specific country:

1. Check this guide first
2. Review `webapp/build-international-cache.py` for examples
3. Test the geocoding script output for errors
4. Verify the cached JSON file is properly formatted

---

**Last Updated:** January 18, 2026  
**FastWeather Version:** 2.0+  
**Platforms:** Web/PWA, Windows, macOS, iOS
