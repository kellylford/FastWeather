# FastWeather iOS User Guide

**Your accessible, feature-rich weather companion**

---

## Getting Started

Add cities to track their weather:

- Activate the **+** (Add City) button on the My Cities tab
- Enter a city name or ZIP code
- Select from search results
- Or browse cities by state/country

---

## My Cities Tab

View and manage your saved cities:

- **Swipe left** on a city to remove it, or use the **VoiceOver actions menu**
- **Activate** a city to see detailed weather
- **Pull down** to refresh all cities
- Change view: **List** or **Flat** cards

---

## Browse Cities

Discover weather in new locations:

- Browse by **U.S. States** or **International** countries
- Navigate through states/countries → cities
- View weather without adding to your list
- Activate the **+** (Add City) button to add interesting cities

---

## Weather in Time

Weather in Time is aimed at answering the question about tomorrow's weather with a bit of a different approach. It will show you the conditions for all cities in your city list for the same time of day on the previous or next seven days.

### Navigating Through Dates

- **VoiceOver users:** Use the **three-finger swipe left or right** gestures to move between days
- **Sighted users:** Use the **left and right arrow buttons** at the top of the screen to navigate between days
- Both methods work for moving backward (earlier dates) or forward (future dates) by one day at a time

### Return to Today

- Activate the **Return to Today** button located at the top of the My Cities screen
- This button appears when viewing any date other than today
- Instantly returns all cities to current day's weather

### Important Background Behavior

⚠️ **The app does NOT automatically revert back to today when it goes to the background. It only resets to today when you completely close and reopen the app. If the weather looks incorrect, check which day you're viewing at the top of the screen.**

### How It Works

- **City list shows weather for the selected date** - All cities update together when you change dates
- **City detail view matches the selected date** - Opening a city shows details for the day you're viewing
- **Date range:** 7 days in the past to 7 days in the future
- **Same time each day** - See consistent comparisons across dates

---

## Marine Forecast

View tidal and marine conditions for coastal cities over the next 24 hours. This feature is useful for planning beach trips, boating, surfing, or understanding coastal weather patterns.

### What's Included

- **Sea Level Height** - Tidal information showing water level changes throughout the day
- **Wave Height** - Current and forecasted wave conditions
- **Wave Direction** - Direction waves are coming from
- **Wave Period** - Time between wave crests
- **Sea Surface Temperature** - Current water temperature
- **Swell Wave Height** - Long-period wave conditions
- **Ocean Current Velocity** - Speed of ocean currents
- Additional detailed metrics available in settings

### Accessing Marine Forecast

- Open any city's detail view
- Scroll to the **Marine Forecast** section
- Section appears when enabled in Settings → Detail Categories
- Displays 24-hour forecast starting from current time

### Customization

- Go to Settings → Marine Forecast to customize which marine fields are displayed
- Reorder marine fields by dragging
- Enable/disable individual data points based on your needs
- Marine Forecast can be hidden entirely in Settings → Detail Categories

**Note:** Marine forecast data is available for coastal locations. Inland cities may show limited or no marine data. Sea Level Height (tidal data) is enabled by default and shown first in the marine section.

---

## City Detail View

Explore comprehensive weather information:

- **Current conditions** with temperature, humidity, wind
- **Hourly forecast** for next 24 hours
- **Daily forecast** for 16 days
- **Marine forecast** for coastal locations (if enabled)
- **Actions menu** for historical data and more
- **Weather alerts** when active (U.S. and select international locations)

### Weather in Time Integration

All weather details in this view are based on the date you've selected using Weather in Time. If you're viewing tomorrow's weather in your city list, opening a city's detail view will show tomorrow's forecast, not today's.

---

## Actions Menu

Access additional features from city detail:

- **Refresh** - Update weather data
- **View Historical Weather** - See past weather data
- **Expected Precipitation** - Rainfall forecast (if enabled)
- **Weather Around Me** - Regional weather comparison (if enabled)
- **Remove City** - Delete from your list

---

## Weather Around Me

See weather in cities around you in all directions. This feature helps you understand regional weather patterns and plan trips.

### What You'll See

- **Regional Overview** - Weather in 8 directions (N, NE, E, SE, S, SW, W, NW)
- **Distance** - How far each city is from your selected city
- **Current Weather** - Temperature and conditions for each city

### Exploring Along a Direction

Tap any direction to explore cities along that path. For example, tap "North" to see all cities north of your location.

- **Pick a Direction** - Choose N, NE, E, SE, S, SW, W, or NW from the picker
- **Navigate Cities** - Swipe up for cities farther away, swipe down for closer cities
- **Visual Buttons** - Use "Closer" and "Farther" buttons to move between cities
- **View All** - Tap "List All" to see all cities in that direction at once

### First Time Loading

Finding cities along a direction may take 10-20 seconds the first time, but results are cached for instant access next time. The app searches every 10 miles along your chosen direction to find nearby cities.

### Tips

