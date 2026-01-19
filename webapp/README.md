# FastWeather Testing - State City Browser Feature

This testing directory contains an enhanced version of the FastWeather web application with a new feature for browsing cities by U.S. state.

## New Features

### State City Browser
- **State Selector**: A dropdown menu listing all 50 U.S. states
- **Choose State Button**: Loads 50 cities for the selected state
- **City Display**: Shows cities in the current view mode (Flat, Table, or List)
- **Add to My Cities**: Each displayed city has a button to add it to your personal city list

### How to Use

1. Open `index.html` in a web browser
2. Scroll to the "Browse Cities by State" section
3. Select a state from the dropdown menu
4. Click "Choose State"
5. Browse through 50 cities for that state
6. Click "Add to My Cities" button on any city to add it to your personal weather tracking list

### View Modes

The state cities are displayed in the same view mode as your saved cities:
- **Flat View**: Card-based layout with full city details
- **Table View**: Compact table format
- **List View**: Dense list format with keyboard navigation

### Files

- `index.html` - Enhanced HTML with state selector section
- `app.js` - JavaScript with state selection and city rendering logic
- `us-cities-cached.json` - Pre-cached coordinates for 2,500 U.S. cities (all 50 states)
- `international-cities-cached.json` - Pre-cached coordinates for 67 countries
- `styles.css` - Enhanced CSS with styling for state selector and add buttons
- `README.md` - This documentation file

### Technical Details

**Caching System**: To provide fast loading times, city coordinates are pre-cached in JSON files. This eliminates the need for slow geocoding API calls.

- **With Cache**: Loads 20 cities with weather in ~5 seconds
- **Without Cache**: Would take ~22 seconds due to API rate limits

**Current Coverage**:
- ✅ United States: All 50 states (50 cities each = 2,500 total)
- ✅ International: 67 countries (~20 cities each = 1,340 total)

**Managing City Data**:

All geocoding scripts and source data have been moved to the centralized `CityData/` directory. To update or rebuild the cache files:

```bash
cd ../CityData

# Set up environment (first time only)
quick-start.bat

# Rebuild caches if needed
venv\Scripts\activate
python build-city-cache.py              # US cities (~2 hours)
python build-international-cache.py     # International (~40-50 min)

# Distribute updated caches to all platforms
distribute-caches.bat
```

See `../CityData/README.md` for complete documentation.

## Accessibility

The new feature maintains WCAG 2.2 AA compliance:
- Proper ARIA labels and roles
- Keyboard navigation support
- Screen reader announcements
- Focus management
- High contrast mode support

## Future Enhancements

Potential improvements for this feature:
- Caching geocoded city data to reduce API calls
- Filtering cities by population or region
- Bulk add functionality
- Search within state cities
