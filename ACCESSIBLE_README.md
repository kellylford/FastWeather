# FastWeather - Accessible GUI Weather Application

A fully accessible weather application built with PyQt5 that provides comprehensive screen reader support, complete keyboard navigation, and an intuitive interface for managing weather data across multiple cities.

## Why This Version is Truly Accessible

Unlike many GUI frameworks, this PyQt5 implementation provides:

- **Full Screen Reader Support**: Compatible with NVDA, JAWS, Narrator, VoiceOver, and Orca
- **Complete Keyboard Navigation**: Every feature accessible without a mouse
- **Proper Focus Management**: Logical tab order and clear focus indicators
- **Accessibility Attributes**: Proper labels, descriptions, and roles for assistive technology
- **High Contrast Support**: Respects system accessibility settings
- **Standard Shortcuts**: Uses familiar Windows/accessibility conventions

## Features

### Core Weather Functionality
- **Current Weather**: Real-time temperature, conditions, and wind information
- **Detailed Forecasts**: 12-hour and 7-day weather predictions
- **Multiple Cities**: Manage unlimited cities with persistent storage
- **Auto-Geocoding**: Automatic coordinate lookup for cities worldwide
- **Free API**: Uses Open-Meteo (no API key required)

### Accessibility Features
- **Screen Reader Announcements**: Status updates and weather data properly announced
- **Keyboard Shortcuts**: Industry-standard shortcuts for common actions
- **Contextual Help**: F1 help dialog with complete usage instructions
- **Error Handling**: Clear, accessible error messages with helpful suggestions
- **Focus Indicators**: Visual and programmatic focus management
- **Resizable Interface**: Adjustable layout for different screen sizes and zoom levels

## Installation

### Requirements
- Python 3.6 or higher
- PyQt5 (for accessible GUI framework)
- requests (for API calls)

### Quick Setup
1. **Clone or download** the weather application files
2. **Install dependencies**:
   ```bash
   pip install PyQt5 requests
   ```
3. **Run the application**:
   ```bash
   python accessible_weather_gui.py
   ```

### Virtual Environment (Recommended)
```bash
# Create virtual environment
python -m venv weather_env

# Activate it
# Windows:
weather_env\Scripts\activate
# macOS/Linux:
source weather_env/bin/activate

# Install dependencies
pip install PyQt5 requests

# Run the app
python accessible_weather_gui.py
```

## Usage Guide

### Getting Started
1. **Launch the app** - The application opens with focus on the city input field
2. **Add your first city** - Type a city name, zip code, or location and press Enter
3. **Select cities** - Use arrow keys to navigate your city list
4. **View weather** - Basic weather appears automatically; press Enter for full details

### Interface Layout

The application has three main sections:

#### 1. City Input (Top)
- **Input field**: Type city names, zip codes, or locations
- **Add button**: Click or press Enter to add cities
- **Supports**: "Madison", "53703", "London, UK", "Tokyo, Japan"

#### 2. City Management (Left Panel)
- **City list**: Your saved cities with arrow key navigation
- **Remove button**: Delete selected cities from your list
- **Refresh button**: Update weather for selected city
- **Full Weather button**: Open detailed forecast window

#### 3. Weather Display (Right Panel)
- **Current weather**: Automatically displays when you select a city
- **Temperature**: Shows in both Fahrenheit and Celsius
- **Conditions**: Clear descriptions of weather conditions
- **Wind information**: Speed and direction
- **Update time**: When the data was last refreshed

### Keyboard Navigation

#### Primary Shortcuts
| Key | Action |
|-----|--------|
| **F1** | Show help dialog with all shortcuts |
| **F5** or **Ctrl+R** | Refresh weather for selected city |
| **Ctrl+D** | Remove selected city |
| **Ctrl+N** | Focus on city input field |
| **Enter** | Add city (from input) or show full weather (from list) |

#### Navigation Keys
| Key | Action |
|-----|--------|
| **Tab** | Move to next control |
| **Shift+Tab** | Move to previous control |
| **Arrow Keys** | Navigate city list |
| **Space** | Activate buttons and checkboxes |
| **Escape** | Close dialogs |

