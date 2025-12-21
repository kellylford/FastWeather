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
- `us-cities-data.js` - Data file containing 50 cities for each U.S. state
- `styles.css` - Enhanced CSS with styling for state selector and add buttons
- `README.md` - This documentation file

### Technical Details

**Caching System**: To provide fast loading times, city coordinates are pre-cached in `us-cities-cached.json`. This eliminates the need for slow geocoding API calls.

- **With Cache**: Loads 20 cities with weather in ~5 seconds
- **Without Cache**: Would take ~22 seconds due to API rate limits

**Current Status**:
- ✅ Wisconsin: 20 cities cached
- ⏳ Other states: Use `build-city-cache.py` to generate

**Building the Complete Cache**:
```bash
# Install requirements
pip install requests

# Run the cache builder (takes ~2 hours for all 50 states)
python build-city-cache.py
```

The script:
- Geocodes all 2,500 cities across 50 states
- Saves progress after each state
- Can resume if interrupted
- Respects API rate limits (1 req/sec)

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
