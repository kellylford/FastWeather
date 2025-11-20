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

#### Managing Your Cities
*   **View Weather**: Select a city and press **Enter** (or activate **Full Weather**) to view the detailed report.
*   **Reorder**: Use the **Move Up** (Alt+U) and **Move Down** (Alt+D) buttons to change the order of your cities.
*   **Remove**: Select a city and press **Delete** (or activate **Remove**) to delete it from your list.
*   **Refresh**: Press **F5** (or activate **Refresh**) to update the temperature and conditions for the selected city.

### Full Weather View
This view provides a comprehensive weather report, including:
*   **Current Conditions**: Temperature, wind, humidity, etc.
*   **Hourly Forecast**: A 12-hour outlook.
*   **Daily Forecast**: A 7-day outlook with highs, lows, and precipitation chances.

Press **Esc** or activate **<- Back** to return to the city list.

---

## Customization

You can customize exactly what data is displayed in the Full Weather report.

1.  From the **Full Weather** view, activate the **Configure** button.
2.  A dialog will appear with three tabs: **Current**, **Hourly**, and **Daily**.
3.  Check or uncheck the boxes to show or hide specific details.
    *   *Examples: Cloud Cover, UV Index, Humidity, Feels Like Temperature.*
4.  Activate **OK** to save. Your preferences are saved automatically for future sessions.

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
| **Remove City** | `Delete` |
| **Move City Up** | `Alt + U` |
| **Move City Down** | `Alt + D` |
| **Go Back / Close** | `Esc` |

---

## Troubleshooting

**The hourly forecast seems to start at the wrong time.**
The app calculates the hourly forecast based on your computer's current time. Ensure your system clock is set correctly.

**I want to reset everything to default.**
If you need to clear all your data and settings, you can run the application from a command prompt with the reset flag:
`FastWeather.exe --reset`
This will delete your saved cities and configuration file.

**Where does the weather data come from?**
Weather data is provided by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0). Geocoding is provided by [OpenStreetMap](https://www.openstreetmap.org/).
