# Country Name Normalization - Implementation Plan

**Date:** February 7, 2026  
**Issue:** Country names display in native language ("Deutschland", "Việt Nam") instead of US English  
**Scope:** All platforms (iOS, macOS, Web, Python)  
**Risk Level:** 🟡 Moderate (data migration required)

---

## Problem Statement

OpenStreetMap Nominatim API returns country names in their native language by default:
- Germany → "Deutschland"
- Vietnam → "Việt Nam" (with diacritics)
- Austria → "Österreich"
- Belgium → "België / Belgique / Belgien"

This affects:
- **City display names** in all views (list, detail, browse)
- **Cached city data** (~17,000+ international cities)
- **User-saved cities** that were geocoded with native names
- **VoiceOver pronunciation** (reads native names with English phonetics)

---

## Root Cause Analysis

### Data Flow
1. **Cache Build:** `build-international-cache.py` queries Nominatim → receives `address.country` (native) → stores in cache
2. **Live Geocoding:** All platforms query Nominatim → receive `address.country` (native) → save to user data
3. **Display:** All platforms read directly from cache/saved data → show native names

### Why Native Names?
- Nominatim returns native names by default from OpenStreetMap database
- No `accept-language=en` header used in requests
- Even with language header, Nominatim's support is inconsistent (depends on OSM data)
- No client-side normalization or translation layer exists

---

## Solution Design

### Architecture
Use **ISO 3166-1 alpha-2 country codes** + **hardcoded mapping table**:
- Nominatim provides `address.country_code` (uppercase 2-letter: "DE", "VN", "US")
- Map to English names: `ISO_MAPPING = {"DE": "Germany", "VN": "Vietnam", ...}`
- Fallback to native name if code missing or unmapped (graceful degradation)

### Why This Approach?
✅ **Reliable:** ISO standard, doesn't depend on Nominatim language negotiation  
✅ **Fast:** O(1) dictionary lookup, no API calls  
✅ **Maintainable:** Centralized mapping, easy to update  
✅ **Consistent:** Same logic across all platforms  
✅ **Future-proof:** Can add alternate names/localizations later  

### Alternatives Considered
❌ **Accept-Language header:** Nominatim support inconsistent, depends on OSM data quality  
❌ **External translation API:** Adds dependency, latency, potential cost  
❌ **Manual curation:** Not scalable, hard to maintain  

---

## Implementation Steps

### Phase 1: Create Country Code Mapping (All Platforms)

**Files to Create:**
- `CityData/country_names.py` - Python dictionary (~200 ISO codes)
- `iOS/FastWeather/Utilities/CountryNames.swift` - Swift mapping
- `FastWeatherMac/FastWeatherMac/Utilities/CountryNames.swift` - macOS copy
- `webapp/country-names.js` - JavaScript mapping

**Mapping Structure:**
```python
ISO_TO_ENGLISH = {
    "US": "United States",
    "GB": "United Kingdom",
    "DE": "Germany",
    "VN": "Vietnam",
    "AT": "Austria",
    "BE": "Belgium",
    # ... ~200 total
}

# Reverse mapping for migration (native → English)
NATIVE_TO_ENGLISH = {
    "Deutschland": "Germany",
    "Việt Nam": "Vietnam",
    "Österreich": "Austria",
    "België / Belgique / Belgien": "Belgium",
    # Common variations
    "USA": "United States",
    "UK": "United Kingdom",
    # ... ~50-100 common variations
}
```

**Special Cases:**
- US variations: "USA", "United States of America" → "United States"
- UK variations: "Great Britain", "England" → "United Kingdom"
- Multi-language: Take English version or ISO default
- Territories: Puerto Rico, Guam, etc. → Map appropriately

---

### Phase 2: Update Cache Build Scripts

**File:** `CityData/build-international-cache.py`

**Changes:**
```python
# Import mapping
from country_names import ISO_TO_ENGLISH

# In geocode function (line ~163):
country_code = address.get('country_code', '').upper()
if country_code in ISO_TO_ENGLISH:
    country = ISO_TO_ENGLISH[country_code]
    print(f"  Mapped {country_code} → {country}")
else:
    # Fallback to native name
    country = address.get('country', country_name)
    print(f"  ⚠️  Unmapped code: {country_code}, using: {country}")
```

**File:** `CityData/build-city-cache.py`

Apply same logic for US cities (mostly "United States" already, but normalize variations)

