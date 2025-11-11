# FastWeather# FastWeather



A fast, accessible weather application that provides current conditions and detailed forecasts without the clutter.A command-line and GUI weather application that fetches current weather and forecasts for cities using the Open-Meteo API. Features both a powerful CLI interface and a fully accessible PyQt5 GUI with screen reader support.



## Why FastWeather?## Applications Included



Get weather fast. No ads, no tracking, no distractions. Just the weather you need, when you need it.- **fastweather.py**: Full-featured command-line interface

- **accessible_weather_gui.py**: Accessible PyQt5 GUI application

## Features

## Features

- **Fast & Simple** - Current weather at a glance, detailed forecasts on demand

- **Multiple Cities** - Track weather for as many locations as you want- **Current Weather**: Temperature, wind speed/direction, weather conditions

- **Comprehensive Data** - Temperature, feels-like, humidity, wind, precipitation, UV index, visibility, cloud cover, and more- **Hourly Forecasts**: Next 5 hours with detailed information

- **Accessible** - Fully compatible with screen readers and keyboard navigation- **Daily Forecasts**: Up to 7 days with high/low temperatures, sunrise/sunset, precipitation

- **No API Key Required** - Uses the free Open-Meteo weather service- **Multiple Cities**: Manage and query multiple cities

- **Privacy First** - No tracking, no analytics, your cities stored locally- **Interactive Mode**: User-friendly prompts for city selection

- **Non-Interactive Mode**: Command-line arguments for automation

## Quick Start- **City Management**: Add, delete, and reorder cities

- **HTML Export**: Generate weather reports in HTML format

### Running from Python- **Automatic Geocoding**: Look up city coordinates automatically



1. Install Python 3.8 or later## Installation

2. Install dependencies:

   ```bash### Requirements

   pip install -r requirements.txt- Python 3.6 or higher

   ```- `requests` library

3. Run the application:

   ```bash### Setup

   python fastweather.py1. Install the required dependency:

   ```   ```bash

   pip install requests

### Running the Executable (Windows)   ```



1. Download the latest release2. Download the `fastweather.py` script to your desired directory.

2. Extract the ZIP file

3. Run `FastWeather.exe`## Usage



## Usage### Quick Start



### Adding Cities**Get current temperature for all cities (one line each):**

```bash

1. Type a city name in the search box (e.g., "Seattle", "New York, NY", "London, UK")python fastweather.py

2. Press Enter or click "Search"```

3. Select your city from the results

4. The city will be added to your list with current weather### Command Line Options



### Viewing Weather| Option | Description | Default |

|--------|-------------|---------|

- **City List**: Shows temperature and current sky conditions for each city| `--detail` | Level of detail: `full`, `basic`, or `temps` | `full` |

- **Full Weather**: Double-click a city or select and press Enter for:| `--city` | Specify a city name, or use `all`, `list`, or `configure` | None |

  - Current conditions with all available data| `--city-file` | Path to JSON file with city coordinates | `city.json` |

  - 12-hour forecast| `--days` | Number of forecast days (1-7) | `7` |

  - 7-day forecast| `--debug` | Show debug information including weather codes | `False` |

- **Refresh**: Click "Refresh All" or press F5 to update all cities| `--quiet` | Suppress non-error output | `False` |

| `--html` | Export weather report to HTML file | None |

### Keyboard Shortcuts

### Detail Levels

- **Enter** - Add city or view full weather (depending on focus)

- **Delete** - Remove selected city- **`full`**: Current weather + 5-hour forecast + daily forecast

- **F5** - Refresh all weather data- **`basic`**: Current weather only

- **Escape** - Close full weather view- **`temps`**: Current temperature only (compact format)

- **Tab** - Navigate between elements

### Examples

## Configuration

**Get full weather for a specific city:**

### Custom City File```bash

python fastweather.py --city "New York"

By default, cities are saved in `city.json` in the application directory. You can specify a different file:```



```bash**Get basic weather for all cities:**

python fastweather.py --city-file /path/to/mycities.json```bash

```python fastweather.py --city all --detail basic

```

### Weather Display Options

**List available cities:**

Click "Configure Display" to customize what information is shown in full weather reports:```bash

- **Current Conditions**: Temperature, feels-like, wind, humidity, precipitation, pressure, cloud cover, visibility, UV indexpython fastweather.py --city list

- **Hourly Forecast**: Which details to show for the next 12 hours```

- **Daily Forecast**: Which details to show for the 7-day forecast

**Configure city list:**

## Weather Data Explained```bash

python fastweather.py --city configure

### Sky Conditions```