### Adding Cities

The application supports multiple input formats:

#### US Locations
- **City names**: "Madison", "Portland", "Miami"
- **City, State**: "Madison, WI", "Portland, OR", "Miami, FL"  
- **Zip codes**: "53703", "97201", "33101"

#### International Locations
- **City, Country**: "London, UK", "Paris, France", "Tokyo, Japan"
- **Full names**: "London, England, United Kingdom"
- **Major cities**: Often work with just the name

#### Smart Disambiguation
When multiple cities match your input, the app shows a selection dialog:
- Use arrow keys to navigate options
- Each option shows city, state/region, country, and coordinates
- Press Enter or click Select to choose
- Press Escape or Cancel to abort

### Weather Information

#### Basic Weather (Auto-displayed)
- **Temperature**: Current temp in °F and °C
- **Conditions**: Clear description (e.g., "Clear sky", "Light rain")
- **Wind**: Speed in mph and cardinal direction
- **Update time**: When data was last fetched
- **Instructions**: Guidance for accessing full weather

#### Full Weather (Detailed Window)
Opens in a separate window with:
- **Current conditions**: Detailed current weather
- **12-hour forecast**: Hourly breakdown with temperature, humidity, precipitation, wind
- **7-day forecast**: Daily highs/lows, sunrise/sunset, precipitation totals
- **Formatted display**: Easy-to-read monospaced font layout

### City Management

#### Removing Cities
1. Select the city in your list (arrow keys)
2. Press Ctrl+D or click "Remove City"
3. Confirm removal in the dialog
4. City is permanently removed from your list

#### Refreshing Weather
- **Selected city**: Press F5, Ctrl+R, or click "Refresh Weather"
- **Automatic refresh**: Weather updates when you select different cities
- **Error handling**: Clear messages if refresh fails

## Accessibility Details

### Screen Reader Support

#### Proper Labeling
- All controls have descriptive accessible names
- Context-sensitive descriptions explain purpose and usage
- Status updates are announced as they occur
- Error messages are clearly presented with helpful suggestions

#### Content Structure
- Logical heading structure for navigation
- Grouped related controls (city input, city list, weather display)
- Proper list semantics for city navigation
- Clear dialog structure for city selection

#### Announcements
- Weather updates announced when city selection changes
- Status bar updates for background operations
- Error messages with specific guidance
- Success confirmations for added/removed cities

### Keyboard Accessibility

#### Complete Keyboard Access
- Every feature accessible without a mouse
- Logical tab order through all controls
- Standard shortcuts for common operations
- Escape key handling for dialogs

#### Focus Management
- Clear visual focus indicators
- Focus returns to logical positions after dialogs
- Initial focus on city input for immediate use
- Focus trapped appropriately in modal dialogs

### Visual Accessibility

#### High Contrast Support
- Respects system high contrast settings
- Uses system colors for compatibility
- Proper color contrast ratios
- No reliance on color alone for information

#### Scalability
- Fonts scale with system accessibility settings
- Interface elements resize appropriately
- Scrollable areas for varying screen sizes
- Resizable splitter for custom layout

## Data Storage

### City Database
Cities are stored in `city.json` in the same directory:
```json
{
    "Madison, Wisconsin, United States": [43.074761, -89.3837613],
    "London, England, United Kingdom": [51.5074456, -0.1277653],
    "Tokyo, Tokyo, Japan": [35.6762, 139.6503]
}
```

### Compatibility
- Compatible with the command-line version's city database
- Automatic backup and recovery of city data
- Graceful handling of corrupted or missing files
- Cross-platform file storage

## Error Handling

### Network Issues
- **Connection problems**: Clear error messages with retry suggestions
- **Timeout handling**: 10-second timeouts with user notification
- **Service unavailable**: Helpful guidance for temporary outages
- **Rate limiting**: Automatic handling with user feedback