---

### Phase 3: Rebuild Cache Files

**Commands:**
```bash
cd CityData
python build-international-cache.py  # ~1-2 hours
python build-city-cache.py           # ~20-30 minutes
./distribute-caches.sh               # Copy to all platforms
```

**Verification:**
```bash
# Check Germany cities
grep -A 3 '"Berlin"' international-cities-cached.json | grep country
# Expected: "country": "Germany"

# Check Vietnam cities
grep -A 3 '"Hanoi"' international-cities-cached.json | grep country
# Expected: "country": "Vietnam"

# Check for leftover native names (should be minimal/none)
grep -i "Deutschland\|Việt Nam\|Österreich" international-cities-cached.json
```

---

### Phase 4: iOS User Data Migration

**File:** `iOS/FastWeather/Utilities/CountryNames.swift` (NEW)

```swift
struct CountryNames {
    // ISO alpha-2 → English name
    static let isoToEnglish: [String: String] = [
        "US": "United States",
        "GB": "United Kingdom",
        "DE": "Germany",
        "VN": "Vietnam",
        // ... ~200 codes
    ]
    
    // Native name → English name (for migration)
    static let nativeToEnglish: [String: String] = [
        "Deutschland": "Germany",
        "Việt Nam": "Vietnam",
        "Österreich": "Austria",
        "USA": "United States",
        "UK": "United Kingdom",
        // ... ~50-100 variations
    ]
    
    // Try ISO code first, fallback to native name lookup
    static func normalize(_ name: String, code: String? = nil) -> String {
        if let code = code?.uppercased(), let english = isoToEnglish[code] {
            return english
        }
        return nativeToEnglish[name] ?? name  // Fallback to original
    }
}
```

**File:** `iOS/FastWeather/Services/WeatherService.swift`

```swift
// In init(), before loading cities
private func migrateCountryNamesIfNeeded() {
    let migrationKey = "countryNamesMigrated_v1"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else {
        print("✅ Country names already migrated")
        return
    }
    
    print("🔄 Migrating country names to English...")
    var migrated = 0
    
    // Create backup
    if let encoded = try? JSONEncoder().encode(savedCities) {
        UserDefaults.standard.set(encoded, forKey: "cities_backup_preMigration")
    }
    
    // Migrate each city
    for i in savedCities.indices {
        let oldCountry = savedCities[i].country
        let newCountry = CountryNames.nativeToEnglish[oldCountry ?? ""] ?? oldCountry
        
        if oldCountry != newCountry {
            savedCities[i].country = newCountry
            migrated += 1
            print("  \(savedCities[i].name): '\(oldCountry ?? "")' → '\(newCountry ?? "")'")
        }
    }
    
    // Save migrated cities
    saveCities()
    
    // Mark as migrated
    UserDefaults.standard.set(true, forKey: migrationKey)
    
    print("✅ Migration complete: \(migrated) cities updated")
    
    // Announce to VoiceOver
    if migrated > 0 {
        UIAccessibility.post(notification: .announcement, 
                            argument: "Updated country names for \(migrated) cities")
    }
}
```

**File:** `iOS/FastWeather/Services/WeatherService.swift` (geocoding)

Update `searchCity()` to normalize before saving:
```swift
// After getting placemark
let country = CountryNames.normalize(placemark.country ?? "Unknown", 
                                     code: placemark.isoCountryCode)
```

---

### Phase 5: macOS Implementation

Copy same logic as iOS:
- Create `FastWeatherMac/FastWeatherMac/Utilities/CountryNames.swift`
- Update `FastWeatherMac/FastWeatherMac/Services/WeatherService.swift`
- Same migration + geocoding normalization

---

### Phase 6: Web Implementation

**File:** `webapp/country-names.js` (NEW)

```javascript
const COUNTRY_NAMES = {
    ISO_TO_ENGLISH: {
        "US": "United States",
        "GB": "United Kingdom",
        "DE": "Germany",
        "VN": "Vietnam",
        // ... ~200 codes
    },
    
    NATIVE_TO_ENGLISH: {
        "Deutschland": "Germany",
        "Việt Nam": "Vietnam",
        // ... ~50-100 variations
    },
    
    normalize(name, code) {
        if (code) {
            const english = this.ISO_TO_ENGLISH[code.toUpperCase()];
            if (english) return english;
        }
        return this.NATIVE_TO_ENGLISH[name] || name;
    }
};
```

