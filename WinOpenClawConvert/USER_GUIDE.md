# FastWeather User Guide

FastWeather is a lightweight, accessible, and customizable weather application designed for speed and ease of use. It provides current conditions, hourly forecasts, and daily outlooks for cities around the world without requiring an API key or complex setup.

## Getting Started

### Installation
FastWeather is a portable application, meaning it does not require a traditional installation process.

1.  **Download**: Download the `FastWeather.exe` file.
2.  **Run**: Open the file to start the application.
    *   *Note: Windows may ask for permission to run the file since it is not signed by a major publisher. You can safely allow it to run.*

### Default Cities
When you run FastWeather for the first time, it comes pre-loaded with a diverse set of default cities (e.g., Madison, San Diego, London) to help you get started immediately. You can remove these or add your own at any time.

### Data Storage
FastWeather stores your city list and configuration settings in your user profile directory (typically `%AppData%\FastWeather` on Windows). This ensures your preferences are remembered even if you move the executable file.

### Advanced Configuration
You can specify a custom city list file by running the application from the command line with the `-c` flag:
`FastWeather.exe -c "C:\path\to\my_cities.json"`

---

## Using FastWeather

### Main Screen
The main screen is divided into two sections: **Add New City** and **Your Cities**.

#### Adding a City
1.  Type the name of a city (e.g., "Madison, WI" or "London, UK") or a zip code into the text box at the top.
2.  Press **Enter** or activate the **Add City** button.
3.  If multiple locations match your search, a dialog will appear asking you to select the correct one.
4.  The city will be added to your list.

#### Interesting Cities to Try

FastWeather works with weather data from anywhere on Earth! Here are some fascinating locations you can add to explore extreme weather conditions:

**Extreme Cold:**
- **McMurdo Station, Antarctica** - Largest Antarctic research station (currently -4.8°C with regular snowfall)
- **Amundsen-Scott South Pole Station, Antarctica** - Geographic South Pole (extreme cold year-round)
- **Mount Everest Base Camp, Nepal** - Highest weather station area on Earth (currently -33°C!)

**Extreme Heat:**
- **Death Valley, California** - Hottest place on Earth (record: 56.7°C / 134°F in 1913)
- **Mecca, Saudi Arabia** - One of the hottest pilgrimage sites (summer highs often exceed 45°C)

**Unique Climates:**
- **Atacama Desert, Chile** - Driest non-polar place on Earth (some areas have never recorded rain)
- **Bikini Atoll, Marshall Islands** - Remote tropical island and historic nuclear test site
- **Pitcairn Island** - Most remote inhabited island in the world (Pacific Ocean)
- **Vostok Station, Antarctica** - Russian station, coldest temperature ever recorded (-89.2°C in 1983)

These locations are excellent for testing the app's display of extreme temperatures, low precipitation, or heavy snowfall. Simply type the location name (e.g., "Death Valley, California" or "McMurdo Station, Antarctica") and add it to your list!

#### Managing Your Cities
*   **View Weather**: Select a city and press **Enter** (or activate **Full Weather**) to view the detailed report.
*   **Reorder**: Use the **Move Up** (Alt+U) and **Move Down** (Alt+D) buttons to change the order of your cities.
*   **Remove**: Select a city and press **Delete** (or activate **Remove**) to delete it from your list.
*   **Refresh**: Press **F5** (or activate **Refresh**) to update the temperature and conditions for the selected city.

### Full Weather View
This view provides a comprehensive weather report, including:
*   **Current Conditions**: Temperature, Feels Like, Conditions, Humidity, Wind (with gusts), UV Index, Dew Point (comfort level), Pressure, Cloud Cover, Visibility
*   **Hourly Forecast**: 24-hour outlook with temperature, conditions, rain chance, UV Index, wind, humidity, and more
*   **Daily Forecast**: 16-day outlook with highs, lows, rain chance, UV Index, sunrise/sunset, and daylight duration

**Understanding the UV Index:**
*   **0-2 (Low)**: Minimal sun protection needed
*   **3-5 (Moderate)**: Use SPF 30+ sunscreen
*   **6-7 (High)**: Use SPF 30+ sunscreen and seek shade
*   **8-10 (Very High)**: Use SPF 50+ sunscreen, avoid midday sun
*   **11+ (Extreme)**: Take all precautions, stay indoors if possible