- Increase "Max Distance" in settings to see cities farther away
- Use VoiceOver swipe gestures to quickly explore city by city
- Weather data is prefetched as you navigate for smooth scrolling

---

## Historical Weather

Explore weather from the past:

- **Single Day** - View specific date's weather
- **Multi-Year** - Compare across years
- **Daily Browse** - Scroll through month view
- Data available back to 1940 for most locations

---

## Settings

Customize your experience:

- **Units** - °F/°C, mph/km/h, inches/mm
- **View Mode** - List or Flat cards
- **Display Mode** - Condensed or Expanded
- **Weather Fields** - Show/hide and reorder
- **Detail Categories** - Customize detail view

---

## Icons & Graphics

Visual icons used throughout the app with VoiceOver equivalents:

### Tab Bar Icons

- **List icon** - My Cities tab (VoiceOver: "My Cities")
- **Magnifying glass** - Browse tab (VoiceOver: "Browse Cities")
- **Gear** - Settings tab (VoiceOver: "Settings")

### Weather Condition Icons

- **Sun** - Clear sky (VoiceOver: condition name)
- **Cloud with sun** - Partly cloudy
- **Cloud** - Overcast
- **Cloud with rain** - Rain
- **Cloud with snow** - Snow
- **Cloud with lightning** - Thunderstorm
- **Fog cloud** - Fog or mist

VoiceOver announces: "Weather condition: [description]"

### Weather Alert Icons

- **Filled warning triangle** - Extreme/Severe/Moderate alerts (red/orange/yellow)
- **Filled circle with exclamation** - Minor alerts (blue)
- **Circle with exclamation** - Unknown severity (gray)

VoiceOver announces: "Weather alert: [event name]" with severity level

### Action & Navigation Icons

- **Plus circle** - Add city (VoiceOver: "Add City")
- **Circular arrows** - Refresh (VoiceOver: "Refresh" or "Refresh weather")
- **Three dots circle** - Actions menu (VoiceOver: "Actions")
- **Chevron right** - Navigate forward (VoiceOver: included in item name)
- **Chevron down** - Expand menu (VoiceOver: "[State/Country name]")
- **Map pin** - Location/browse (VoiceOver: "Browse by state or country")
- **Book** - User guide (VoiceOver: "User Guide")
- **Hammer** - Developer settings (VoiceOver: "Developer Settings")

### Data Visualization Icons

- **Droplet** - Precipitation amount (VoiceOver: "Precipitation: [amount]")
- **Up arrow** - High temperature (VoiceOver: "High: [temperature]")
- **Down arrow** - Low temperature (VoiceOver: "Low: [temperature]")
- **Compass arrows** - Wind direction (VoiceOver: "Wind from [direction]")
- **Clock** - Time/timestamp (VoiceOver: formatted time)
- **Calendar with clock** - Historical weather (VoiceOver: "View historical weather")

### Status Icons

- **Warning triangle** - Error or unavailable (VoiceOver: describes issue)
- **Checkmark** - Selected item (VoiceOver: "Selected")
- **Sort arrows** - Reorder indicator (VoiceOver: "Reorder" or drag hint)

### Important Note on Icons

⚠️ **All icons are decorative only. VoiceOver users receive full information through text labels and announcements. You never need to see icons to use the app.**

### Expected Precipitation Timeline

The Expected Precipitation feature displays a visual timeline showing precipitation forecasts for each time interval. This timeline is visible on screen for sighted users but is hidden from VoiceOver. The same data is available through the audio graph below the timeline, which provides both audio tones (representing precipitation intensity) and individual data points you can explore by swiping. The audio graph format is more efficient for non-visual exploration than reading through a long list of time entries.

---

## Accessibility

FastWeather is designed for VoiceOver users:

- **Complete VoiceOver support** - All features accessible
- **Descriptive labels** - Clear, context-aware announcements
- **Logical navigation** - Efficient screen reader flow
- **Dynamic Type** - Text scales with system settings
- **High contrast** - Readable in all conditions

---

## Keyboard Shortcuts

Use external keyboard shortcuts for faster navigation (iPad with keyboard):

### General

- **⌘⇧N** - Add new city

More keyboard shortcuts will be added in future updates.

---

## Tips & Tricks

- **Reorder weather fields** in Settings → Weather Fields
- **Drag to reorder** detail categories in Settings
- **Activate** a city in browse to view without adding
- **Pull to refresh** works on all city lists
- **Swipe actions** or **VoiceOver actions menu** available in List view
- **Historical years** can be configured in Settings

---

## Weather Data

FastWeather uses reliable, free data sources:

- **Open-Meteo** - Current and forecast weather
- **Historical Archive** - Weather back to 1940
- **NWS Alerts** - U.S. weather warnings (when available)
- **OpenStreetMap** - City geocoding

No API keys required. No data tracking.

---

## Need More Help?

FastWeather is designed to be intuitive. Explore the app and discover features as you use it. Most actions are available through standard iOS gestures and VoiceOver commands.

---

*This user guide corresponds to the in-app User Guide accessible from Settings.*
