# Web App Cache Troubleshooting

## Problem: New countries not showing after running geocoding script

### Root Cause
The web app uses a Service Worker that caches files for offline use. When you update the JSON files, the browser continues serving the old cached version.

### Solution (Choose One)

#### Option 1: Hard Refresh (Quickest)
1. Open the web app in your browser
2. Press **Ctrl+Shift+R** (Windows/Linux) or **Cmd+Shift+R** (Mac)
3. This forces a full reload bypassing all caches

#### Option 2: Clear Service Worker Cache
1. Open browser DevTools (F12)
2. Go to **Application** tab
3. Click **Storage** → **Clear site data**
4. Refresh the page (F5)

#### Option 3: Service Worker Update (Already Done)
The service worker version has been updated from `v1` to `v2-92countries`. This will automatically clear old caches on next reload.

### How to Verify Files Were Distributed

Check file sizes match across locations:

```bash
# From CityData directory
ls -lh international-cities-cached.json
ls -lh ../webapp/international-cities-cached.json
ls -lh ../FastWeatherMac/international-cities-cached.json
ls -lh ../iOS/FastWeather/Resources/international-cities-cached.json
```

**Expected size after geocoding 92 countries:** ~310-320 KB  
**Old size (47 countries):** ~163 KB

### Distribution Script Issues

**If using Windows Git Bash:**
Use the bash script instead of .bat:
```bash
cd CityData
./distribute-caches.sh
```

**If using Windows Command Prompt:**
Use the batch file:
```cmd
cd CityData
distribute-caches.bat
```

### Manual Distribution (If Scripts Fail)

From the CityData directory:

```bash
# Copy to all locations manually
cp international-cities-cached.json ../
cp international-cities-cached.json ../webapp/
cp international-cities-cached.json ../FastWeatherMac/
cp international-cities-cached.json ../iOS/FastWeather/Resources/

cp us-cities-cached.json ../
cp us-cities-cached.json ../webapp/
cp us-cities-cached.json ../FastWeatherMac/
cp us-cities-cached.json ../iOS/FastWeather/Resources/
```

### What Was Fixed

1. ✅ **Copied updated JSON to webapp** - File now has 92 countries
2. ✅ **Updated service worker version** - Changed from `v1` to `v2-92countries`
3. ✅ **Removed obsolete cache entries** - Removed deleted -data.js files from cache
4. ✅ **Created bash distribution script** - `distribute-caches.sh` for Git Bash users

### Testing After Fix

1. **Hard refresh** the browser (Ctrl+Shift+R)
2. Open **Browse Cities by State/Country**
3. Click **International**
4. Verify new countries appear (Colombia, Peru, Greece, etc.)
5. Select a city and verify weather loads

### Expected Results

You should now see **92 countries** in the International section, including:
- Latin America: Colombia, Peru, Chile, Ecuador, Bolivia, etc.
- Europe: Greece, Portugal, Croatia, Serbia, Bulgaria, etc.
- Africa: Algeria, Tunisia, Ghana, Tanzania, etc.
- Asia: Cambodia, Laos, Myanmar, Uzbekistan, etc.
- Caribbean: Jamaica, Trinidad and Tobago, Cuba
- Middle East: Lebanon, Oman, Bahrain

### If Still Not Working

1. Check browser console (F12) for errors
2. Verify JSON file size in webapp is ~317KB
3. Try incognito/private browsing mode
4. Clear all browser data for localhost
5. Restart the web server

### For Future Updates

Always increment the service worker cache version when updating JSON files:

```javascript
// In service-worker.js
const CACHE_NAME = 'fastweather-v3';  // Increment this
```
