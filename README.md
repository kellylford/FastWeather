# FastWeather

A command-line and GUI weather application that fetches current weather and forecasts for cities using the Open-Meteo API. Features both a powerful CLI interface and a fully accessible PyQt5 GUI with screen reader support.

## Applications Included

- **fastweather.py**: Full-featured command-line interface
- **accessible_weather_gui.py**: Accessible PyQt5 GUI application

## Features

- **Current Weather**: Temperature, wind speed/direction, weather conditions
- **Hourly Forecasts**: Next 5 hours with detailed information
- **Daily Forecasts**: Up to 7 days with high/low temperatures, sunrise/sunset, precipitation
- **Multiple Cities**: Manage and query multiple cities
- **Interactive Mode**: User-friendly prompts for city selection
- **Non-Interactive Mode**: Command-line arguments for automation
- **City Management**: Add, delete, and reorder cities
- **HTML Export**: Generate weather reports in HTML format
- **Automatic Geocoding**: Look up city coordinates automatically

## Installation

### Requirements
- Python 3.6 or higher
- `requests` library

### Setup
1. Install the required dependency:
   ```bash
   pip install requests
   ```

2. Download the `fastweather.py` script to your desired directory.

## Usage

### Quick Start

**Get current temperature for all cities (one line each):**
```bash
python fastweather.py
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--detail` | Level of detail: `full`, `basic`, or `temps` | `full` |
| `--city` | Specify a city name, or use `all`, `list`, or `configure` | None |
| `--city-file` | Path to JSON file with city coordinates | `city.json` |
| `--days` | Number of forecast days (1-7) | `7` |
| `--debug` | Show debug information including weather codes | `False` |
| `--quiet` | Suppress non-error output | `False` |
| `--html` | Export weather report to HTML file | None |

### Detail Levels

- **`full`**: Current weather + 5-hour forecast + daily forecast
- **`basic`**: Current weather only
- **`temps`**: Current temperature only (compact format)

### Examples

**Get full weather for a specific city:**
```bash
python fastweather.py --city "New York"
```

**Get basic weather for all cities:**
```bash
python fastweather.py --city all --detail basic
```

**List available cities:**
```bash
python fastweather.py --city list
```

**Configure city list:**
```bash
python fastweather.py --city configure
```

**Get 3-day forecast with debug info:**
```bash
python fastweather.py --city "London" --days 3 --debug
```

**Export all cities to HTML:**
```bash
python fastweather.py --html weather_report.html
```

**Quick temperature check (quiet mode):**
```bash
python fastweather.py --city all --detail temps --quiet
```

## Interactive Mode

When run without the `--city` option, the program enters interactive mode:

```bash
python fastweather.py --detail full
```

You'll be prompted to enter:
- City names (supports partial matching)
- Special commands:
  - `list` - Show available cities
  - `all` - Get weather for all cities
  - `configure` - Edit city list
  - `exit` - Quit program

## City Management

### Adding Cities

Cities are automatically added when you search for them. The program uses the Nominatim geocoding service to find coordinates.

**Via command line:**
```bash
python fastweather.py --city configure
```

**In interactive mode:**
Type `configure` when prompted for a city name.

### City Configuration Options

When in configuration mode, you can:
- `add <city name>` - Add a new city with automatic geocoding
- `delete <number>` - Remove a city by its list number
- `move up <number>` - Move a city up in the list
- `move down <number>` - Move a city down in the list
- `save` - Save changes and exit
- `cancel` - Discard changes and exit

### City Disambiguation

When multiple cities match your search, you'll see a numbered list:
```
Multiple matches found:
  1. London, England, United Kingdom (lat: 51.5074, lon: -0.1278)
  2. London, Ontario, Canada (lat: 42.9849, lon: -81.2453)
  3. London, Kentucky, United States (lat: 37.1289, lon: -84.0832)
Select the correct city by number: 1
```

## City Data File

Cities are stored in a JSON file (default: `city.json`) with this format:
```json
{
    "New York, New York, United States": [40.7128, -74.0060],
    "London, England, United Kingdom": [51.5074, -0.1278],
    "Tokyo, Tokyo, Japan": [35.6762, 139.6503]
}
```

You can specify a different file with `--city-file`:
```bash
python fastweather.py --city-file my_cities.json
```

## Output Formats

### Full Detail Example
```
--- Current Weather for New York, New York, United States ---
Temperature: 72.50°F
Wind Speed: 8.45 mph
Wind Direction: South-West (225°)
Conditions: Clear sky

--- Hourly Weather (Next 5 Hours) for New York, New York, United States ---

Hour 1 (2025-06-23T14:00):
  Temperature: 73.40°F
  Humidity: 45%
  Precipitation: 0.00 in
  Wind Speed: 9.32 mph
  Wind Direction: South-West (230°)
...

--- Daily Weather (Next 7 Days) for New York, New York, United States ---

Monday (2025-06-23):
  Max Temp: 78.80°F
  Min Temp: 65.30°F
  Sunrise: 5:25 AM
  Sunset: 8:30 PM
  Total Precipitation: 0.00 in
...
```

### Temps Mode Example
```
New York, New York, United States: 72.50°F
London, England, United Kingdom: 59.36°F
Tokyo, Tokyo, Japan: 77.90°F
```

## HTML Export

Generate a comprehensive weather report for all cities:
```bash
python fastweather.py --html weather_report.html
```

This creates an HTML file with full weather details for all configured cities, including:
- Timestamp of report generation
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