**File:** `webapp/app.js`

Update `geocodeCity()`:
```javascript
const country = COUNTRY_NAMES.normalize(
    address.country || '',
    address.country_code
);
```

**Migration:**
```javascript
function migrateCountryNames() {
    const migrationKey = 'countryNamesMigrated_v1';
    if (localStorage.getItem(migrationKey)) {
        console.log('✅ Country names already migrated');
        return;
    }
    
    console.log('🔄 Migrating country names...');
    const cities = JSON.parse(localStorage.getItem('cities') || '[]');
    
    // Backup
    localStorage.setItem('cities_backup', JSON.stringify(cities));
    
    let migrated = 0;
    cities.forEach(city => {
        const newCountry = COUNTRY_NAMES.normalize(city.country);
        if (city.country !== newCountry) {
            console.log(`  ${city.name}: '${city.country}' → '${newCountry}'`);
            city.country = newCountry;
            migrated++;
        }
    });
    
    localStorage.setItem('cities', JSON.stringify(cities));
    localStorage.setItem(migrationKey, 'true');
    console.log(`✅ Migration complete: ${migrated} cities updated`);
}

// Call on app load
migrateCountryNames();
```

---

### Phase 7: Python Implementation

**File:** `country_names.py` (NEW, in root directory)

Same structure as Python cache version

**File:** `fastweather.py`

```python
from country_names import ISO_TO_ENGLISH, NATIVE_TO_ENGLISH

# In MainWindow.__init__(), before load_cities()
def migrate_country_names(self):
    migration_key = "countryNamesMigrated_v1"
    
    # Check if already migrated (store in city.json metadata)
    if self.city_data.get('_metadata', {}).get(migration_key):
        print("✅ Country names already migrated")
        return
    
    print("🔄 Migrating country names to English...")
    
    # Backup
    import shutil
    shutil.copy('city.json', 'city.json.backup')
    
    migrated = 0
    for city in self.city_data.get('cities', []):
        old_country = city.get('country', '')
        new_country = NATIVE_TO_ENGLISH.get(old_country, old_country)
        
        if old_country != new_country:
            print(f"  {city['name']}: '{old_country}' → '{new_country}'")
            city['country'] = new_country
            migrated += 1
    
    # Mark as migrated
    if '_metadata' not in self.city_data:
        self.city_data['_metadata'] = {}
    self.city_data['_metadata'][migration_key] = True
    
    # Save
    self.save_cities()
    print(f"✅ Migration complete: {migrated} cities updated")

# In geocode function
country_code = address.get('country_code', '').upper()
country = ISO_TO_ENGLISH.get(country_code, address.get('country', ''))
```

---

## Testing Strategy

### Pre-Migration Testing
1. **Backup verification:**
   - iOS: Check UserDefaults has "cities_backup_preMigration"
   - Web: Check localStorage has "cities_backup"
   - Python: Verify city.json.backup exists
2. **Add test cities with native names manually** (simulate old data)

### Migration Testing
1. **Run migration:**
   - Launch app with native-named cities
   - Verify console logs show correct mapping
   - Check all cities updated to English names
2. **Verify idempotency:**
   - Relaunch app
   - Migration should NOT run again (check for flag)
3. **Check edge cases:**
   - City with unmapped country → keeps original name
   - City already in English → no change

### Post-Migration Testing
1. **Add new city:**
   - Search "Munich, Germany"
   - Should save as "Munich, Bavaria, Germany" (not "Deutschland")
2. **Cross-platform consistency:**
   - Add same city on iOS, Web, Python
   - Compare display names → all should be English
3. **VoiceOver:**
   - Navigate city list
   - Verify English country names announced correctly
4. **Cache verification:**
   - Browse Cities by country
   - Verify all cities load with English country names

---

## Rollout Plan

### Stage 1: Web First (Lowest Risk)
- Implement mapping + migration
- Test with small user group
- Easy to rollback (just clear localStorage)

### Stage 2: iOS
- Ship with app update
- Monitor crash reports for migration issues
- Can push hotfix if needed

### Stage 3: macOS
- Same as iOS (shares code)

### Stage 4: Python
- Standalone desktop app
- Lowest priority (smallest user base)

---

## Risk Mitigation

### Data Loss Prevention
✅ **Automatic backup before migration**
✅ **Idempotent migration** (safe to re-run)
✅ **Graceful fallback** (unmapped → keep original)
✅ **Version flag** (can run migration v2 later if needed)

