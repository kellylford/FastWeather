"""Application entry point: `python -m fastweather` (and via the shim)."""

import argparse
import os

import wx

from .app import MainFrame
from .paths import user_data_dir


def main():
    app = wx.App()

    parser = argparse.ArgumentParser(prog="WeatherFast", description="WeatherFast")
    parser.add_argument("--reset", action="store_true",
                        help="Reset (delete) the saved city data file")
    parser.add_argument("-c", "--config",
                        help="Path to a specific city data JSON file to use")
    args = parser.parse_args()

    app.SetAppName("WeatherFast")
    data_dir = user_data_dir()  # single source of truth (with legacy migration)

    city_file = args.config if args.config else os.path.join(data_dir, "city.json")

    if args.reset:
        if os.path.exists(city_file):
            try:
                os.remove(city_file)
                print(f"Reset complete: Removed {city_file}")
            except Exception as e:
                print(f"Error resetting data: {e}")
        else:
            print(f"No data file found at {city_file} to reset.")

    MainFrame(city_file).Show()
    app.MainLoop()


if __name__ == "__main__":
    main()
