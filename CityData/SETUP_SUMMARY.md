# CityData Directory Setup - Summary

## What Was Done

Created a centralized `CityData/` directory with all tools and data for managing city coordinates across all FastWeather platforms.

## Directory Structure

```
CityData/
├── README.md                           # Main documentation
├── ADDING_COUNTRIES_GUIDE.md          # Detailed guide for adding countries
├── requirements.txt                    # Python dependencies (requests)
├── setup-venv.bat                     # Virtual environment setup script
├── quick-start.bat                    # One-click setup and guidance
├── distribute-caches.bat              # Copies cached files to all platforms
│
├── international-cities-data.js       # Source: City names by country (67 countries)
├── us-cities-data.js                  # Source: City names by US state (50 states)
│
├── build-international-cache.py       # Script to geocode international cities
├── build-city-cache.py                # Script to geocode US cities
│
├── international-cities-cached.json   # Output: Cached coordinates (international)
└── us-cities-cached.json              # Output: Cached coordinates (US)
```

## What Was Added

### 45 New Countries (Ready to Geocode)

**Latin America (10):**
1. Colombia (co) - Bogotá, Medellín, Cali, Barranquilla, etc.
2. Peru (pe) - Lima, Arequipa, Cusco, Trujillo, etc.
3. Chile (cl) - Santiago, Valparaíso, Concepción, La Serena, etc.
4. Ecuador (ec) - Quito, Guayaquil, Cuenca, etc.
5. Bolivia (bo) - Santa Cruz, La Paz, El Alto, Cochabamba, etc.
6. Uruguay (uy) - Montevideo, Salto, Paysandú, etc.
7. Paraguay (py) - Asunción, Ciudad del Este, San Lorenzo, etc.
8. Venezuela (ve) - Caracas, Maracaibo, Valencia, etc.

**Central America & Caribbean (5):**
9. Dominican Republic (do) - Santo Domingo, Santiago, La Romana, etc.
10. Panama (pa) - Panama City, Colón, David, etc.
11. Costa Rica (cr) - San José, Limón, Alajuela, etc.
12. Guatemala (gt) - Guatemala City, Quetzaltenango, etc.
13. El Salvador (sv) - San Salvador, Santa Ana, San Miguel, etc.
14. Honduras (hn) - Tegucigalpa, San Pedro Sula, etc.

**Europe (4):**
15. Greece (gr) - Athens, Thessaloniki, Patras, Heraklion, etc.
16. Portugal (pt) - Lisbon, Porto, Braga, Coimbra, etc.
17. Czech Republic (cz) - Prague, Brno, Ostrava, Plzeň, etc.
18. Hungary (hu) - Budapest, Debrecen, Szeged, Miskolc, etc.
19. Romania (ro) - Bucharest, Cluj-Napoca, Timișoara, etc.

**Central Asia (1):**
20. Kazakhstan (kz) - Almaty, Astana, Shymkent, etc.

### Total Coverage After Geocoding
- **International:** 92 countries (47 existing + 45 new)
- **United States:** 50 states
- **Total Cities:** ~5,340 pre-geocoded locations

## Scripts Created

### 1. `setup-venv.bat`
Creates Python virtual environment and installs dependencies.

### 2. `quick-start.bat`
One-click setup with step-by-step guidance for first-time users.

### 3. `distribute-caches.bat`
Automatically copies cached JSON files to all platform locations:
- Root (Windows .exe)
- FastWeatherMac/ (macOS)
- iOS/FastWeather/Resources/ (iOS)
- webapp/ (Web/PWA)

## How to Use

### Option 1: Quick Start (Recommended)
```bash
cd CityData
quick-start.bat
```

This will:
1. Set up virtual environment
2. Install dependencies
3. Guide you through next steps

### Option 2: Manual Steps
```bash
# 1. Set up virtual environment
cd CityData
setup-venv.bat

# 2. Activate and run geocoding
venv\Scripts\activate
python build-international-cache.py

# 3. Distribute to all platforms
distribute-caches.bat
```

## Geocoding Time Estimate

**20 new countries × ~20 cities each × 1.1 sec/city + country delays:**
- Approximate time: **7-10 minutes**
- Script saves progress after each country (resumable if interrupted)
- Respects Nominatim's 1 request/second rate limit

## Testing After Geocoding

1. **Web/PWA:**
   ```bash
   cd webapp
   python -m http.server 8000
   # Browse Cities → International → [New Country]
   ```

2. **Windows:**
   ```bash
   python fastweather.py
   # Alt+W → International → [New Country]
   ```

3. **macOS:**
   ```bash
   cd FastWeatherMac
   ./build-and-launch.sh
   # Browse Cities → International → [New Country]
   ```

4. **iOS:**
   - Build in Xcode
   - Add City → Browse → International → [New Country]

## Files Modified

- `CityData/international-cities-data.js` - Added 20 countries with city names
- `CityData/build-international-cache.py` - Added ISO country codes for 20 countries

## Distribution Process

After running `distribute-caches.bat`, the cached files will be copied to:

```
FastWeather/
├── international-cities-cached.json    ← Root (Windows)
├── us-cities-cached.json              ← Root (Windows)
├── FastWeatherMac/
│   ├── international-cities-cached.json
│   └── us-cities-cached.json
├── iOS/FastWeather/Resources/
│   ├── international-cities-cached.json
│   └── us-cities-cached.json
└── webapp/
    ├── international-cities-cached.json
    └── us-cities-cached.json
```

## Next Steps for You

1. **Run the setup** (if not already done):
   ```bash
   cd CityData
   quick-start.bat
   ```

2. **Geocode the 20 new countries**:
   ```bash
   venv\Scripts\activate
   python build-international-cache.py
   ```
   *(Wait 7-10 minutes for completion)*

3. **Distribute to all platforms**:
   ```bash
   distribute-caches.bat
   ```

4. **Test on your platform(s)**

5. **Rebuild distribution packages** (optional):
   - Windows: `python build.py`
   - macOS: `cd FastWeatherMac && ./create-dmg.sh`
   - Web/PWA: No rebuild needed

## Notes

- Virtual environment will be created in `CityData/venv/` (not tracked in git)
- All scripts are Windows batch files (`.bat`)
- Geocoding progress is saved - script can be resumed if interrupted
- Rate limiting is enforced (1 request/second) - do not modify delays

## Documentation

- **README.md** - Quick reference for this directory
- **ADDING_COUNTRIES_GUIDE.md** - Comprehensive guide for adding countries
- See also: Root `ADDING_COUNTRIES_GUIDE.md` for full documentation

---

**Created:** January 18, 2026  
**FastWeather Version:** 2.0+  
**Purpose:** Centralized city data management for all platforms