Cloud cover descriptions are based on meteorological standards:**Get 3-day forecast with debug info:**

- **Clear**: 0-12% cloud cover```bash

- **Mostly Clear**: 13-37% cloud cover  python fastweather.py --city "London" --days 3 --debug

- **Partly Cloudy**: 38-62% cloud cover```

- **Mostly Cloudy**: 63-87% cloud cover

- **Cloudy**: 88-100% cloud cover**Export all cities to HTML:**

```bash

### What You Getpython fastweather.py --html weather_report.html

```

**Current Weather**:

- Temperature and "feels like" temperature**Quick temperature check (quiet mode):**

- Sky conditions with cloud cover percentage```bash

- Wind speed, gusts, and directionpython fastweather.py --city all --detail temps --quiet

- Humidity and dew point```

- Precipitation amount

- Barometric pressure## Interactive Mode

- Visibility

- UV indexWhen run without the `--city` option, the program enters interactive mode:

- Observation time

```bash

**Hourly Forecast** (next 12 hours):python fastweather.py --detail full

- Hour-by-hour conditions```

- Temperature and feels-like

- Precipitation amount and probabilityYou'll be prompted to enter:

- Wind speed, gusts, and direction- City names (supports partial matching)

- Cloud cover- Special commands:

- Pressure, visibility, UV index  - `list` - Show available cities

  - `all` - Get weather for all cities

**Daily Forecast** (7 days):  - `configure` - Edit city list

- High and low temperatures  - `exit` - Quit program

- Feels-like high and low

- Sky conditions## City Management

- Sunrise and sunset times

- Daylight and sunshine hours### Adding Cities

- UV index

- Precipitation amount and probabilityCities are automatically added when you search for them. The program uses the Nominatim geocoding service to find coordinates.

- Wind speed, gusts, and direction

- Solar radiation**Via command line:**

```bash

## Building from Sourcepython fastweather.py --city configure

```

### Create Windows Executable

**In interactive mode:**

1. Install PyInstaller:Type `configure` when prompted for a city name.

   ```bash

   pip install pyinstaller### City Configuration Options

   ```

When in configuration mode, you can:

2. Run the build script:- `add <city name>` - Add a new city with automatic geocoding

   ```bash- `delete <number>` - Remove a city by its list number

   python build.py- `move up <number>` - Move a city up in the list

   ```- `move down <number>` - Move a city down in the list

- `save` - Save changes and exit

3. Find the executable in `dist/FastWeather/`- `cancel` - Discard changes and exit



The build script creates a single-folder distribution with all dependencies included.### City Disambiguation



## Sample CitiesWhen multiple cities match your search, you'll see a numbered list:

```

The application ships with sample cities from around the world. You can:Multiple matches found:

- Remove them using the "Remove City" button  1. London, England, United Kingdom (lat: 51.5074, lon: -0.1278)

- Delete `city.json` before first run to start with an empty list  2. London, Ontario, Canada (lat: 42.9849, lon: -81.2453)

- Edit the JSON file directly  3. London, Kentucky, United States (lat: 37.1289, lon: -84.0832)

Select the correct city by number: 1

## Data Sources```



