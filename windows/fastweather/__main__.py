"""Application entry point: `python -m fastweather` (and via the shim)."""

import argparse
import os

import wx

from .app import MainFrame


def main():
    app = wx.App()

    parser = argparse.ArgumentParser(description="FastWeather")
    parser.add_argument("--reset", action="store_true",
                        help="Reset (delete) the saved city data file")
    parser.add_argument("-c", "--config",
                        help="Path to a specific city data JSON file to use")
    args = parser.parse_args()

    app.SetAppName("FastWeather")
    sp = wx.StandardPaths.Get()
    user_data_dir = sp.GetUserDataDir()
    if not os.path.exists(user_data_dir):
        os.makedirs(user_data_dir)

    city_file = args.config if args.config else os.path.join(user_data_dir, "city.json")

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