### Performance
✅ **O(1) dictionary lookup** (hash table)
✅ **Runs once on first launch** (not on every app start)
✅ **<100ms for typical user** (10-20 cities)

### User Impact
✅ **Transparent migration** (happens before UI appears)
✅ **Progressive enhancement** (works without cache rebuild)
✅ **Recovery path** (users can delete/re-add cities)

### Code Quality
✅ **Centralized mapping** (single source of truth)
✅ **Platform-specific implementations** (idiomatic to each)
✅ **Extensive logging** (for debugging migration issues)
✅ **Unit testable** (mapping logic isolated)

---

## Success Metrics

**After implementation:**
- [ ] Cache files contain 0 instances of "Deutschland", "Việt Nam", "Österreich"
- [ ] Cache files contain "Germany", "Vietnam", "Austria" instead
- [ ] User data migrated on first launch (check logs)
- [ ] New cities added with English names (live geocoding)
- [ ] VoiceOver reads English country names
- [ ] Cross-platform consistency (same city = same display name)
- [ ] Migration flag prevents re-running
- [ ] Backup files created successfully
- [ ] No crashes during migration
- [ ] <100ms migration time for typical users

---

## Maintenance Plan

**Future Updates:**
- Add new ISO codes as countries change (rare)
- Add common native name variations as discovered
- Consider localization (user language preference) in future version

**Monitoring:**
- Log unmapped country codes in production
- Track migration completion rate
- Monitor VoiceOver feedback on pronunciation

---

## Rollback Plan

**If migration fails:**
1. **iOS/Mac:** Restore from "cities_backup_preMigration" in UserDefaults
2. **Web:** Restore from "cities_backup" in localStorage
3. **Python:** Copy city.json.backup → city.json

**If mapping incomplete:**
1. Update mapping file only (no code changes)
2. Reset migration flag: `countryNamesMigrated_v1` → false
3. Re-run migration on next launch

**Nuclear option:**
1. User deletes all cities
2. Re-adds from Browse or Search
3. Gets fresh English names from cache/API

---

## Files Changed

### New Files
- `CityData/country_names.py`
- `iOS/FastWeather/Utilities/CountryNames.swift`
- `FastWeatherMac/FastWeatherMac/Utilities/CountryNames.swift`
- `webapp/country-names.js`
- `country_names.py` (root, for Python app)

### Modified Files
- `CityData/build-international-cache.py`
- `CityData/build-city-cache.py`
- `iOS/FastWeather/Services/WeatherService.swift`
- `FastWeatherMac/FastWeatherMac/Services/WeatherService.swift`
- `webapp/app.js`
- `fastweather.py`

### Data Files (Rebuilt)
- `international-cities-cached.json` (~17,000 cities)
- `us-cities-cached.json` (~2,500 cities)
- Copies in: `iOS/`, `FastWeatherMac/`, `webapp/`, `CityData/`

---

## Timeline Estimate

| Phase | Duration | Can Run in Parallel |
|-------|----------|---------------------|
| Create mapping files | 30 min | - |
| Update cache scripts | 20 min | Yes (with mapping) |
| Rebuild caches | 2 hours | Yes (background task) |
| iOS implementation | 45 min | Yes (while cache builds) |
| iOS testing | 30 min | - |
| macOS implementation | 30 min | Yes (copy iOS logic) |
| Web implementation | 45 min | - |
| Python implementation | 45 min | - |
| Final testing | 1 hour | - |
| **Total** | **~6 hours** | **~4 hours with parallelization** |

---

## Decision Log

**Decision:** Use ISO country codes instead of `accept-language` header  
**Rationale:** More reliable, faster, consistent across OSM data quality  
**Date:** Feb 7, 2026

**Decision:** Automatic migration instead of manual user action  
**Rationale:** Better UX, prevents inconsistency between old/new cities  
**Date:** Feb 7, 2026

**Decision:** Rebuild caches with English names instead of runtime-only translation  
**Rationale:** Performance (no lookup), consistency, matches source of truth  
**Date:** Feb 7, 2026

**Decision:** Graceful fallback (keep native name if unmapped)  
**Rationale:** Preserve data rather than show "Unknown", better than failure  
**Date:** Feb 7, 2026

---

## Approved By

- Kelly Ford - February 7, 2026

**Implementation Status:** Ready to proceed (iOS first, then staged rollout)