- **Weather Data**: [Open-Meteo](https://open-meteo.com/) - Free weather API, no key required## City Data File

- **Geocoding**: [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org/)

Cities are stored in a JSON file (default: `city.json`) with this format:

## Technical Details```json

{

- **Language**: Python 3.8+    "New York, New York, United States": [40.7128, -74.0060],

- **GUI Framework**: PyQt5    "London, England, United Kingdom": [51.5074, -0.1278],

- **Weather API**: Open-Meteo API    "Tokyo, Tokyo, Japan": [35.6762, 139.6503]

- **Geocoding**: Nominatim}

- **Data Format**: JSON```

- **Units**: Fahrenheit, MPH, inches (with Celsius shown for temperature)

You can specify a different file with `--city-file`:

## System Requirements```bash

python fastweather.py --city-file my_cities.json

- **OS**: Windows 10/11 (executable), or any OS with Python 3.8+```

- **Memory**: 50-100 MB RAM

- **Disk Space**: ~30 MB for executable, ~5 MB for Python version## Output Formats

- **Internet**: Required for weather data and city search

### Full Detail Example

## Privacy```

--- Current Weather for New York, New York, United States ---

FastWeather:Temperature: 72.50°F

- ✅ Does NOT collect any personal informationWind Speed: 8.45 mph

- ✅ Does NOT track your usage  Wind Direction: South-West (225°)

- ✅ Does NOT contain ads or analyticsConditions: Clear sky

- ✅ Stores city preferences locally on your computer

- ✅ Only connects to Open-Meteo API and Nominatim for weather/geocoding data--- Hourly Weather (Next 5 Hours) for New York, New York, United States ---



## TroubleshootingHour 1 (2025-06-23T14:00):

  Temperature: 73.40°F

**"No weather data" appears**  Humidity: 45%

- Check your internet connection  Precipitation: 0.00 in

- The weather service may be temporarily unavailable  Wind Speed: 9.32 mph

- Try refreshing (F5)  Wind Direction: South-West (230°)

...

**City not found**

- Try adding state/country (e.g., "Portland, OR" or "Portland, Oregon, USA")--- Daily Weather (Next 7 Days) for New York, New York, United States ---

- Use full city names

- Check spellingMonday (2025-06-23):

  Max Temp: 78.80°F

**Weather conditions seem wrong**  Min Temp: 65.30°F

- Weather data comes from models and may lag reality by 15-30 minutes  Sunrise: 5:25 AM

- Sky conditions shown include both the weather code and actual cloud cover percentage  Sunset: 8:30 PM

- Click "Refresh All" to get the latest data  Total Precipitation: 0.00 in

...

**Application won't start (executable)**```

- Make sure all files from the ZIP are extracted to the same folder

- Windows may block the executable - right-click, select "Properties" > "Unblock"### Temps Mode Example

- Check that `city.json` is in the same folder as the executable```

New York, New York, United States: 72.50°F

## LicenseLondon, England, United Kingdom: 59.36°F

Tokyo, Tokyo, Japan: 77.90°F

See LICENSE file for details.```



## Contributing## HTML Export



This is a simple, focused weather app. If you have suggestions or find bugs, please open an issue on GitHub.Generate a comprehensive weather report for all cities:

```bash

## Creditspython fastweather.py --html weather_report.html

```

- Weather data: [Open-Meteo](https://open-meteo.com/)

- Geocoding: [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org/)This creates an HTML file with full weather details for all configured cities, including:

- Built with Python and PyQt5- Timestamp of report generation

- Current weather for each city
- Hourly and daily forecasts
- Formatted for easy reading in web browsers

## Error Handling

The program handles various error conditions gracefully:
- **Missing city file**: Creates a new one when cities are added
- **Invalid JSON**: Reports error and starts with empty city list
- **Network errors**: Shows error message and continues
- **Invalid city names**: Prompts for correction
- **API failures**: Reports specific error messages

## Tips

1. **First Run**: The program creates `city.json` automatically when you add your first city
2. **Partial Matching**: You can type partial city names (e.g., "new" for "New York")
3. **Case Insensitive**: City searches are case-insensitive
4. **Automation**: Use `--quiet` flag for scripts to suppress informational messages
5. **Quick Check**: Run without arguments for a quick temperature overview
6. **Debugging**: Use `--debug` to see weather codes and detailed lookup information

## Data Sources

- **Weather Data**: [Open-Meteo API](https://open-meteo.com/) (free, no API key required)
- **Geocoding**: [Nominatim](https://nominatim.openstreetmap.org/) (OpenStreetMap's geocoding service)

## Troubleshooting

**"No cities available in the file"**
- Run with `--city configure` to add cities

**"Could not retrieve coordinates"**
- Check internet connection
- Try a more specific city name (e.g., "London, UK" instead of "London")

**Network errors**
- Verify internet connectivity
- API services may be temporarily unavailable

**JSON decode errors**
- Delete the city.json file to start fresh
- Check file permissions

## License

This program is provided as-is for personal and educational use.

## Data Attribution (Required by API Terms)

This application uses:

**Open-Meteo API** - Weather data licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Attribution: "Weather data by Open-Meteo.com"
- More info: https://open-meteo.com/en/licence
- Usage: Non-commercial, under 10,000 API calls per day

**OpenStreetMap/Nominatim** - Geocoding data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
- Licensed under [ODbL](https://opendatacommons.org/licenses/odbl/)
- More info: https://operations.osmfoundation.org/policies/nominatim/
- Usage: User-triggered searches only, proper attribution displayed

**Important for Commercial Use**: If you modify this application for commercial purposes, you must:
1. Subscribe to Open-Meteo's commercial API plan (https://open-meteo.com/en/pricing)
2. Ensure compliance with OSM/Nominatim terms for your use case  
3. Review and comply with all license requirements

## Credits

- Weather data: [Open-Meteo](https://open-meteo.com/)
- Geocoding: [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org/)
- Built with Python and PyQt5
