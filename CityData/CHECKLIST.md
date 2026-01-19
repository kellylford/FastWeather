# FastWeather CityData - Your Action Checklist

Follow these steps to geocode the 20 new countries and distribute to all platforms.

## ✅ Pre-Setup (Already Done)

- [x] CityData directory created
- [x] All source files copied
- [x] 20 new countries added to international-cities-data.js
- [x] ISO country codes added to build-international-cache.py
- [x] Distribution scripts created
- [x] Documentation created

## 📋 Your Tasks

### Step 1: Initial Setup
```bash
cd CityData
quick-start.bat
```

**What this does:**
- Creates Python virtual environment in `venv/`
- Installs `requests` library
- Shows you next steps

**Time:** ~30 seconds

---

### Step 2: Run Geocoding Script
```bash
venv\Scripts\activate
python build-international-cache.py
```

**What this does:**
- Reads existing international-cities-cached.json (skips already geocoded)
- Geocodes 45 new countries (900 cities total)
- Saves progress after each country
- Creates/updates international-cities-cached.json

**Time:** ~15-20 minutes  
**Rate limit:** 1 request/second (do not interrupt or modify)

**Progress output example:**
```
[48/67] Processing Colombia (co)...
  [1/20] Geocoding Bogotá... ✓
  [2/20] Geocoding Medellín... ✓
  ...
  ✓ Saved 20 cities for Colombia
```

**If interrupted:** Just run the command again - it will resume from where it stopped.

---

### Step 3: Distribute to All Platforms
```bash
deactivate  # Exit virtual environment
distribute-caches.bat
```

**What this does:**
- Copies `international-cities-cached.json` to:
  - `../` (root - for Windows .exe)
  - `../FastWeatherMac/`
  - `../iOS/FastWeather/Resources/`
  - `../webapp/`
- Copies `us-cities-cached.json` to same locations

**Time:** ~5 seconds

---

### Step 4: Test Each Platform

#### Web/PWA Test
```bash
cd ..\webapp
python -m http.server 8000
# Open http://localhost:8000
# Click "Browse Cities by State/Country"
# Click "International"
# Verify new countries appear (Colombia, Peru, Chile, etc.)
# Select a city and verify weather loads
```

#### Windows Desktop Test
```bash
cd ..
python fastweather.py
# Press Alt+W (Browse Cities)
# Select "International"
# Verify new countries appear
# Add a city from a new country
# Verify weather displays
```

#### macOS Test (if you have a Mac)
```bash
cd FastWeatherMac
./build-and-launch.sh
# Browse Cities by State/Country
# International
# Verify new countries
```

#### iOS Test (if you have Xcode)
```bash
cd iOS
open FastWeather.xcodeproj
# Build and run
# Add City → Browse by Location → International
# Verify new countries
```

---

### Step 5: Optional - Rebuild Distribution Packages

Only if you plan to distribute to end users:

**Windows .exe:**
```bash
cd ..
python build.py
# Creates dist/FastWeather.exe with embedded cached files
```

**macOS .dmg:**
```bash
cd FastWeatherMac
./create-dmg.sh
# Creates distributable .dmg installer
```

**Web/PWA:**
No rebuild needed - just upload new JSON files to your web server.

---

## 🎯 New Countries Added (45 Total)

### Latin America (10)
- [ ] Colombia (co) - 20 cities
- [ ] Peru (pe) - 20 cities
- [ ] Chile (cl) - 20 cities
- [ ] Ecuador (ec) - 20 cities
- [ ] Bolivia (bo) - 20 cities
- [ ] Uruguay (uy) - 20 cities
- [ ] Paraguay (py) - 20 cities
- [ ] Venezuela (ve) - 20 cities
- [ ] Cuba (cu) - 20 cities

