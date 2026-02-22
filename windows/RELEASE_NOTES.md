# FastWeather Release Notes

## Version 1.1 - November 28, 2025

### New Features

#### Precipitation Configuration & Display
- **Configurable Precipitation Details**: Added options to show/hide snowfall, rain, and showers in Current, Hourly, and Daily weather sections
- **Snow Depth**: Added snow depth display in Current weather (shows total accumulated snow on the ground)
- **At-a-Glance Precipitation Indicators**: City list now shows `[Snow]` or `[Rain]` indicators when precipitation is occurring
- **Improved Precision**: Changed precipitation thresholds to show trace amounts (≥0.01mm) instead of only larger amounts
- **Smart Display**: Shows "None" for zero values when precipitation options are enabled

#### Unit Configuration System
- **Temperature Units**: Choose between Fahrenheit (°F) and Celsius (°C)
- **Wind Speed Units**: Choose between mph and km/h
- **Precipitation Units**: Choose between inches (in) and millimeters (mm)
- **Persistent Preferences**: Unit settings are saved and applied across all weather displays
- **New Units Tab**: Added dedicated Units configuration tab in the settings dialog

#### Enhanced User Experience
- **Apply Button**: Configuration dialog now includes an Apply button to preview changes without closing the dialog
- **24-Hour Forecast**: Extended hourly forecast from 12 to 24 hours for better planning
- **Configure Button on Main View**: Quick access to configuration settings from the main screen

#### Improved Accessibility
- **New Keyboard Shortcuts**:
  - `Alt+N`: Focus the new city input field
  - `Alt+C`: Open configuration dialog
  - `Alt+F`: View full weather report
- **Enter Key Support**: Pressing Enter in city search results now selects the city
- **Text-Based Indicators**: Precipitation indicators use accessible text (`[Snow]`, `[Rain]`) instead of emoji symbols

### Technical Improvements
- Unit conversion system with helper methods throughout the application
- Enhanced configuration merge logic to handle new settings gracefully
- Improved precipitation data display across all views
- Better integration between configuration changes and live data refresh

### Documentation
- Updated USER_GUIDE.md with complete keyboard shortcut reference
- Added documentation for new precipitation and unit configuration features

---

## Version 1.0 - Initial Release

Initial release of FastWeather with core features:
- Current weather conditions display
- Hourly and daily forecasts
- Multiple city management
- Basic weather configuration options
- Accessible interface with screen reader support
- Keyboard navigation
- No API key required (uses Open-Meteo API)