Press **Esc** or activate **<- Back** to return to the city list.

---

## Customization

You can customize exactly what data is displayed throughout the application.

1.  From the **Full Weather** view (or main screen in web version), activate the **Configure** button.
2.  A dialog will appear with multiple tabs:
    *   **Current Weather**: Temperature, Feels Like, Humidity, Wind Speed/Direction, Wind Gusts, UV Index, Dew Point, Pressure, Visibility, Precipitation, Cloud Cover
    *   **Hourly Forecast**: Temperature, Feels Like, Humidity, Precipitation, Rain Chance (%), UV Index, Wind Speed, Wind Gusts, Dew Point, Cloud Cover
    *   **Daily Forecast**: High/Low Temps, Sunrise/Sunset, Total Precipitation, Rain Chance (%), UV Index (Max), Daylight Duration, Sunshine Duration, Max Wind Speed
    *   **City List**: Choose which fields appear in your city list view and their display order
    *   **Units**: Select Fahrenheit/Celsius, mph/km/h, inches/mm, inHg/hPa, miles/km
3.  Check or uncheck the boxes to show or hide specific details.
4.  Activate **Apply** to preview changes or **Save & Close** to save. Your preferences are saved automatically for future sessions.

### New Features Explained

**UV Index**: Color-coded indicator showing sun exposure risk. Low (green), Moderate (yellow), High (orange), Very High (red), Extreme (purple). Higher numbers mean stronger sun protection needed.

**Wind Gusts**: Shows peak wind speeds in addition to sustained wind speed. Important for outdoor activities and driving safety.

**Rain Chance (%)**: Probability of precipitation occurring. Higher percentages mean rain is more likely. Helps you decide whether to bring an umbrella.

**Dew Point**: Indicates how humid/muggy it feels. Shows comfort level: Dry, Comfortable, Slightly humid, Muggy/Uncomfortable, or Oppressive.

**Daylight Duration**: Total hours of daylight from sunrise to sunset. Useful for planning outdoor activities and understanding seasonal changes.

**Sunshine Duration**: Expected hours of actual sunshine (vs. cloudy periods). Lower than daylight duration indicates cloudy conditions.

---

## Accessibility & Keyboard Shortcuts

FastWeather is designed to be fully accessible with screen readers and keyboard navigation.

### Navigation
*   **Tab**: Move focus between controls.
*   **Arrow Keys**: Navigate within the city list or weather report.
*   **Enter**: Activate buttons or view the selected city's weather.

### Keyboard Shortcuts
| Action | Shortcut |
| :--- | :--- |
| **Refresh Weather** | `F5` or `Ctrl + R` |
| **View Full Report** | `Alt + F` or `Enter` (on list) |
| **Configure Display** | `Alt + C` |
| **New City Field** | `Alt + N` |
| **Remove City** | `Delete` |
| **Move City Up** | `Alt + U` |
| **Move City Down** | `Alt + D` |
| **Go Back / Close** | `Esc` |

---

## Troubleshooting

**The hourly forecast seems to start at the wrong time.**
The app calculates the hourly forecast based on your computer's current time. Ensure your system clock is set correctly.


**What's the difference between Daylight and Sunshine Duration?**
Daylight Duration is the total time from sunrise to sunset. Sunshine Duration is the expected hours of actual direct sunshine. If sunshine duration is much lower than daylight, expect cloudy conditions.

**Why doesn't the UV Index show at night?**
UV Index measures ultraviolet radiation from the sun, so it's only displayed during daylight hours. At night, the UV Index is zero.

**What does "Muggy/Uncomfortable" dew point mean?**
Dew point measures moisture in the air. When the dew point is above 65°F (18°C), the air feels sticky and uncomfortable. Above 70°F (21°C) is oppressive. Below 60°F (15°C) feels comfortable.
**I want to reset everything to default.**
If you need to clear all your data and settings, you can run the application from a command prompt with the reset flag:
`FastWeather.exe --reset`
This will delete your saved cities and configuration file.

**Where does the weather data come from?**
Weather data is provided by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0). Geocoding is provided by [OpenStreetMap](https://www.openstreetmap.org/).

---

## Reporting Issues

If you encounter any bugs or have suggestions for improvements, please report them on our GitHub Issues page:
[https://github.com/kellylford/FastWeather/issues](https://github.com/kellylford/FastWeather/issues)