### Central America & Caribbean (6)
- [ ] Dominican Republic (do) - 20 cities
- [ ] Panama (pa) - 20 cities
- [ ] Costa Rica (cr) - 20 cities
- [ ] Guatemala (gt) - 20 cities
- [ ] El Salvador (sv) - 20 cities
- [ ] Honduras (hn) - 20 cities
- [ ] Jamaica (jm) - 20 cities
- [ ] Trinidad and Tobago (tt) - 20 cities

### Europe (9)
- [ ] Greece (gr) - 20 cities
- [ ] Portugal (pt) - 20 cities
- [ ] Czech Republic (cz) - 20 cities
- [ ] Hungary (hu) - 20 cities
- [ ] Romania (ro) - 20 cities
- [ ] Croatia (hr) - 20 cities
- [ ] Serbia (rs) - 20 cities
- [ ] Bulgaria (bg) - 20 cities
- [ ] Slovakia (sk) - 20 cities
- [ ] Slovenia (si) - 20 cities

### Central & South Asia (5)
- [ ] Kazakhstan (kz) - 20 cities
- [ ] Uzbekistan (uz) - 20 cities
- [ ] Azerbaijan (az) - 20 cities
- [ ] Georgia (ge) - 20 cities
- [ ] Armenia (am) - 20 cities

### Southeast Asia (3)
- [ ] Cambodia (kh) - 20 cities
- [ ] Laos (la) - 20 cities
- [ ] Myanmar (mm) - 20 cities

### Middle East (3)
- [ ] Lebanon (lb) - 20 cities
- [ ] Oman (om) - 20 cities
- [ ] Bahrain (bh) - 20 cities

### Africa (9)
- [ ] Algeria (dz) - 20 cities
- [ ] Tunisia (tn) - 20 cities
- [ ] Ghana (gh) - 20 cities
- [ ] Tanzania (tz) - 20 cities
- [ ] Uganda (ug) - 20 cities
- [ ] Cameroon (cm) - 20 cities
- [ ] Senegal (sn) - 20 cities
- [ ] Côte d'Ivoire (ci) - 20 cities
- [ ] Zimbabwe (zw) - 20 cities
- [ ] Mozambique (mz) - 20 cities
- [ ] Angola (ao) - 20 cities

---

## 🚨 Troubleshooting

### "No module named 'requests'"
```bash
venv\Scripts\activate
pip install -r requirements.txt
```

### "Rate limit exceeded" or network errors
- Wait 5-10 minutes and re-run the script
- It will resume from where it stopped
- Do NOT reduce the 1.1 second delay in the script

### "City not found" during geocoding
- This is normal for some small cities
- The script will continue with remaining cities
- Check the output for which cities failed

### "Permission denied" when copying files
- Run distribute-caches.bat as administrator
- Or manually copy the JSON files to each platform

### Files not appearing on iOS
- Open Xcode
- Right-click on Resources folder
- Add Files to "FastWeather"
- Select the cached JSON files
- Check "Copy items if needed"

---

## 📊 Expected Results

After geocoding completes:
- `international-cities-cached.json` will grow from ~163KB to ~375KB
- File will contain 92 countries (47 old + 45 new)
- ~1,840 international cities with coordinates
- All platforms will have instant access to new cities

---

## 🎉 Success Criteria

You're done when:
- [x] Geocoding script completes without errors
- [x] distribute-caches.bat runs successfully
- [x] New countries appear in Browse Cities on all platforms
- [x] Can add cities from new countries
- [x] Weather data loads for new cities

---

## 📁 Files You'll Create

During this process, the following will be created:
- `CityData/venv/` - Python virtual environment (ignored by git)
- Updated `international-cities-cached.json` (in CityData and all platform locations)

---

## ⏱️ Total Time Estimate

- Setup: ~30 seconds
- Geocoding: ~7-10 minutes
- Distribution: ~5 seconds
- Testing: ~5 minutes per platform

**Total: ~15-20 minutes** (plus testing time)

---

Ready to begin? Run: `quick-start.bat`
