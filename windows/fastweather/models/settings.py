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
            "temperature": True, "feels_like": True, "humidity": True,
            "wind_speed": True, "wind_direction": True, "pressure": False,
            "visibility": False, "uv_index": False, "precipitation": True,
            "cloud_cover": False, "snowfall": False, "snow_depth": False,
            "rain": False, "showers": False,
        },
        "hourly": {
            "temperature": True, "feels_like": False, "humidity": False,
            "precipitation": True, "wind_speed": False, "wind_direction": False,
            "cloud_cover": False, "snowfall": False, "rain": False, "showers": False,
        },
        "daily": {
            "temperature_max": True, "temperature_min": True, "sunrise": True,
            "sunset": True, "precipitation_sum": True, "precipitation_hours": False,
            "wind_speed_max": False, "wind_direction_dominant": False,
            "snowfall_sum": False, "rain_sum": False, "showers_sum": False,
        },
        "units": {"temperature": "F", "wind_speed": "mph", "precipitation": "in"},
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
