# FastWeather

A fast weather application that provides current conditions and detailed forecasts without the clutter. Built with Python and wxPython, it is designed to be fully compatible with screen readers and keyboard navigation.

## Features

- **Fast & Simple**: Current weather at a glance, detailed forecasts on demand.
- **Comprehensive Data**: Temperature, feels-like, humidity, wind, precipitation, UV index, visibility, cloud cover, and more.
- **Accessible**: Fully compatible with screen readers and keyboard navigation.
- **No API Key Required**: Uses the free Open-Meteo weather service.
- **Privacy First**: No tracking, no analytics, your cities stored locally.
- **Portable**: Available as a single-file executable.

## Documentation

For detailed instructions on how to use the application, please see the [User Guide](USER_GUIDE.md).

## Installation

### Running from Source

1.  Install Python 3.8 or later.
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  Run the application:
    ```bash
    python fastweather.py
    ```

### Building the Executable

To build the standalone executable yourself:

1.  Install PyInstaller:
    ```bash
    pip install pyinstaller
    ```
2.  Run the build script:
    ```bash
    python build.py
    ```
3.  The executable will be created in the `dist/` folder.

## License

This project is licensed under the MIT License.

Data provided by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0).
Geocoding provided by [OpenStreetMap](https://www.openstreetmap.org/).
