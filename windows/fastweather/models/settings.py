"""Application settings.

Wraps the weather-display configuration that was previously a free-form dict
on the main frame. The persisted JSON shape is byte-compatible with the
original ``config.json`` (top-level ``current`` / ``hourly`` / ``daily`` /
``units`` sections), and loading merges saved values over defaults so old
config files upgrade cleanly when new keys are added.
"""

import copy


def default_config():
    """Return a fresh copy of the default weather-display configuration."""
    return {
        "current": {
            "today_outlook": True,
            "condition": True, "temperature": True, "feels_like": True,
            "humidity": True, "dew_point": False,
            "wind_speed": True, "wind_direction": True, "wind_gusts": False,
            "pressure": False, "visibility": False, "uv_index": False,
            "precipitation": True, "cloud_cover": False, "snowfall": False,
            "snow_depth": False, "rain": False, "showers": False,
        },
        "hourly": {
            "condition": False, "temperature": True, "feels_like": False,
            "humidity": False, "dew_point": False, "precip_probability": False,
            "precipitation": True, "wind_speed": False, "wind_direction": False,
            "wind_gusts": False, "cloud_cover": False, "snowfall": False,
            "rain": False, "showers": False,
        },
        "daily": {
            "condition": False, "temperature_max": True, "temperature_min": True,
            "apparent_max": False, "apparent_min": False, "sunrise": True,
            "sunset": True, "daylight_duration": False, "sunshine_duration": False,
            "uv_max": False, "precipitation_sum": True, "precipitation_hours": False,
            "precip_probability_max": False,
            "wind_speed_max": False, "wind_direction_dominant": False,
            "snowfall_sum": False, "rain_sum": False, "showers_sum": False,
        },
        "units": {
            "temperature": "F", "wind_speed": "mph", "precipitation": "in",
            "distance": "mi", "pressure": "inHg",
        },
        # Miscellaneous scalar options for feature screens.
        "options": {
            "around_me_radius_km": 160,       # ~100 mi
            "around_me_mode": "arc",          # arc | corridor
            "around_me_width": "Standard",    # Narrow | Standard | Medium | Wide
            "historical_years_back": 20,
            "mydata_selection": [],           # ordered list of MyDataParameter keys
        },
    }


class AppSettings:
    """Holds weather-display configuration with default-merging load semantics."""

    def __init__(self, config=None):
        self.config = config if config is not None else default_config()

    # -- dict-style access so existing call sites read naturally --------------
    def __getitem__(self, key):
        return self.config[key]

    def __setitem__(self, key, value):
        self.config[key] = value

    def get(self, key, default=None):
        return self.config.get(key, default)

    def to_dict(self):
        return copy.deepcopy(self.config)

    def replace(self, new_config):
        """Replace the whole configuration (used by the config dialog)."""
        self.config = copy.deepcopy(new_config)

    def merge_saved(self, saved_config):
        """Merge a loaded config dict over defaults (new keys survive upgrades)."""
        if not isinstance(saved_config, dict):
            return
        for section, options in saved_config.items():
            if section in self.config and isinstance(options, dict):
                for k, v in options.items():
                    self.config[section][k] = v