### Input Validation
- **Invalid cities**: Suggestions for correct spelling or format
- **Ambiguous input**: Disambiguation dialogs with multiple options
- **Empty input**: Helpful prompts for valid input formats
- **Duplicate cities**: Prevention with clear user notification

### Application Errors
- **File permissions**: Guidance for resolving save/load issues
- **Missing data**: Graceful fallbacks with user notification
- **Thread errors**: Background operation error handling
- **Memory issues**: Cleanup and recovery procedures

## Technical Implementation

### Architecture
- **Main thread**: GUI and user interaction
- **Background threads**: Network requests (geocoding and weather)
- **Thread-safe updates**: All GUI updates on main thread
- **Proper cleanup**: Thread management and resource cleanup

### APIs and Services
- **Open-Meteo**: Free weather data (no API key required)
- **Nominatim**: OpenStreetMap geocoding service
- **Timeout handling**: 10-second timeouts for all requests
- **Error recovery**: Automatic retry logic for transient failures

### Accessibility Implementation
- **PyQt5 accessibility**: Native OS accessibility integration
- **Proper semantics**: Correct widget types and properties
- **Focus management**: Programmatic focus control
- **Screen reader testing**: Tested with multiple assistive technologies

## Troubleshooting

### Common Issues

#### Application Won't Start
- **Missing PyQt5**: Install with `pip install PyQt5`
- **Python version**: Requires Python 3.6 or higher
- **Virtual environment**: Ensure proper activation
- **System dependencies**: May need system Qt5 libraries

#### Network Problems
- **No internet**: Check connection for geocoding and weather
- **Firewall blocking**: Ensure access to api.open-meteo.com and nominatim.openstreetmap.org
- **Proxy issues**: May need proxy configuration
- **DNS problems**: Try using IP addresses if DNS fails

#### Accessibility Issues
- **Screen reader not working**: Ensure PyQt5 accessibility is enabled
- **Focus problems**: Try restarting the application
- **Keyboard shortcuts not working**: Check for conflicting system shortcuts
- **High contrast not working**: Verify system accessibility settings

### Performance Tips
- **City limit**: No technical limit, but 50+ cities may slow startup
- **Weather caching**: Basic weather is briefly cached to reduce API calls
- **Network optimization**: Requests are made only when needed
- **Memory usage**: Application cleans up background threads automatically

### Getting Help
- **F1 key**: In-app help with all shortcuts and usage instructions
- **Status bar**: Real-time feedback on current operations
- **Error dialogs**: Specific guidance for resolving issues
- **Logs**: Console output for debugging (if run from terminal)

## Platform Compatibility

### Operating Systems
- **Windows**: Full accessibility support with Narrator, NVDA, JAWS
- **macOS**: VoiceOver compatibility and native integration
- **Linux**: Orca screen reader support and system integration

### Python Versions
- **Python 3.6+**: Minimum required version
- **Python 3.8-3.12**: Fully tested and supported
- **Latest Python**: Generally compatible with newest versions

### Dependencies
- **PyQt5**: 5.12 or higher recommended
- **requests**: 2.20 or higher
- **System Qt5**: Required on some Linux distributions

## Development and Customization

This application is designed to be maintainable and extensible:

### Code Structure
- **Modular design**: Separate classes for different responsibilities
- **Threading model**: Clean separation of UI and network operations
- **Error handling**: Comprehensive error management throughout
- **Documentation**: Well-commented code with clear function purposes

### Extending Functionality
- **Additional weather data**: Easy to add more Open-Meteo parameters
- **Export features**: Framework for adding data export capabilities
- **Theming**: PyQt5 style sheets for custom appearances
- **Localization**: Structure supports multiple languages

### Accessibility Standards
- **WCAG 2.1**: Follows Web Content Accessibility Guidelines principles
- **Platform guidelines**: Adheres to OS-specific accessibility standards
- **Assistive technology**: Tested with multiple screen readers and tools
- **User feedback**: Designed based on accessibility user testing

---

This accessible weather application demonstrates that with proper framework choice and implementation, GUI applications can be fully accessible to users with disabilities while maintaining excellent usability for all users.
