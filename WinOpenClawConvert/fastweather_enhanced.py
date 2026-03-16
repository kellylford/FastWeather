#!/usr/bin/env python3
"""
Accessible GUI Weather Application using wxPython
Fully accessible with screen readers, keyboard navigation, and proper focus management
Uses Open-Meteo API (no API key required)

ENHANCED VERSION with iOS feature parity:
- Weather Around Me (regional weather in 8 directions)
- Expected Precipitation (2-hour nowcast with timeline)
- Historical Weather (multi-year same-day comparison)
"""

__version__ = "2.0"

import sys
import json
import requests
import argparse
from datetime import datetime, timedelta
import threading
import os
import wx
import wx.adv
import wx.lib.newevent

# Constants
KMH_TO_MPH = 0.621371
MM_TO_INCHES = 0.0393701
HPA_TO_INHG = 0.02953
OPEN_METEO_API_URL = "https://api.open-meteo.com/v1/forecast"
OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

# Default Cities
DEFAULT_CITIES = {
    "Madison, Wisconsin, United States": [43.074761, -89.3837613],
    "San Diego, California, United States": [32.7174202, -117.162772],
    "Portland, Oregon, United States": [45.5202471, -122.674194],
    "London, England, United Kingdom": [51.5074456, -0.1277653],
    "Miami, Florida, United States": [25.7741728, -80.19362],
    "Redmond, Washington, United States": [47.6694141, -122.1238767],
    "Mexico City, Ciudad de México, México": [19.3207722, -99.1514678],
    "Seaside, Oregon, United States": [45.993246, -123.920213],
    "Fond du Lac, Wisconsin, United States": [43.7731217, -88.4417538],
    "Mission Viejo, California, United States": [33.612472, -117.6425884],
    "Maui, Hawaii, United States of America": [20.8029568, -156.3106833]
}

# Weather code descriptions (WMO codes)
WEATHER_CODES = {
    0: "Clear sky",
    1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Depositing rime fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    56: "Light freezing drizzle", 57: "Dense freezing drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    66: "Light freezing rain", 67: "Heavy freezing rain",
    71: "Slight snow fall", 73: "Moderate snow fall", 75: "Heavy snow fall",
    77: "Snow grains",
    80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
}

# Custom Events
WeatherReadyEvent, EVT_WEATHER_READY = wx.lib.newevent.NewEvent()
WeatherErrorEvent, EVT_WEATHER_ERROR = wx.lib.newevent.NewEvent()
GeoReadyEvent, EVT_GEO_READY = wx.lib.newevent.NewEvent()
GeoErrorEvent, EVT_GEO_ERROR = wx.lib.newevent.NewEvent()
RegionalWeatherReadyEvent, EVT_REGIONAL_WEATHER_READY = wx.lib.newevent.NewEvent()
RegionalWeatherErrorEvent, EVT_REGIONAL_WEATHER_ERROR = wx.lib.newevent.NewEvent()
PrecipitationReadyEvent, EVT_PRECIPITATION_READY = wx.lib.newevent.NewEvent()
PrecipitationErrorEvent, EVT_PRECIPITATION_ERROR = wx.lib.newevent.NewEvent()
HistoricalWeatherReadyEvent, EVT_HISTORICAL_READY = wx.lib.newevent.NewEvent()
HistoricalWeatherErrorEvent, EVT_HISTORICAL_ERROR = wx.lib.newevent.NewEvent()


class WeatherFetchThread(threading.Thread):
    def __init__(self, notify_window, city_name, lat, lon, detail="basic", forecast_days=16):
        super().__init__()
        self.notify_window = notify_window
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.detail = detail
        self.forecast_days = forecast_days
        self.daemon = True
        self.start()
    
    def run(self):
        try:
            params = {
                "latitude": self.lat,
                "longitude": self.lon,
                "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility",
                "timezone": "auto",
            }
            
            if self.detail == "full":
                params["hourly"] = "temperature_2m,apparent_temperature,relative_humidity_2m,dewpoint_2m,precipitation,precipitation_probability,rain,showers,snowfall,snow_depth,weathercode,pressure_msl,surface_pressure,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,visibility,evapotranspiration,et0_fao_evapotranspiration,vapor_pressure_deficit,windspeed_10m,winddirection_10m,windgusts_10m,uv_index,uv_index_clear_sky,is_day,cape,freezing_level_height,soil_temperature_0cm"
                params["daily"] = "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,winddirection_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration"
                params["forecast_days"] = self.forecast_days
            else:
                params["hourly"] = "cloudcover"
                params["daily"] = "temperature_2m_max,temperature_2m_min"
                params["forecast_days"] = 1
            
            response = requests.get(OPEN_METEO_API_URL, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            wx.PostEvent(self.notify_window, WeatherReadyEvent(data=(self.city_name, data)))
        except Exception as e:
            wx.PostEvent(self.notify_window, WeatherErrorEvent(data=(self.city_name, str(e))))


class RegionalWeatherThread(threading.Thread):
    """Thread to fetch weather for 8 directions around a location"""
    def __init__(self, notify_window, city_name, lat, lon, distance_miles=50):
        super().__init__()
        self.notify_window = notify_window
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.distance_miles = distance_miles
        self.daemon = True
        self.start()
    
    def miles_to_degrees(self, miles):
        """Convert miles to degrees (approximate)"""
        return miles / 69.0
    
    def run(self):
        try:
            dist = self.miles_to_degrees(self.distance_miles)
            
            # Calculate 8 directional coordinates
            locations = [
                ("Center", self.lat, self.lon),
                ("North", self.lat + dist, self.lon),
                ("Northeast", self.lat + dist, self.lon + dist),
                ("East", self.lat, self.lon + dist),
                ("Southeast", self.lat - dist, self.lon + dist),
                ("South", self.lat - dist, self.lon),
                ("Southwest", self.lat - dist, self.lon - dist),
                ("West", self.lat, self.lon - dist),
                ("Northwest", self.lat + dist, self.lon - dist)
            ]
            
            results = []
            for direction, lat, lon in locations:
                params = {
                    "latitude": lat,
                    "longitude": lon,
                    "current": "temperature_2m,weather_code",
                    "timezone": "auto"
                }
                response = requests.get(OPEN_METEO_API_URL, params=params, timeout=10)
                response.raise_for_status()
                data = response.json()
                
                temp = data.get("current", {}).get("temperature_2m", 0)
                code = data.get("current", {}).get("weather_code", 0)
                condition = WEATHER_CODES.get(code, "Unknown")
                
                results.append({
                    "direction": direction,
                    "latitude": lat,
                    "longitude": lon,
                    "temperature": temp,
                    "condition": condition
                })
            
            wx.PostEvent(self.notify_window, RegionalWeatherReadyEvent(data=(self.city_name, results, self.distance_miles)))
        except Exception as e:
            wx.PostEvent(self.notify_window, RegionalWeatherErrorEvent(data=(self.city_name, str(e))))


class PrecipitationNowcastThread(threading.Thread):
    """Thread to fetch 2-hour precipitation nowcast"""
    def __init__(self, notify_window, city_name, lat, lon):
        super().__init__()
        self.notify_window = notify_window
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.daemon = True
        self.start()
    
    def run(self):
        try:
            params = {
                "latitude": self.lat,
                "longitude": self.lon,
                "minutely_15": "precipitation",
                "hourly": "precipitation,weather_code,wind_direction_10m",
                "current": "precipitation,weather_code,wind_direction_10m",
                "timezone": "auto",
                "forecast_days": 1
            }
            
            response = requests.get(OPEN_METEO_API_URL, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            # Process precipitation data
            processed = self.process_precipitation_data(data)
            wx.PostEvent(self.notify_window, PrecipitationReadyEvent(data=(self.city_name, processed)))
        except Exception as e:
            wx.PostEvent(self.notify_window, PrecipitationErrorEvent(data=(self.city_name, str(e))))
    
    def process_precipitation_data(self, data):
        """Process raw API data into usable format"""
        current = data.get("current", {})
        minutely = data.get("minutely_15", {})
        hourly = data.get("hourly", {})
        
        # Current status
        current_precip = current.get("precipitation", 0)
        if current_precip > 0.01:
            current_status = f"Precipitation at your location ({self.format_intensity(current_precip)})"
        else:
            current_status = "Clear at your location"
        
        # Build timeline
        timeline = []
        times = minutely.get("time", [])
        precip_values = minutely.get("precipitation", [])
        
        now = datetime.now()
        
        # Find current time index
        current_idx = 0
        for i, time_str in enumerate(times):
            try:
                time_dt = datetime.strptime(time_str, "%Y-%m-%dT%H:%M")
                if time_dt > now:
                    current_idx = i
                    break
            except:
                continue
        
        # Build 2-hour timeline (8 intervals of 15 minutes)
        intervals = [0, 15, 30, 45, 60, 75, 90, 105, 120]
        for interval in intervals:
            idx = current_idx + (interval // 15)
            if idx < len(times) and idx < len(precip_values):
                time_label = "Now" if interval == 0 else f"{interval} min"
                precip = precip_values[idx] if precip_values[idx] is not None else 0
                condition = self.format_intensity(precip)
                timeline.append({"time": time_label, "condition": condition, "value": precip})
        
        # Find nearest precipitation
        nearest = None
        for idx in range(current_idx, len(precip_values)):
            precip = precip_values[idx] if precip_values[idx] is not None else 0
            if precip > 0.01:
                minutes_away = (idx - current_idx) * 15
                if minutes_away > 0:
                    # Get wind direction for movement calculation
                    wind_dirs = hourly.get("wind_direction_10m", [])
                    wind_idx = min(idx // 4, len(wind_dirs) - 1) if wind_dirs else 0
                    wind_dir = wind_dirs[wind_idx] if wind_dirs and wind_idx < len(wind_dirs) else 0
                    
                    from_direction = self.get_opposite_direction(wind_dir)
                    distance_miles = (minutes_away * 15) // 60  # Rough estimate
                    speed_mph = 15  # Average storm speed
                    
                    arrival = f"{minutes_away} minutes" if minutes_away < 60 else f"Approximately {minutes_away // 60} hour{'s' if minutes_away // 60 > 1 else ''}"
                    
                    nearest = {
                        "distance_miles": distance_miles,
                        "direction": from_direction,
                        "type": self.format_intensity(precip),
                        "intensity": self.format_intensity(precip),
                        "movement_direction": self.get_cardinal_direction(wind_dir),
                        "speed_mph": speed_mph,
                        "arrival": arrival
                    }
                    break
        
        return {
            "current_status": current_status,
            "timeline": timeline,
            "nearest": nearest
        }
    
    def format_intensity(self, mm):
        if mm < 0.1:
            return "Clear"
        elif mm < 2.5:
            return "Light precipitation"
        elif mm < 10:
            return "Moderate precipitation"
        elif mm < 50:
            return "Heavy precipitation"
        else:
            return "Very heavy precipitation"
    
    def get_cardinal_direction(self, degrees):
        directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        index = int((degrees + 22.5) / 45) % 8
        return directions[index]
    
    def get_opposite_direction(self, degrees):
        opposite = (degrees + 180) % 360
        return self.get_cardinal_direction(opposite).lower()


class HistoricalWeatherThread(threading.Thread):
    """Thread to fetch historical weather data"""
    def __init__(self, notify_window, city_name, lat, lon, month, day, years_back=5):
        super().__init__()
        self.notify_window = notify_window
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.month = month
        self.day = day
        self.years_back = years_back
        self.daemon = True
        self.start()
    
    def run(self):
        try:
            current_year = datetime.now().year
            results = []
            
            for year in range(current_year - 1, current_year - self.years_back - 1, -1):
                date_str = f"{year}-{self.month:02d}-{self.day:02d}"
                
                params = {
                    "latitude": self.lat,
                    "longitude": self.lon,
                    "start_date": date_str,
                    "end_date": date_str,
                    "daily": "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,rain_sum,snowfall_sum,precipitation_hours,windspeed_10m_max",
                    "timezone": "auto"
                }
                
                response = requests.get(OPEN_METEO_ARCHIVE_URL, params=params, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    daily = data.get("daily", {})
                    
                    if daily.get("time") and len(daily["time"]) > 0:
                        results.append({
                            "year": year,
                            "date": date_str,
                            "temp_max": daily.get("temperature_2m_max", [None])[0],
                            "temp_min": daily.get("temperature_2m_min", [None])[0],
                            "weather_code": daily.get("weathercode", [0])[0],
                            "precipitation": daily.get("precipitation_sum", [0])[0],
                            "snowfall": daily.get("snowfall_sum", [0])[0],
                            "wind_max": daily.get("windspeed_10m_max", [None])[0]
                        })
            
            wx.PostEvent(self.notify_window, HistoricalWeatherReadyEvent(data=(self.city_name, results, self.month, self.day)))
        except Exception as e:
            wx.PostEvent(self.notify_window, HistoricalWeatherErrorEvent(data=(self.city_name, str(e))))


class GeocodingThread(threading.Thread):
    def __init__(self, notify_window, city_input):
        super().__init__()
        self.notify_window = notify_window
        self.city_input = city_input
        self.daemon = True
        self.start()
    
    def run(self):
        try:
            params = {"q": self.city_input, "format": "json", "addressdetails": 1, "limit": 5}
            headers = {"User-Agent": "FastWeather GUI/2.0"}
            response = requests.get(NOMINATIM_URL, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            results = response.json()
            
            matches = []
            for r in results:
                address = r.get("address", {})
                city_name = address.get('city') or address.get('town') or address.get('village') or self.city_input
                state = address.get('state', '')
                country = address.get('country', '')
                display_parts = [p for p in [city_name, state, country] if p]
                matches.append({
                    "display": ", ".join(display_parts),
                    "city": city_name,
                    "state": state,
                    "country": country,
                    "lat": float(r["lat"]),
                    "lon": float(r["lon"])
                })
            wx.PostEvent(self.notify_window, GeoReadyEvent(data=(self.city_input, matches)))
        except Exception as e:
            wx.PostEvent(self.notify_window, GeoErrorEvent(data=str(e)))


class CitySelectionDialog(wx.Dialog):
    def __init__(self, parent, matches, original_input):
        super().__init__(parent, title="Select City", size=(600, 400))
        self.matches = matches
        self.selected_match = None
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        vbox.Add(wx.StaticText(panel, label=f"Multiple cities found for '{original_input}':"), 0, wx.ALL, 10)
        
        self.city_list = wx.ListBox(panel, style=wx.LB_SINGLE)
        for match in matches:
            self.city_list.Append(f"{match['display']} ({match['lat']:.4f}, {match['lon']:.4f})")
        if matches: self.city_list.SetSelection(0)
        
        vbox.Add(self.city_list, 1, wx.EXPAND | wx.ALL, 10)
        
        btns = wx.StdDialogButtonSizer()
        btns.AddButton(wx.Button(panel, wx.ID_OK))
        btns.AddButton(wx.Button(panel, wx.ID_CANCEL))
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        self.Bind(wx.EVT_BUTTON, self.on_ok, id=wx.ID_OK)
        self.city_list.Bind(wx.EVT_LISTBOX_DCLICK, self.on_ok)
        self.city_list.Bind(wx.EVT_KEY_DOWN, self.on_list_key)
        
    def on_ok(self, event):
        sel = self.city_list.GetSelection()
        if sel != wx.NOT_FOUND:
            self.selected_match = self.matches[sel]
            self.EndModal(wx.ID_OK)
        else:
            event.Skip()
    
    def on_list_key(self, event):
        keycode = event.GetKeyCode()
        if keycode == wx.WXK_RETURN or keycode == wx.WXK_NUMPAD_ENTER:
            self.on_ok(event)
        else:
            event.Skip()


class LocationBrowserDialog(wx.Dialog):
    """Dialog for browsing cities by US State or International Country"""
    def __init__(self, parent, us_cities_cache, intl_cities_cache):
        super().__init__(parent, title="Browse Cities by Location", size=(700, 600))
        self.us_cities_cache = us_cities_cache
        self.intl_cities_cache = intl_cities_cache
        self.selected_cities = []
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        
        # Notebook for US States / International tabs
        self.notebook = wx.Notebook(panel)
        
        # US States Tab
        us_panel = wx.Panel(self.notebook)
        us_sizer = wx.BoxSizer(wx.VERTICAL)
        
        us_sizer.Add(wx.StaticText(us_panel, label="Select a U.S. State:"), 0, wx.ALL, 10)
        self.state_choice = wx.Choice(us_panel)
        if us_cities_cache:
            states = sorted(us_cities_cache.keys())
            self.state_choice.Append("-- Select a State --")
            for state in states:
                self.state_choice.Append(state)
            self.state_choice.SetSelection(0)
        us_sizer.Add(self.state_choice, 0, wx.EXPAND | wx.ALL, 10)
        
        self.load_state_btn = wx.Button(us_panel, label="Load Cities")
        us_sizer.Add(self.load_state_btn, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        us_panel.SetSizer(us_sizer)
        
        # International Tab
        intl_panel = wx.Panel(self.notebook)
        intl_sizer = wx.BoxSizer(wx.VERTICAL)
        
        intl_sizer.Add(wx.StaticText(intl_panel, label="Select a Country:"), 0, wx.ALL, 10)
        self.country_choice = wx.Choice(intl_panel)
        if intl_cities_cache:
            countries = sorted(intl_cities_cache.keys())
            self.country_choice.Append("-- Select a Country --")
            for country in countries:
                self.country_choice.Append(country)
            self.country_choice.SetSelection(0)
        intl_sizer.Add(self.country_choice, 0, wx.EXPAND | wx.ALL, 10)
        
        self.load_country_btn = wx.Button(intl_panel, label="Load Cities")
        intl_sizer.Add(self.load_country_btn, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        intl_panel.SetSizer(intl_sizer)
        
        self.notebook.AddPage(us_panel, "U.S. States")
        self.notebook.AddPage(intl_panel, "International")
        vbox.Add(self.notebook, 0, wx.EXPAND | wx.ALL, 10)
        
        # Cities list with checkboxes
        vbox.Add(wx.StaticText(panel, label="Select cities to add (check multiple cities):"), 0, wx.ALL, 10)
        self.cities_list = wx.CheckListBox(panel)
        vbox.Add(self.cities_list, 1, wx.EXPAND | wx.ALL, 10)
        
        # Selection controls
        sel_box = wx.BoxSizer(wx.HORIZONTAL)
        self.select_all_btn = wx.Button(panel, label="Select All")
        self.deselect_all_btn = wx.Button(panel, label="Deselect All")
        sel_box.Add(self.select_all_btn, 0, wx.RIGHT, 5)
        sel_box.Add(self.deselect_all_btn, 0)
        vbox.Add(sel_box, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        # Dialog buttons
        btns = wx.StdDialogButtonSizer()
        add_btn = wx.Button(panel, wx.ID_OK, "Add Selected Cities")
        cancel_btn = wx.Button(panel, wx.ID_CANCEL)
        btns.AddButton(add_btn)
        btns.AddButton(cancel_btn)
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        # Bind events
        self.Bind(wx.EVT_BUTTON, self.on_load_state, self.load_state_btn)
        self.Bind(wx.EVT_BUTTON, self.on_load_country, self.load_country_btn)
        self.Bind(wx.EVT_BUTTON, self.on_select_all, self.select_all_btn)
        self.Bind(wx.EVT_BUTTON, self.on_deselect_all, self.deselect_all_btn)
        self.Bind(wx.EVT_BUTTON, self.on_add_cities, id=wx.ID_OK)
    
    def on_load_state(self, event):
        sel = self.state_choice.GetSelection()
        if sel == 0 or sel == wx.NOT_FOUND:
            wx.MessageBox("Please select a state", "No Selection", wx.OK | wx.ICON_WARNING)
            return
        
        state_name = self.state_choice.GetString(sel)
        if state_name in self.us_cities_cache:
            self.cities_list.Clear()
            cities = self.us_cities_cache[state_name]
            for city_data in cities:
                display = f"{city_data['name']}, {city_data['state']}, {city_data['country']}"
                self.cities_list.Append(display)
                self.cities_list.SetClientData(self.cities_list.GetCount() - 1, 
                                               (city_data['name'], city_data['lat'], city_data['lon'], 
                                                city_data['state'], city_data['country']))
    
    def on_load_country(self, event):
        sel = self.country_choice.GetSelection()
        if sel == 0 or sel == wx.NOT_FOUND:
            wx.MessageBox("Please select a country", "No Selection", wx.OK | wx.ICON_WARNING)
            return
        
        country_name = self.country_choice.GetString(sel)
        if country_name in self.intl_cities_cache:
            self.cities_list.Clear()
            cities = self.intl_cities_cache[country_name]
            for city_data in cities:
                parts = [city_data['name']]
                if city_data.get('state'):
                    parts.append(city_data['state'])
                parts.append(country_name)
                display = ", ".join(parts)
                
                self.cities_list.Append(display)
                self.cities_list.SetClientData(self.cities_list.GetCount() - 1, 
                                               (city_data['name'], city_data['lat'], city_data['lon'],
                                                city_data.get('state', ''), country_name))
    
    def on_select_all(self, event):
        for i in range(self.cities_list.GetCount()):
            self.cities_list.Check(i, True)
    
    def on_deselect_all(self, event):
        for i in range(self.cities_list.GetCount()):
            self.cities_list.Check(i, False)
    
    def on_add_cities(self, event):
        self.selected_cities = []
        for i in range(self.cities_list.GetCount()):
            if self.cities_list.IsChecked(i):
                city_data = self.cities_list.GetClientData(i)
                name, lat, lon, state, country = city_data
                parts = [name]
                if state:
                    parts.append(state)
                parts.append(country)
                display_name = ", ".join(parts)
                self.selected_cities.append((display_name, lat, lon))
        
        if not self.selected_cities:
            wx.MessageBox("Please select at least one city to add", "No Cities Selected", 
                         wx.OK | wx.ICON_WARNING)
            return
        
        self.EndModal(wx.ID_OK)
    
    def get_selected_cities(self):
        return self.selected_cities


class WeatherAroundMeDialog(wx.Dialog):
    """Dialog showing weather in 8 cardinal directions"""
    def __init__(self, parent, city_name, lat, lon, is_fahrenheit=True):
        super().__init__(parent, title=f"Weather Around Me - {city_name}", size=(600, 700))
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.is_fahrenheit = is_fahrenheit
        self.regional_data = None
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        
        # Distance selector
        dist_box = wx.BoxSizer(wx.HORIZONTAL)
        dist_box.Add(wx.StaticText(panel, label="Distance:"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 5)
        self.distance_choice = wx.Choice(panel, choices=["25 miles", "50 miles", "100 miles", "150 miles"])
        self.distance_choice.SetSelection(1)  # Default 50 miles
        dist_box.Add(self.distance_choice, 0, wx.RIGHT, 10)
        self.refresh_btn = wx.Button(panel, label="Refresh")
        dist_box.Add(self.refresh_btn, 0)
        vbox.Add(dist_box, 0, wx.ALL, 10)
        
        # Content area
        self.content_panel = wx.ScrolledWindow(panel)
        self.content_panel.SetScrollRate(5, 5)
        self.content_sizer = wx.BoxSizer(wx.VERTICAL)
        self.content_panel.SetSizer(self.content_sizer)
        vbox.Add(self.content_panel, 1, wx.EXPAND | wx.ALL, 10)
        
        # Loading text
        self.loading_text = wx.StaticText(self.content_panel, label="Loading regional weather...")
        self.content_sizer.Add(self.loading_text, 0, wx.ALL, 10)
        
        # Close button
        btns = wx.StdDialogButtonSizer()
        btns.AddButton(wx.Button(panel, wx.ID_OK))
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        # Bind events
        self.Bind(wx.EVT_BUTTON, self.on_refresh, self.refresh_btn)
        self.Bind(wx.EVT_CHOICE, self.on_distance_change, self.distance_choice)
        
        # Start loading
        self.load_regional_weather()
    
    def on_distance_change(self, event):
        self.load_regional_weather()
    
    def on_refresh(self, event):
        self.load_regional_weather()
    
    def load_regional_weather(self):
        self.loading_text.SetLabel("Loading regional weather...")
        self.content_sizer.Clear(True)
        self.content_sizer.Add(self.loading_text, 0, wx.ALL, 10)
        self.content_panel.Layout()
        self.Refresh()
        
        distance = [25, 50, 100, 150][self.distance_choice.GetSelection()]
        RegionalWeatherThread(self, self.city_name, self.lat, self.lon, distance)
    
    def display_regional_weather(self, data, distance_miles):
        self.content_sizer.Clear(True)
        
        # Title
        title = wx.StaticText(self.content_panel, label=f"Weather within {distance_miles} miles of {self.city_name}")
        title_font = wx.Font(12, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD)
        title.SetFont(title_font)
        self.content_sizer.Add(title, 0, wx.ALL, 10)
        
        # Find center data
        center = None
        directions = []
        for item in data:
            if item["direction"] == "Center":
                center = item
            else:
                directions.append(item)
        
        # Center location card
        if center:
            center_box = wx.StaticBox(self.content_panel, label="Your Location")
            center_sizer = wx.StaticBoxSizer(center_box, wx.VERTICAL)
            
            temp = self.format_temp(center["temperature"])
            condition = center["condition"]
            
            center_info = wx.StaticText(self.content_panel, label=f"{self.city_name}\n{temp} - {condition}")
            center_font = wx.Font(11, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL)
            center_info.SetFont(center_font)
            center_sizer.Add(center_info, 0, wx.ALL, 10)
            
            self.content_sizer.Add(center_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Directional weather cards
        dir_box = wx.StaticBox(self.content_panel, label="Surrounding Areas")
        dir_sizer = wx.StaticBoxSizer(dir_box, wx.VERTICAL)
        
        for item in directions:
            direction = item["direction"]
            temp = self.format_temp(item["temperature"])
            condition = item["condition"]
            
            row = wx.BoxSizer(wx.HORIZONTAL)
            
            # Direction label
            dir_label = wx.StaticText(self.content_panel, label=f"{direction}:")
            dir_label.SetFont(wx.Font(10, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
            row.Add(dir_label, 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
            
            # Weather info
            info = wx.StaticText(self.content_panel, label=f"{temp} - {condition}")
            row.Add(info, 1, wx.ALIGN_CENTER_VERTICAL)
            
            dir_sizer.Add(row, 0, wx.EXPAND | wx.ALL, 5)
            
            # Add separator except for last item
            if item != directions[-1]:
                dir_sizer.Add(wx.StaticLine(self.content_panel), 0, wx.EXPAND | wx.TOP | wx.BOTTOM, 5)
        
        self.content_sizer.Add(dir_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Regional summary
        if center and directions:
            summary = self.generate_summary(center, directions)
            if summary:
                summary_box = wx.StaticBox(self.content_panel, label="Regional Summary")
                summary_sizer = wx.StaticBoxSizer(summary_box, wx.VERTICAL)
                summary_text = wx.StaticText(self.content_panel, label=summary)
                summary_text.Wrap(500)
                summary_sizer.Add(summary_text, 0, wx.ALL, 10)
                self.content_sizer.Add(summary_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Attribution
        attr = wx.StaticText(self.content_panel, label="Weather data by Open-Meteo.com")
        attr.SetForegroundColour(wx.Colour(128, 128, 128))
        self.content_sizer.Add(attr, 0, wx.ALL, 10)
        
        self.content_panel.Layout()
        self.content_panel.FitInside()
        self.Refresh()
    
    def format_temp(self, celsius):
        if self.is_fahrenheit:
            temp_f = (celsius * 9/5) + 32
            return f"{temp_f:.0f}°F"
        return f"{celsius:.0f}°C"
    
    def generate_summary(self, center, directions):
        """Generate a summary of regional weather patterns"""
        summaries = []
        
        center_temp = center["temperature"]
        
        # Check for temperature differences
        warmer_dirs = []
        colder_dirs = []
        for d in directions:
            temp_diff = d["temperature"] - center_temp
            if temp_diff > 3:
                warmer_dirs.append(d["direction"].lower())
            elif temp_diff < -3:
                colder_dirs.append(d["direction"].lower())
        
        if warmer_dirs:
            summaries.append(f"Warmer to the {', '.join(warmer_dirs)}")
        if colder_dirs:
            summaries.append(f"Colder to the {', '.join(colder_dirs)}")
        
        # Check for precipitation
        precip_dirs = [d["direction"].lower() for d in directions 
                      if "rain" in d["condition"].lower() or "snow" in d["condition"].lower() or "drizzle" in d["condition"].lower()]
        if precip_dirs:
            summaries.append(f"Precipitation to the {', '.join(precip_dirs)}")
        
        return ". ".join(summaries) if summaries else None


class PrecipitationNowcastDialog(wx.Dialog):
    """Dialog showing 2-hour precipitation nowcast"""
    def __init__(self, parent, city_name, lat, lon, is_fahrenheit=True):
        super().__init__(parent, title=f"Expected Precipitation - {city_name}", size=(600, 600))
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.is_fahrenheit = is_fahrenheit
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        
        # Loading text
        self.loading_text = wx.StaticText(panel, label="Loading precipitation forecast...")
        vbox.Add(self.loading_text, 0, wx.ALL, 20)
        
        # Content panel (hidden initially)
        self.content_panel = wx.ScrolledWindow(panel)
        self.content_panel.SetScrollRate(5, 5)
        self.content_sizer = wx.BoxSizer(wx.VERTICAL)
        self.content_panel.SetSizer(self.content_sizer)
        self.content_panel.Hide()
        vbox.Add(self.content_panel, 1, wx.EXPAND | wx.ALL, 10)
        
        # Close button
        btns = wx.StdDialogButtonSizer()
        close_btn = wx.Button(panel, wx.ID_OK, "Close")
        btns.AddButton(close_btn)
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        # Start loading
        PrecipitationNowcastThread(self, city_name, lat, lon)
    
    def display_precipitation_data(self, data):
        self.loading_text.Hide()
        self.content_panel.Show()
        self.content_sizer.Clear(True)
        
        # Title
        title = wx.StaticText(self.content_panel, label=f"2-Hour Precipitation Forecast")
        title_font = wx.Font(12, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD)
        title.SetFont(title_font)
        self.content_sizer.Add(title, 0, wx.ALL, 10)
        
        # Current status
        status_box = wx.StaticBox(self.content_panel, label="Current Status")
        status_sizer = wx.StaticBoxSizer(status_box, wx.VERTICAL)
        status_text = wx.StaticText(self.content_panel, label=data["current_status"])
        status_sizer.Add(status_text, 0, wx.ALL, 10)
        self.content_sizer.Add(status_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Nearest precipitation
        if data["nearest"]:
            nearest = data["nearest"]
            nearest_box = wx.StaticBox(self.content_panel, label="Nearest Precipitation")
            nearest_sizer = wx.StaticBoxSizer(nearest_box, wx.VERTICAL)
            
            info_text = f"""Type: {nearest['type']}
Distance: {nearest['distance_miles']} miles to the {nearest['direction']}
Movement: {nearest['movement_direction']} at {nearest['speed_mph']} mph
Expected arrival: {nearest['arrival']}"""
            
            nearest_text = wx.StaticText(self.content_panel, label=info_text)
            nearest_sizer.Add(nearest_text, 0, wx.ALL, 10)
            self.content_sizer.Add(nearest_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Timeline
        timeline_box = wx.StaticBox(self.content_panel, label="2-Hour Timeline")
        timeline_sizer = wx.StaticBoxSizer(timeline_box, wx.VERTICAL)
        
        for point in data["timeline"]:
            row = wx.BoxSizer(wx.HORIZONTAL)
            time_label = wx.StaticText(self.content_panel, label=f"{point['time']:<12}")
            time_label.SetFont(wx.Font(9, wx.FONTFAMILY_TELETYPE, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
            row.Add(time_label, 0, wx.RIGHT, 10)
            
            condition = wx.StaticText(self.content_panel, label=point["condition"])
            row.Add(condition, 1)
            
            timeline_sizer.Add(row, 0, wx.EXPAND | wx.ALL, 5)
        
        self.content_sizer.Add(timeline_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Visual representation (simple bar chart)
        graph_box = wx.StaticBox(self.content_panel, label="Precipitation Graph")
        graph_sizer = wx.StaticBoxSizer(graph_box, wx.VERTICAL)
        
        graph_panel = wx.Panel(self.content_panel)
        graph_panel.Bind(wx.EVT_PAINT, self.on_paint_graph)
        graph_panel.SetMinSize((500, 150))
        graph_panel.data = data["timeline"]
        graph_sizer.Add(graph_panel, 0, wx.EXPAND | wx.ALL, 10)
        
        self.content_sizer.Add(graph_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Attribution
        attr = wx.StaticText(self.content_panel, label="Precipitation nowcast data by Open-Meteo.com")
        attr.SetForegroundColour(wx.Colour(128, 128, 128))
        self.content_sizer.Add(attr, 0, wx.ALL, 10)
        
        self.content_panel.Layout()
        self.content_panel.FitInside()
        self.Layout()
        self.Refresh()
    
    def on_paint_graph(self, event):
        dc = wx.PaintDC(event.GetEventObject())
        panel = event.GetEventObject()
        data = getattr(panel, 'data', [])
        
        if not data:
            return
        
        width, height = panel.GetSize()
        bar_width = width // len(data) - 10
        max_height = height - 40
        
        # Draw bars
        for i, point in enumerate(data):
            value = point.get("value", 0)
            condition = point.get("condition", "Clear")
            
            # Determine color and height based on intensity
            if "Clear" in condition or "No data" in condition:
                color = wx.Colour(200, 200, 200)
                bar_h = 10
            elif "Light" in condition:
                color = wx.Colour(100, 150, 255)
                bar_h = max_height * 0.3
            elif "Moderate" in condition:
                color = wx.Colour(50, 100, 255)
                bar_h = max_height * 0.6
            else:
                color = wx.Colour(0, 50, 200)
                bar_h = max_height * 0.9
            
            x = i * (bar_width + 10) + 10
            y = height - bar_h - 20
            
            dc.SetBrush(wx.Brush(color))
            dc.DrawRectangle(x, int(y), bar_width, int(bar_h))
            
            # Draw time label
            dc.SetTextForeground(wx.Colour(0, 0, 0))
            dc.DrawText(point["time"], x, height - 18)


class HistoricalWeatherDialog(wx.Dialog):
    """Dialog showing historical weather data"""
    def __init__(self, parent, city_name, lat, lon, is_fahrenheit=True):
        super().__init__(parent, title=f"Historical Weather - {city_name}", size=(700, 600))
        self.city_name = city_name
        self.lat = lat
        self.lon = lon
        self.is_fahrenheit = is_fahrenheit
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        
        # Date selection
        date_box = wx.BoxSizer(wx.HORIZONTAL)
        date_box.Add(wx.StaticText(panel, label="Select Date:"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 5)
        
        self.month_choice = wx.Choice(panel, choices=["January", "February", "March", "April", "May", "June",
                                                        "July", "August", "September", "October", "November", "December"])
        self.month_choice.SetSelection(datetime.now().month - 1)
        date_box.Add(self.month_choice, 0, wx.RIGHT, 5)
        
        self.day_choice = wx.Choice(panel, choices=[str(i) for i in range(1, 32)])
        self.day_choice.SetSelection(datetime.now().day - 1)
        date_box.Add(self.day_choice, 0, wx.RIGHT, 10)
        
        self.load_btn = wx.Button(panel, label="Load History")
        date_box.Add(self.load_btn, 0)
        
        vbox.Add(date_box, 0, wx.ALL, 10)
        
        # Content area
        self.content_panel = wx.ScrolledWindow(panel)
        self.content_panel.SetScrollRate(5, 5)
        self.content_sizer = wx.BoxSizer(wx.VERTICAL)
        self.content_panel.SetSizer(self.content_sizer)
        vbox.Add(self.content_panel, 1, wx.EXPAND | wx.ALL, 10)
        
        # Loading text
        self.loading_text = wx.StaticText(self.content_panel, label="Select a date and click Load History")
        self.content_sizer.Add(self.loading_text, 0, wx.ALL, 10)
        
        # Close button
        btns = wx.StdDialogButtonSizer()
        btns.AddButton(wx.Button(panel, wx.ID_OK))
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        # Bind events
        self.Bind(wx.EVT_BUTTON, self.on_load, self.load_btn)
    
    def on_load(self, event):
        month = self.month_choice.GetSelection() + 1
        day = self.day_choice.GetSelection() + 1
        
        self.loading_text.SetLabel("Loading historical data...")
        self.content_sizer.Clear(True)
        self.content_sizer.Add(self.loading_text, 0, wx.ALL, 10)
        self.content_panel.Layout()
        self.Refresh()
        
        HistoricalWeatherThread(self, self.city_name, self.lat, self.lon, month, day)
    
    def display_historical_data(self, data, month, day):
        self.content_sizer.Clear(True)
        
        month_name = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"][month - 1]
        
        # Title
        title = wx.StaticText(self.content_panel, label=f"Historical Weather for {month_name} {day}")
        title_font = wx.Font(12, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD)
        title.SetFont(title_font)
        self.content_sizer.Add(title, 0, wx.ALL, 10)
        
        if not data:
            no_data = wx.StaticText(self.content_panel, label="No historical data available for this date.")
            self.content_sizer.Add(no_data, 0, wx.ALL, 10)
        else:
            # Create grid
            grid_box = wx.StaticBox(self.content_panel, label=f"Past {len(data)} Years")
            grid_sizer = wx.StaticBoxSizer(grid_box, wx.VERTICAL)
            
            # Header row
            header = wx.BoxSizer(wx.HORIZONTAL)
            headers = ["Year", "High", "Low", "Conditions", "Precipitation", "Wind Max"]
            widths = [60, 70, 70, 150, 100, 90]
            for h, w in zip(headers, widths):
                lbl = wx.StaticText(self.content_panel, label=h)
                lbl.SetFont(wx.Font(9, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
                header.Add(lbl, w, wx.RIGHT, 5)
            grid_sizer.Add(header, 0, wx.EXPAND | wx.ALL, 5)
            grid_sizer.Add(wx.StaticLine(self.content_panel), 0, wx.EXPAND)
            
            # Data rows
            for item in data:
                row = wx.BoxSizer(wx.HORIZONTAL)
                
                # Year
                year = wx.StaticText(self.content_panel, label=str(item["year"]))
                row.Add(year, widths[0], wx.RIGHT, 5)
                
                # High temp
                high = self.format_temp(item["temp_max"]) if item["temp_max"] else "N/A"
                high_lbl = wx.StaticText(self.content_panel, label=high)
                row.Add(high_lbl, widths[1], wx.RIGHT, 5)
                
                # Low temp
                low = self.format_temp(item["temp_min"]) if item["temp_min"] else "N/A"
                low_lbl = wx.StaticText(self.content_panel, label=low)
                row.Add(low_lbl, widths[2], wx.RIGHT, 5)
                
                # Conditions
                code = item.get("weather_code", 0)
                condition = WEATHER_CODES.get(code, "Unknown")
                cond_lbl = wx.StaticText(self.content_panel, label=condition)
                row.Add(cond_lbl, widths[3], wx.RIGHT, 5)
                
                # Precipitation
                precip = item.get("precipitation", 0) or 0
                snow = item.get("snowfall", 0) or 0
                if snow > 0:
                    precip_str = f"{snow:.1f}cm snow"
                elif precip > 0:
                    precip_str = f"{precip:.1f}mm"
                else:
                    precip_str = "None"
                precip_lbl = wx.StaticText(self.content_panel, label=precip_str)
                row.Add(precip_lbl, widths[4], wx.RIGHT, 5)
                
                # Wind
                wind = item.get("wind_max")
                wind_str = f"{wind:.0f} km/h" if wind else "N/A"
                wind_lbl = wx.StaticText(self.content_panel, label=wind_str)
                row.Add(wind_lbl, widths[5], wx.RIGHT, 5)
                
                grid_sizer.Add(row, 0, wx.EXPAND | wx.ALL, 5)
                grid_sizer.Add(wx.StaticLine(self.content_panel), 0, wx.EXPAND)
            
            self.content_sizer.Add(grid_sizer, 0, wx.EXPAND | wx.ALL, 5)
        
        # Attribution
        attr = wx.StaticText(self.content_panel, label="Historical data by Open-Meteo.com")
        attr.SetForegroundColour(wx.Colour(128, 128, 128))
        self.content_sizer.Add(attr, 0, wx.ALL, 10)
        
        self.content_panel.Layout()
        self.content_panel.FitInside()
        self.Refresh()
    
    def format_temp(self, celsius):
        if celsius is None:
            return "N/A"
        if self.is_fahrenheit:
            temp_f = (celsius * 9/5) + 32
            return f"{temp_f:.0f}°F"
        return f"{celsius:.0f}°C"


class WeatherConfigDialog(wx.Dialog):
    def __init__(self, parent, current_config):
        super().__init__(parent, title="Configure Weather Display", size=(600, 500))
        self.config = current_config.copy()
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        vbox.Add(wx.StaticText(panel, label="Select weather details to display:"), 0, wx.ALL, 10)
        
        nb = wx.Notebook(panel)
        self.checkboxes = {'current': {}, 'hourly': {}, 'daily': {}}
        self.unit_controls = {}
        
        # Helper to create tabs
        def add_tab(name, key, options):
            p = wx.Panel(nb)
            sz = wx.BoxSizer(wx.VERTICAL)
            for opt_key, label in options:
                cb = wx.CheckBox(p, label=label)
                cb.SetValue(self.config[key].get(opt_key, False))
                self.checkboxes[key][opt_key] = cb
                sz.Add(cb, 0, wx.ALL, 5)
            p.SetSizer(sz)
            nb.AddPage(p, name)

        add_tab("Current", 'current', [
            ('temperature', 'Temperature'), ('feels_like', 'Feels Like'),
            ('humidity', 'Humidity'), ('wind_speed', 'Wind Speed'),
            ('wind_direction', 'Wind Direction'), ('pressure', 'Pressure'),
            ('visibility', 'Visibility'), ('uv_index', 'UV Index'),
            ('precipitation', 'Precipitation'), ('cloud_cover', 'Cloud Cover'),
            ('snowfall', 'Snowfall'), ('snow_depth', 'Snow Depth'), ('rain', 'Rain'), ('showers', 'Showers')
        ])
        
        add_tab("Hourly", 'hourly', [
            ('temperature', 'Temperature'), ('feels_like', 'Feels Like'),
            ('humidity', 'Humidity'), ('precipitation', 'Precipitation'),
            ('wind_speed', 'Wind Speed'), ('wind_direction', 'Wind Direction'),
            ('cloud_cover', 'Cloud Cover'), ('snowfall', 'Snowfall'),
            ('rain', 'Rain'), ('showers', 'Showers')
        ])
        
        add_tab("Daily", 'daily', [
            ('temperature_max', 'High Temp'), ('temperature_min', 'Low Temp'),
            ('sunrise', 'Sunrise'), ('sunset', 'Sunset'),
            ('precipitation_sum', 'Precip Total'), ('precipitation_hours', 'Precip Hours'),
            ('wind_speed_max', 'Max Wind'), ('wind_direction_dominant', 'Wind Direction'),
            ('snowfall_sum', 'Snowfall Total'), ('rain_sum', 'Rain Total'), ('showers_sum', 'Showers Total')
        ])
        
        # Units Tab
        units_panel = wx.Panel(nb)
        units_sizer = wx.BoxSizer(wx.VERTICAL)
        
        # Temperature units
        temp_box = wx.StaticBox(units_panel, label="Temperature")
        temp_sizer = wx.StaticBoxSizer(temp_box, wx.HORIZONTAL)
        self.unit_controls['temp_f'] = wx.RadioButton(units_panel, label="Fahrenheit (°F)", style=wx.RB_GROUP)
        self.unit_controls['temp_c'] = wx.RadioButton(units_panel, label="Celsius (°C)")
        self.unit_controls['temp_f'].SetValue(self.config['units'].get('temperature', 'F') == 'F')
        self.unit_controls['temp_c'].SetValue(self.config['units'].get('temperature', 'F') == 'C')
        temp_sizer.Add(self.unit_controls['temp_f'], 0, wx.ALL, 5)
        temp_sizer.Add(self.unit_controls['temp_c'], 0, wx.ALL, 5)
        units_sizer.Add(temp_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # Wind speed units
        wind_box = wx.StaticBox(units_panel, label="Wind Speed")
        wind_sizer = wx.StaticBoxSizer(wind_box, wx.HORIZONTAL)
        self.unit_controls['wind_mph'] = wx.RadioButton(units_panel, label="Miles per hour (mph)", style=wx.RB_GROUP)
        self.unit_controls['wind_kmh'] = wx.RadioButton(units_panel, label="Kilometers per hour (km/h)")
        self.unit_controls['wind_mph'].SetValue(self.config['units'].get('wind_speed', 'mph') == 'mph')
        self.unit_controls['wind_kmh'].SetValue(self.config['units'].get('wind_speed', 'mph') == 'km/h')
        wind_sizer.Add(self.unit_controls['wind_mph'], 0, wx.ALL, 5)
        wind_sizer.Add(self.unit_controls['wind_kmh'], 0, wx.ALL, 5)
        units_sizer.Add(wind_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        # Precipitation units
        precip_box = wx.StaticBox(units_panel, label="Precipitation")
        precip_sizer = wx.StaticBoxSizer(precip_box, wx.HORIZONTAL)
        self.unit_controls['precip_in'] = wx.RadioButton(units_panel, label="Inches (in)", style=wx.RB_GROUP)
        self.unit_controls['precip_mm'] = wx.RadioButton(units_panel, label="Millimeters (mm)")
        self.unit_controls['precip_in'].SetValue(self.config['units'].get('precipitation', 'in') == 'in')
        self.unit_controls['precip_mm'].SetValue(self.config['units'].get('precipitation', 'in') == 'mm')
        precip_sizer.Add(self.unit_controls['precip_in'], 0, wx.ALL, 5)
        precip_sizer.Add(self.unit_controls['precip_mm'], 0, wx.ALL, 5)
        units_sizer.Add(precip_sizer, 0, wx.EXPAND | wx.ALL, 10)
        
        units_panel.SetSizer(units_sizer)
        nb.AddPage(units_panel, "Units")
        
        vbox.Add(nb, 1, wx.EXPAND | wx.ALL, 10)
        
        btns = wx.StdDialogButtonSizer()
        ok_btn = wx.Button(panel, wx.ID_OK)
        apply_btn = wx.Button(panel, wx.ID_APPLY, "Apply")
        cancel_btn = wx.Button(panel, wx.ID_CANCEL)
        btns.AddButton(ok_btn)
        btns.AddButton(apply_btn)
        btns.AddButton(cancel_btn)
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        self.Bind(wx.EVT_BUTTON, self.on_ok, id=wx.ID_OK)
        self.Bind(wx.EVT_BUTTON, self.on_apply, id=wx.ID_APPLY)

    def on_ok(self, event):
        for section in self.checkboxes:
            for key, cb in self.checkboxes[section].items():
                self.config[section][key] = cb.GetValue()
        
        # Save unit preferences
        self.config['units']['temperature'] = 'F' if self.unit_controls['temp_f'].GetValue() else 'C'
        self.config['units']['wind_speed'] = 'mph' if self.unit_controls['wind_mph'].GetValue() else 'km/h'
        self.config['units']['precipitation'] = 'in' if self.unit_controls['precip_in'].GetValue() else 'mm'
        
        self.EndModal(wx.ID_OK)
    
    def on_apply(self, event):
        """Apply changes without closing the dialog"""
        for section in self.checkboxes:
            for key, cb in self.checkboxes[section].items():
                self.config[section][key] = cb.GetValue()
        
        # Save unit preferences
        self.config['units']['temperature'] = 'F' if self.unit_controls['temp_f'].GetValue() else 'C'
        self.config['units']['wind_speed'] = 'mph' if self.unit_controls['wind_mph'].GetValue() else 'km/h'
        self.config['units']['precipitation'] = 'in' if self.unit_controls['precip_in'].GetValue() else 'mm'
        
        # Notify parent to apply changes
        parent = self.GetParent()
        if parent and hasattr(parent, 'apply_config_changes'):
            parent.apply_config_changes(self.config)

    def get_configuration(self):
        return self.config


class AccessibleWeatherApp(wx.Frame):
    def __init__(self, city_file=None):
        super().__init__(None, title="FastWeather", size=(1000, 700))
        
        # Determine user data directory if no file provided
        if city_file is None:
            sp = wx.StandardPaths.Get()
            user_data_dir = sp.GetUserDataDir()
            if not os.path.exists(user_data_dir):
                os.makedirs(user_data_dir)
            self.city_file = os.path.join(user_data_dir, "city.json")
            self.config_file = os.path.join(user_data_dir, "config.json")
        else:
            self.city_file = city_file
            sp = wx.StandardPaths.Get()
            user_data_dir = sp.GetUserDataDir()
            if not os.path.exists(user_data_dir):
                os.makedirs(user_data_dir)
            self.config_file = os.path.join(user_data_dir, "config.json")
            
        self.city_data = {}
        self.weather_config = {
            'current': {'temperature': True, 'feels_like': True, 'humidity': True, 'wind_speed': True, 'wind_direction': True, 'pressure': False, 'visibility': False, 'uv_index': False, 'precipitation': True, 'cloud_cover': False, 'snowfall': False, 'snow_depth': False, 'rain': False, 'showers': False},
            'hourly': {'temperature': True, 'feels_like': False, 'humidity': False, 'precipitation': True, 'wind_speed': False, 'wind_direction': False, 'cloud_cover': False, 'snowfall': False, 'rain': False, 'showers': False},
            'daily': {'temperature_max': True, 'temperature_min': True, 'sunrise': True, 'sunset': True, 'precipitation_sum': True, 'precipitation_hours': False, 'wind_speed_max': False, 'wind_direction_dominant': False, 'snowfall_sum': False, 'rain_sum': False, 'showers_sum': False},
            'units': {'temperature': 'F', 'wind_speed': 'mph', 'precipitation': 'in'}
        }
        
        # Load cached city coordinates for browsing
        self.us_cities_cache = None
        self.intl_cities_cache = None
        self.load_cached_cities()
        
        self.load_city_data()
        self.load_config()
        self.init_ui()
        self.setup_shortcuts()
        
        self.Bind(EVT_WEATHER_READY, self.on_weather_ready)
        self.Bind(EVT_WEATHER_ERROR, self.on_weather_error)
        self.Bind(EVT_GEO_READY, self.on_geo_ready)
        self.Bind(EVT_GEO_ERROR, self.on_geo_error)
        self.Bind(EVT_REGIONAL_WEATHER_READY, self.on_regional_weather_ready)
        self.Bind(EVT_REGIONAL_WEATHER_ERROR, self.on_regional_weather_error)
        self.Bind(EVT_PRECIPITATION_READY, self.on_precipitation_ready)
        self.Bind(EVT_PRECIPITATION_ERROR, self.on_precipitation_error)
        self.Bind(EVT_HISTORICAL_READY, self.on_historical_ready)
        self.Bind(EVT_HISTORICAL_ERROR, self.on_historical_error)
        
        wx.CallAfter(self.set_initial_focus)

    def init_ui(self):
        self.panel = wx.Panel(self)
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.book = wx.Simplebook(self.panel)
        
        # Main View
        self.main_view = wx.Panel(self.book)
        mv_sizer = wx.BoxSizer(wx.VERTICAL)
        
        # Input
        sb_input = wx.StaticBox(self.main_view, label="Add New City")
        inp_box = wx.StaticBoxSizer(sb_input, wx.VERTICAL)
        inp_row = wx.BoxSizer(wx.HORIZONTAL)
        self.city_input = wx.TextCtrl(self.main_view, style=wx.TE_PROCESS_ENTER)
        self.city_input.SetHint("City name or zip code")
        self.add_btn = wx.Button(self.main_view, label="Add City")
        inp_row.Add(wx.StaticText(self.main_view, label="Enter city:"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 5)
        inp_row.Add(self.city_input, 1, wx.EXPAND | wx.RIGHT, 5)
        inp_row.Add(self.add_btn, 0)
        inp_box.Add(inp_row, 0, wx.EXPAND | wx.ALL, 5)
        
        # Browse Cities button
        browse_row = wx.BoxSizer(wx.HORIZONTAL)
        self.browse_btn = wx.Button(self.main_view, label="Browse Cities by State/Country")
        browse_row.Add(self.browse_btn, 1, wx.EXPAND)
        inp_box.Add(browse_row, 0, wx.EXPAND | wx.ALL, 5)
        
        mv_sizer.Add(inp_box, 0, wx.EXPAND | wx.ALL, 10)
        
        # List
        sb_list = wx.StaticBox(self.main_view, label="Your Cities")
        list_box = wx.StaticBoxSizer(sb_list, wx.VERTICAL)
        self.city_list = wx.ListBox(self.main_view, style=wx.LB_SINGLE | wx.WANTS_CHARS)
        list_box.Add(self.city_list, 1, wx.EXPAND | wx.ALL, 5)
        
        btn_row = wx.BoxSizer(wx.HORIZONTAL)
        self.btn_up = wx.Button(self.main_view, label="Move Up")
        self.btn_down = wx.Button(self.main_view, label="Move Down")
        self.btn_remove = wx.Button(self.main_view, label="Remove")
        self.btn_refresh = wx.Button(self.main_view, label="Refresh")
        self.btn_full = wx.Button(self.main_view, label="Full Weather")
        self.btn_config_main = wx.Button(self.main_view, label="Configure")
        
        # New feature buttons
        self.btn_weather_around_me = wx.Button(self.main_view, label="Weather Around Me")
        self.btn_precipitation = wx.Button(self.main_view, label="Expected Precipitation")
        self.btn_historical = wx.Button(self.main_view, label="Historical Weather")
        
        for b in [self.btn_up, self.btn_down, self.btn_remove, self.btn_refresh, self.btn_full, 
                  self.btn_config_main, self.btn_weather_around_me, self.btn_precipitation, self.btn_historical]:
            btn_row.Add(b, 0, wx.RIGHT, 5)
        list_box.Add(btn_row, 0, wx.ALIGN_CENTER | wx.ALL, 5)
        mv_sizer.Add(list_box, 1, wx.EXPAND | wx.ALL, 10)
        
        self.main_view.SetSizer(mv_sizer)
        
        # Full View
        self.full_view = wx.Panel(self.book)
        fv_sizer = wx.BoxSizer(wx.VERTICAL)
        
        head_row = wx.BoxSizer(wx.HORIZONTAL)
        self.btn_back = wx.Button(self.full_view, label="<- Back")
        self.lbl_full_title = wx.StaticText(self.full_view, label="Full Weather")
        self.lbl_full_title.SetFont(wx.Font(14, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
        self.btn_config = wx.Button(self.full_view, label="Configure")
        head_row.Add(self.btn_back, 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        head_row.Add(self.lbl_full_title, 1, wx.ALIGN_CENTER_VERTICAL)
        head_row.Add(self.btn_config, 0, wx.ALIGN_CENTER_VERTICAL)
        fv_sizer.Add(head_row, 0, wx.EXPAND | wx.ALL, 10)
        
        self.weather_display = wx.ListBox(self.full_view, style=wx.LB_SINGLE)
        self.weather_display.SetFont(wx.Font(10, wx.FONTFAMILY_TELETYPE, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL))
        fv_sizer.Add(self.weather_display, 1, wx.EXPAND | wx.ALL, 10)
        self.full_view.SetSizer(fv_sizer)
        
        self.book.AddPage(self.main_view, "Main")
        self.book.AddPage(self.full_view, "Full")
        self.sizer.Add(self.book, 1, wx.EXPAND)
        self.panel.SetSizer(self.sizer)
        
        self.statusbar = self.CreateStatusBar(2)
        self.statusbar.SetStatusText("Ready", 0)
        self.statusbar.SetStatusText("Weather: Open-Meteo.com | Geocoding: OpenStreetMap", 1)
        
        # Bindings
        self.Bind(wx.EVT_BUTTON, self.on_add_city, self.add_btn)
        self.city_input.Bind(wx.EVT_TEXT_ENTER, self.on_add_city)
        self.Bind(wx.EVT_BUTTON, self.on_browse_cities, self.browse_btn)
        self.Bind(wx.EVT_LISTBOX, self.on_select, self.city_list)
        self.city_list.Bind(wx.EVT_LISTBOX_DCLICK, self.on_full_weather)
        self.Bind(wx.EVT_BUTTON, self.on_move_up, self.btn_up)
        self.Bind(wx.EVT_BUTTON, self.on_move_down, self.btn_down)
        self.Bind(wx.EVT_BUTTON, self.on_remove, self.btn_remove)
        self.Bind(wx.EVT_BUTTON, self.on_refresh, self.btn_refresh)
        self.Bind(wx.EVT_BUTTON, self.on_full_weather, self.btn_full)
        self.Bind(wx.EVT_BUTTON, self.on_back, self.btn_back)
        self.Bind(wx.EVT_BUTTON, self.on_config, self.btn_config)
        self.Bind(wx.EVT_BUTTON, self.on_config, self.btn_config_main)
        self.city_list.Bind(wx.EVT_KEY_DOWN, self.on_list_key)
        
        # New feature bindings
        self.Bind(wx.EVT_BUTTON, self.on_weather_around_me, self.btn_weather_around_me)
        self.Bind(wx.EVT_BUTTON, self.on_precipitation, self.btn_precipitation)
        self.Bind(wx.EVT_BUTTON, self.on_historical, self.btn_historical)
        
        self.update_city_list()

    def on_list_key(self, event):
        keycode = event.GetKeyCode()
        if keycode == wx.WXK_RETURN or keycode == wx.WXK_NUMPAD_ENTER:
            self.on_full_weather(event)
        elif keycode == wx.WXK_TAB:
            flags = wx.NavigationKeyEvent.IsForward
            if event.ShiftDown():
                flags = wx.NavigationKeyEvent.IsBackward
            self.city_list.Navigate(flags)
        else:
            event.Skip()

    def setup_shortcuts(self):
        self.ID_REFRESH = wx.NewIdRef()
        self.ID_REMOVE = wx.NewIdRef()
        self.ID_MOVE_UP = wx.NewIdRef()
        self.ID_MOVE_DOWN = wx.NewIdRef()
        self.ID_ESCAPE = wx.NewIdRef()
        self.ID_FULL_WEATHER = wx.NewIdRef()
        self.ID_NEW_CITY = wx.NewIdRef()
        self.ID_CONFIGURE = wx.NewIdRef()
        self.ID_WEATHER_AROUND_ME = wx.NewIdRef()
        self.ID_PRECIPITATION = wx.NewIdRef()
        self.ID_HISTORICAL = wx.NewIdRef()
        
        self.Bind(wx.EVT_MENU, self.on_refresh, id=self.ID_REFRESH)
        self.Bind(wx.EVT_MENU, self.on_remove, id=self.ID_REMOVE)
        self.Bind(wx.EVT_MENU, self.on_move_up, id=self.ID_MOVE_UP)
        self.Bind(wx.EVT_MENU, self.on_move_down, id=self.ID_MOVE_DOWN)
        self.Bind(wx.EVT_MENU, self.on_escape, id=self.ID_ESCAPE)
        self.Bind(wx.EVT_MENU, self.on_full_weather, id=self.ID_FULL_WEATHER)
        self.Bind(wx.EVT_MENU, self.on_focus_new_city, id=self.ID_NEW_CITY)
        self.Bind(wx.EVT_MENU, self.on_config, id=self.ID_CONFIGURE)
        self.Bind(wx.EVT_MENU, self.on_weather_around_me, id=self.ID_WEATHER_AROUND_ME)
        self.Bind(wx.EVT_MENU, self.on_precipitation, id=self.ID_PRECIPITATION)
        self.Bind(wx.EVT_MENU, self.on_historical, id=self.ID_HISTORICAL)
        
        accel = [
            (wx.ACCEL_NORMAL, wx.WXK_F5, self.ID_REFRESH),
            (wx.ACCEL_CTRL, ord('R'), self.ID_REFRESH),
            (wx.ACCEL_NORMAL, wx.WXK_DELETE, self.ID_REMOVE),
            (wx.ACCEL_ALT, ord('U'), self.ID_MOVE_UP),
            (wx.ACCEL_ALT, ord('D'), self.ID_MOVE_DOWN),
            (wx.ACCEL_NORMAL, wx.WXK_ESCAPE, self.ID_ESCAPE),
            (wx.ACCEL_ALT, ord('F'), self.ID_FULL_WEATHER),
            (wx.ACCEL_ALT, ord('N'), self.ID_NEW_CITY),
            (wx.ACCEL_ALT, ord('C'), self.ID_CONFIGURE),
            (wx.ACCEL_ALT, ord('W'), self.ID_WEATHER_AROUND_ME),
            (wx.ACCEL_ALT, ord('P'), self.ID_PRECIPITATION),
            (wx.ACCEL_ALT, ord('H'), self.ID_HISTORICAL),
        ]
        self.SetAcceleratorTable(wx.AcceleratorTable(accel))

    def on_escape(self, event):
        if self.book.GetSelection() == 1: self.on_back(event)
    
    def on_focus_new_city(self, event):
        if self.book.GetSelection() == 0:
            self.city_input.SetFocus()

    def set_initial_focus(self):
        if self.city_list.GetCount() > 0:
            self.city_list.SetSelection(0)
            self.city_list.SetFocus()
        else:
            self.city_input.SetFocus()
        self.update_buttons()

    def update_buttons(self):
        sel = self.city_list.GetSelection()
        has_sel = sel != wx.NOT_FOUND
        for b in [self.btn_remove, self.btn_refresh, self.btn_full, 
                  self.btn_weather_around_me, self.btn_precipitation, self.btn_historical]:
            b.Enable(has_sel)
        self.btn_up.Enable(has_sel and sel > 0)
        self.btn_down.Enable(has_sel and sel < self.city_list.GetCount() - 1)

    def load_city_data(self):
        loaded = False
        if os.path.exists(self.city_file):
            try:
                with open(self.city_file) as f:
                    data = json.load(f)
                    if data:
                        self.city_data = data
                        loaded = True
            except:
                pass
        
        if not loaded:
            default_path = None
            if getattr(sys, 'frozen', False):
                default_path = os.path.join(sys._MEIPASS, "city.json")
            else:
                default_path = os.path.join(os.path.dirname(__file__), "city.json")
            
            if default_path and os.path.exists(default_path):
                try:
                    with open(default_path) as f:
                        self.city_data = json.load(f)
                        loaded = True
                except: pass

        if not loaded:
            self.city_data = DEFAULT_CITIES.copy()
            
        if not os.path.exists(self.city_file) and self.city_data:
             self.save_city_data()

    def save_city_data(self):
        try:
            with open(self.city_file, 'w') as f: json.dump(self.city_data, f, indent=4)
        except: pass

    def load_config(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file) as f:
                    saved_config = json.load(f)
                    for section, options in saved_config.items():
                        if section in self.weather_config:
                            for key, value in options.items():
                                self.weather_config[section][key] = value
            except: pass
    
    def load_cached_cities(self):
        script_dir = os.path.dirname(__file__)
        possible_paths = [
            os.path.join(script_dir, "webapp", "us-cities-cached.json"),
            os.path.join(script_dir, "webapp", "international-cities-cached.json"),
            os.path.join(script_dir, "us-cities-cached.json"),
            os.path.join(script_dir, "international-cities-cached.json"),
            os.path.join(getattr(sys, '_MEIPASS', script_dir), "us-cities-cached.json"),
            os.path.join(getattr(sys, '_MEIPASS', script_dir), "international-cities-cached.json"),
        ]
        
        for path in possible_paths:
            if "us-cities" in path and os.path.exists(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        self.us_cities_cache = json.load(f)
                        break
                except: pass
        
        for path in possible_paths:
            if "international-cities" in path and os.path.exists(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        self.intl_cities_cache = json.load(f)
                        break
                except: pass

    def save_config(self):
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.weather_config, f, indent=4)
        except: pass

    def update_city_list(self, reload=True):
        sel_str = self.city_list.GetStringSelection().split(" - ")[0] if self.city_list.GetSelection() != wx.NOT_FOUND else None
        self.city_list.Clear()
        for city in self.city_data: self.city_list.Append(f"{city} - Loading...")
        if reload: self.load_all_weather()
        
        if sel_str:
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(sel_str):
                    self.city_list.SetSelection(i)
                    break
        elif self.city_list.GetCount() > 0: self.city_list.SetSelection(0)
        self.update_buttons()

    def load_all_weather(self):
        for i in range(self.city_list.GetCount()):
            city = self.city_list.GetString(i).split(" - ")[0]
            if city in self.city_data:
                lat, lon = self.city_data[city]
                WeatherFetchThread(self, city, lat, lon, "basic")

    def on_add_city(self, event):
        val = self.city_input.GetValue().strip()
        if val:
            self.statusbar.SetStatusText("Searching...", 0)
            self.add_btn.Disable()
            GeocodingThread(self, val)

    def on_geo_ready(self, event):
        orig, matches = event.data
        self.add_btn.Enable()
        self.statusbar.SetStatusText("Ready", 0)
        if not matches:
            wx.MessageBox("City not found", "Error", wx.OK | wx.ICON_WARNING)
            return
        if len(matches) == 1: self.add_city_match(matches[0])
        else:
            dlg = CitySelectionDialog(self, matches, orig)
            if dlg.ShowModal() == wx.ID_OK: self.add_city_match(dlg.selected_match)
            dlg.Destroy()

    def on_geo_error(self, event):
        self.add_btn.Enable()
        wx.MessageBox(f"Error: {event.data}", "Error", wx.OK | wx.ICON_ERROR)

    def add_city_match(self, match):
        name = match['display']
        if name in self.city_data: return
        self.city_data[name] = [match['lat'], match['lon']]
        self.save_city_data()
        self.update_city_list()
        self.city_input.Clear()
        
        for i in range(self.city_list.GetCount()):
            if self.city_list.GetString(i).startswith(name):
                self.city_list.SetSelection(i)
                break
        self.update_buttons()
    
    def on_browse_cities(self, event):
        if not self.us_cities_cache and not self.intl_cities_cache:
            wx.MessageBox(
                "City data files not found. Please ensure us-cities-cached.json and "
                "international-cities-cached.json are in the application directory.",
                "Data Not Available",
                wx.OK | wx.ICON_INFORMATION
            )
            return
        
        dlg = LocationBrowserDialog(self, self.us_cities_cache, self.intl_cities_cache)
        if dlg.ShowModal() == wx.ID_OK:
            cities_to_add = dlg.get_selected_cities()
            added_count = 0
            skipped_count = 0
            
            for city_name, lat, lon in cities_to_add:
                if city_name not in self.city_data:
                    self.city_data[city_name] = [lat, lon]
                    added_count += 1
                else:
                    skipped_count += 1
            
            if added_count > 0:
                self.save_city_data()
                self.update_city_list()
                
                msg = f"Added {added_count} cit{'y' if added_count == 1 else 'ies'}"
                if skipped_count > 0:
                    msg += f" ({skipped_count} already in list)"
                wx.MessageBox(msg, "Cities Added", wx.OK | wx.ICON_INFORMATION)
            elif skipped_count > 0:
                wx.MessageBox(
                    f"All {skipped_count} selected cit{'y was' if skipped_count == 1 else 'ies were'} already in your list",
                    "No New Cities",
                    wx.OK | wx.ICON_INFORMATION
                )
        
        dlg.Destroy()

    def on_select(self, event): self.update_buttons()

    def on_remove(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        city = self.city_list.GetString(sel).split(" - ")[0]
        if wx.MessageBox(f"Remove {city}?", "Confirm", wx.YES_NO) == wx.YES:
            del self.city_data[city]
            self.save_city_data()
            self.update_city_list(False)

    def on_move_up(self, event): self.move_city(-1)
    def on_move_down(self, event): self.move_city(1)

    def move_city(self, direction):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        new_sel = sel + direction
        if not (0 <= new_sel < self.city_list.GetCount()): return
        
        keys = list(self.city_data.keys())
        keys[sel], keys[new_sel] = keys[new_sel], keys[sel]
        self.city_data = {k: self.city_data[k] for k in keys}
        self.save_city_data()
        
        t1, t2 = self.city_list.GetString(sel), self.city_list.GetString(new_sel)
        self.city_list.SetString(sel, t2)
        self.city_list.SetString(new_sel, t1)
        self.city_list.SetSelection(new_sel)
        self.update_buttons()

    def on_refresh(self, event):
        sel = self.city_list.GetSelection()
        if sel != wx.NOT_FOUND:
            city = self.city_list.GetString(sel).split(" - ")[0]
            lat, lon = self.city_data[city]
            WeatherFetchThread(self, city, lat, lon, "basic")

    def on_full_weather(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        city = self.city_list.GetString(sel).split(" - ")[0]
        lat, lon = self.city_data[city]
        self.current_full_city = (city, lat, lon)
        self.lbl_full_title.SetLabel(f"Full Weather - {city}")
        self.weather_display.Clear()
        self.weather_display.Append("Loading...")
        self.book.SetSelection(1)
        self.weather_display.SetFocus()
        WeatherFetchThread(self, city, lat, lon, "full")

    def on_back(self, event):
        self.book.SetSelection(0)
        self.city_list.SetFocus()

    def on_config(self, event):
        dlg = WeatherConfigDialog(self, self.weather_config)
        if dlg.ShowModal() == wx.ID_OK:
            self.weather_config = dlg.get_configuration()
            self.save_config()
            if hasattr(self, 'current_full_city'):
                self.on_full_weather(None)
        dlg.Destroy()
    
    def apply_config_changes(self, new_config):
        self.weather_config = new_config.copy()
        self.save_config()
        self.load_all_weather()
        if hasattr(self, 'current_full_city') and self.book.GetSelection() == 1:
            self.on_full_weather(None)

    # New feature handlers
    def on_weather_around_me(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        city = self.city_list.GetString(sel).split(" - ")[0]
        lat, lon = self.city_data[city]
        
        is_f = self.weather_config['units'].get('temperature', 'F') == 'F'
        dlg = WeatherAroundMeDialog(self, city, lat, lon, is_f)
        dlg.ShowModal()
        dlg.Destroy()

    def on_precipitation(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        city = self.city_list.GetString(sel).split(" - ")[0]
        lat, lon = self.city_data[city]
        
        is_f = self.weather_config['units'].get('temperature', 'F') == 'F'
        dlg = PrecipitationNowcastDialog(self, city, lat, lon, is_f)
        dlg.ShowModal()
        dlg.Destroy()

    def on_historical(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND: return
        city = self.city_list.GetString(sel).split(" - ")[0]
        lat, lon = self.city_data[city]
        
        is_f = self.weather_config['units'].get('temperature', 'F') == 'F'
        dlg = HistoricalWeatherDialog(self, city, lat, lon, is_f)
        dlg.ShowModal()
        dlg.Destroy()

    # Event handlers for new features
    def on_regional_weather_ready(self, event):
        city, data, distance = event.data
        # Find the dialog and update it
        for child in self.GetChildren():
            if isinstance(child, WeatherAroundMeDialog) and child.city_name == city:
                child.display_regional_weather(data, distance)
                break

    def on_regional_weather_error(self, event):
        city, error = event.data
        wx.MessageBox(f"Error loading regional weather: {error}", "Error", wx.OK | wx.ICON_ERROR)

    def on_precipitation_ready(self, event):
        city, data = event.data
        for child in self.GetChildren():
            if isinstance(child, PrecipitationNowcastDialog) and child.city_name == city:
                child.display_precipitation_data(data)
                break

    def on_precipitation_error(self, event):
        city, error = event.data
        wx.MessageBox(f"Error loading precipitation data: {error}", "Error", wx.OK | wx.ICON_ERROR)

    def on_historical_ready(self, event):
        city, data, month, day = event.data
        for child in self.GetChildren():
            if isinstance(child, HistoricalWeatherDialog) and child.city_name == city:
                child.display_historical_data(data, month, day)
                break

    def on_historical_error(self, event):
        city, error = event.data
        wx.MessageBox(f"Error loading historical data: {error}", "Error", wx.OK | wx.ICON_ERROR)

    def degrees_to_cardinal(self, degrees):
        directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        index = round(degrees / 45) % 8
        return directions[index]
    
    def format_temperature(self, temp_c):
        if self.weather_config['units']['temperature'] == 'C':
            return f"{temp_c:.1f}°C"
        else:
            temp_f = (temp_c * 9/5) + 32
            return f"{temp_f:.1f}°F"
    
    def format_temperature_short(self, temp_c):
        if self.weather_config['units']['temperature'] == 'C':
            return f"{temp_c:.0f}°C"
        else:
            temp_f = (temp_c * 9/5) + 32
            return f"{temp_f:.0f}°F"
    
    def format_wind_speed(self, wind_kmh):
        if self.weather_config['units']['wind_speed'] == 'km/h':
            return f"{wind_kmh:.1f} km/h"
        else:
            wind_mph = wind_kmh * KMH_TO_MPH
            return f"{wind_mph:.1f} mph"
    
    def format_precipitation(self, precip_mm):
        if self.weather_config['units']['precipitation'] == 'mm':
            return f"{precip_mm:.1f}mm"
        else:
            precip_in = precip_mm * MM_TO_INCHES
            return f"{precip_in:.2f}\""

    def on_weather_ready(self, event):
        city, data = event.data
        
        curr = data.get("current", data.get("current_weather", {}))
        if curr:
            temp_c = curr.get("temperature_2m", curr.get("temperature", 0))
            
            cloud_text = ""
            if "cloud_cover" in curr:
                cc = curr["cloud_cover"]
                if cc <= 12: desc = "clear"
                elif cc <= 37: desc = "mostly clear"
                elif cc <= 62: desc = "partly cloudy"
                elif cc <= 87: desc = "mostly cloudy"
                else: desc = "cloudy"
                cloud_text = f", {desc}"
            else:
                hourly = data.get("hourly", {})
                if hourly and 'time' in hourly and 'cloudcover' in hourly:
                    times = hourly['time']
                    cloudcover = hourly['cloudcover']
                    curr_time_str = curr.get('time')
                    
                    idx = -1
                    if curr_time_str in times:
                        idx = times.index(curr_time_str)
                    else:
                        try:
                            curr_dt = datetime.strptime(curr_time_str, "%Y-%m-%dT%H:%M")
                            for i, t_str in enumerate(times):
                                try:
                                    t_dt = datetime.strptime(t_str, "%Y-%m-%dT%H:%M")
                                    if t_dt.replace(minute=0) == curr_dt.replace(minute=0):
                                        idx = i
                                        break
                                except: continue
                        except: pass
                    
                    if idx != -1 and idx < len(cloudcover):
                        cc = cloudcover[idx]
                        if cc <= 12: desc = "clear"
                        elif cc <= 37: desc = "mostly clear"
                        elif cc <= 62: desc = "partly cloudy"
                        elif cc <= 87: desc = "mostly cloudy"
                        else: desc = "cloudy"
                        cloud_text = f", {desc}"
            
            daily_temps = ""
            daily = data.get("daily", {})
            if daily and daily.get("temperature_2m_max") and daily.get("temperature_2m_min"):
                temp_max_c = daily["temperature_2m_max"][0]
                temp_min_c = daily["temperature_2m_min"][0]
                temp_max = self.format_temperature_short(temp_max_c)
                temp_min = self.format_temperature_short(temp_min_c)
                daily_temps = f" (High: {temp_max}, Low: {temp_min})"
            
            precip_text = ""
            snowfall = curr.get("snowfall", 0)
            rain = curr.get("rain", 0)
            showers = curr.get("showers", 0)
            
            if snowfall >= 0.01:
                precip_text = " [Snow]"
            elif rain >= 0.01 or showers >= 0.01:
                precip_text = " [Rain]"
            
            temp_display = self.format_temperature_short(temp_c)
            new_text = f"{city} - {temp_display}{cloud_text}{precip_text}{daily_temps}"
            
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(city + " - "):
                    self.city_list.SetString(i, new_text)
                    break

        if hasattr(self, 'current_full_city') and self.current_full_city[0] == city and self.book.GetSelection() == 1:
            self.weather_display.Clear()
            lines = self.format_full_weather(city, data)
            for line in lines:
                stripped = line.strip()
                if stripped and not all(c in '-=' for c in stripped):
                    self.weather_display.Append(line)
            if self.weather_display.GetCount() > 0: self.weather_display.SetSelection(0)

    def on_weather_error(self, event):
        city, err = event.data
        if self.book.GetSelection() == 1 and self.lbl_full_title.GetLabel().endswith(city):
            self.weather_display.Append(f"Error: {err}")

    def format_full_weather(self, city, data):
        lines = []
        lines.append(f"Report for {city}")
        lines.append("="*40)
        
        curr = data.get("current", data.get("current_weather", {}))
        hourly = data.get("hourly", {})
        daily = data.get("daily", {})
        
        cfg_curr = self.weather_config['current']
        if curr:
            lines.append("CURRENT")
            
            def get_val(keys, default=0):
                if isinstance(keys, str): keys = [keys]
                for k in keys:
                    if k in curr: return curr[k]
                return default

            if cfg_curr.get('temperature', True):
                temp_c = get_val(['temperature_2m', 'temperature'])
                lines.append(f"Temp: {self.format_temperature(temp_c)}")
            
            if cfg_curr.get('feels_like', False):
                app_temp_c = get_val(['apparent_temperature'])
                lines.append(f"Feels Like: {self.format_temperature(app_temp_c)}")

            if cfg_curr.get('humidity', False):
                hum = get_val(['relative_humidity_2m'])
                lines.append(f"Humidity: {hum}%")

            if cfg_curr.get('pressure', False):
                pres = get_val(['pressure_msl', 'surface_pressure'])
                pres_in = pres * HPA_TO_INHG
                lines.append(f"Pressure: {pres_in:.2f} inHg")

            if cfg_curr.get('visibility', False):
                vis_m = get_val(['visibility'])
                vis_miles = vis_m / 1609.34
                lines.append(f"Visibility: {vis_miles:.1f} miles")

            if cfg_curr.get('uv_index', False):
                uv = get_val(['uv_index'])
                if uv == 0 and hourly and 'uv_index' in hourly and 'time' in hourly:
                    curr_time = curr.get('time')
                    if curr_time in hourly['time']:
                        idx = hourly['time'].index(curr_time)
                        uv = hourly['uv_index'][idx]
                lines.append(f"UV Index: {uv}")

            if cfg_curr.get('precipitation', False):
                precip = get_val(['precipitation'])
                if precip > 0:
                    lines.append(f"Precipitation: {self.format_precipitation(precip)}")

            if cfg_curr.get('cloud_cover', False):
                cc = get_val(['cloud_cover', 'cloudcover'])
                if cc is not None:
                    if cc <= 12: desc = "Clear"
                    elif cc <= 37: desc = "Mostly Clear"
                    elif cc <= 62: desc = "Partly Cloudy"
                    elif cc <= 87: desc = "Mostly Cloudy"
                    else: desc = "Cloudy"
                    lines.append(f"Cloud Cover: {cc}% ({desc})")

            if cfg_curr.get('snowfall', False):
                snow = get_val(['snowfall'])
                if snow >= 0.01:
                    lines.append(f"Snowfall: {self.format_precipitation(snow)}")
                elif snow == 0:
                    lines.append(f"Snowfall: None")

            if cfg_curr.get('snow_depth', False):
                depth = get_val(['snow_depth'])
                if depth >= 0.01:
                    depth_converted = depth * 1000
                    lines.append(f"Snow Depth: {self.format_precipitation(depth_converted)}")
                elif depth == 0:
                    lines.append(f"Snow Depth: None")

            if cfg_curr.get('rain', False):
                rain = get_val(['rain'])
                if rain >= 0.01:
                    lines.append(f"Rain: {self.format_precipitation(rain)}")
                elif rain == 0:
                    lines.append(f"Rain: None")

            if cfg_curr.get('showers', False):
                showers = get_val(['showers'])
                if showers >= 0.01:
                    lines.append(f"Showers: {self.format_precipitation(showers)}")
                elif showers == 0:
                    lines.append(f"Showers: None")

            if cfg_curr.get('wind_speed', True):
                wind_kmh = get_val(['wind_speed_10m', 'windspeed'])
                wind_dir = get_val(['wind_direction_10m', 'winddirection'])
                wind_card = self.degrees_to_cardinal(wind_dir)
                
                if cfg_curr.get('wind_direction', True):
                    lines.append(f"Wind: {self.format_wind_speed(wind_kmh)} {wind_card} ({wind_dir}°)")
                else:
                    lines.append(f"Wind: {self.format_wind_speed(wind_kmh)}")
            elif cfg_curr.get('wind_direction', True):
                wind_dir = get_val(['wind_direction_10m', 'winddirection'])
                wind_card = self.degrees_to_cardinal(wind_dir)
                lines.append(f"Wind Dir: {wind_card} ({wind_dir}°)")
                
            lines.append("")
            
        cfg_hourly = self.weather_config['hourly']
        if hourly and any(cfg_hourly.values()):
            lines.append("HOURLY")
            times = hourly.get('time', [])
            temps = hourly.get('temperature_2m', [])
            app_temps = hourly.get('apparent_temperature', [])
            precip = hourly.get('precipitation', [])
            humidity = hourly.get('relative_humidity_2m', [])
            wind_speeds = hourly.get('windspeed_10m', [])
            wind_dirs = hourly.get('winddirection_10m', [])
            cloud_cover = hourly.get('cloudcover', [])
            snowfall = hourly.get('snowfall', [])
            rain = hourly.get('rain', [])
            showers = hourly.get('showers', [])
            
            start = 0
            curr_time = curr.get('time') if curr else None
            
            if curr_time and times:
                try:
                    curr_dt = datetime.strptime(curr_time, "%Y-%m-%dT%H:%M")
                    first_dt = datetime.strptime(times[0], "%Y-%m-%dT%H:%M")
                    
                    diff_seconds = (curr_dt - first_dt).total_seconds()
                    idx = round(diff_seconds / 3600)
                    
                    if 0 <= idx < len(times):
                        start = idx
                except:
                    pass
                
            for i in range(start, min(start+24, len(times))):
                parts = []
                t = datetime.strptime(times[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                parts.append(f"{t}:")
                
                if cfg_hourly.get('temperature', True) and i < len(temps):
                    parts.append(self.format_temperature_short(temps[i]))
                
                if cfg_hourly.get('feels_like', False) and i < len(app_temps):
                    parts.append(f"Feels Like {self.format_temperature_short(app_temps[i])}")

                if cfg_hourly.get('precipitation', True) and i < len(precip):
                    p = precip[i]
                    if p > 0: parts.append(f"{self.format_precipitation(p)} precip")
                
                if cfg_hourly.get('humidity', True) and i < len(humidity):
                    parts.append(f"Humidity {humidity[i]}%")

                if cfg_hourly.get('cloud_cover', False) and i < len(cloud_cover):
                    cc = cloud_cover[i]
                    if cc <= 12: desc = "Clear"
                    elif cc <= 37: desc = "Mostly Clear"
                    elif cc <= 62: desc = "Partly Cloudy"
                    elif cc <= 87: desc = "Mostly Cloudy"
                    else: desc = "Cloudy"
                    parts.append(f"{desc} ({cc}%)")

                if cfg_hourly.get('snowfall', False) and i < len(snowfall):
                    s = snowfall[i]
                    if s >= 0.01: 
                        parts.append(f"{self.format_precipitation(s)} snow")

                if cfg_hourly.get('rain', False) and i < len(rain):
                    r = rain[i]
                    if r >= 0.01: 
                        parts.append(f"{self.format_precipitation(r)} rain")

                if cfg_hourly.get('showers', False) and i < len(showers):
                    sh = showers[i]
                    if sh >= 0.01: 
                        parts.append(f"{self.format_precipitation(sh)} showers")

                if cfg_hourly.get('wind_speed', False) and i < len(wind_speeds):
                    parts.append(self.format_wind_speed(wind_speeds[i]))
                    
                if cfg_hourly.get('wind_direction', False) and i < len(wind_dirs):
                    wd = self.degrees_to_cardinal(wind_dirs[i])
                    parts.append(f"{wd}")
                    
                lines.append(" ".join(parts))
            lines.append("")
            
        cfg_daily = self.weather_config['daily']
        if daily and any(cfg_daily.values()):
            lines.append("DAILY")
            times = daily.get('time', [])
            maxs = daily.get('temperature_2m_max', [])
            mins = daily.get('temperature_2m_min', [])
            precip_sum = daily.get('precipitation_sum', [])
            precip_hours = daily.get('precipitation_hours', [])
            wind_maxs = daily.get('windspeed_10m_max', [])
            wind_doms = daily.get('winddirection_10m_dominant', [])
            sunrise = daily.get('sunrise', [])
            sunset = daily.get('sunset', [])
            snowfall_sum = daily.get('snowfall_sum', [])
            rain_sum = daily.get('rain_sum', [])
            showers_sum = daily.get('showers_sum', [])
            
            for i in range(len(times)):
                d = datetime.strptime(times[i], "%Y-%m-%d").strftime("%a %b %d")
                parts = [f"{d}:"]
                
                if cfg_daily.get('temperature_max', True) and i < len(maxs):
                    parts.append(f"High {self.format_temperature_short(maxs[i])}")
                
                if cfg_daily.get('temperature_min', True) and i < len(mins):
                    parts.append(f"Low {self.format_temperature_short(mins[i])}")
                
                if cfg_daily.get('precipitation_sum', True) and i < len(precip_sum):
                    p = precip_sum[i]
                    if p > 0: parts.append(f"{self.format_precipitation(p)} precip")

                if cfg_daily.get('precipitation_hours', False) and i < len(precip_hours):
                    ph = precip_hours[i]
                    if ph > 0: parts.append(f"{ph:.1f}h precip")

                if cfg_daily.get('snowfall_sum', False) and i < len(snowfall_sum):
                    ss = snowfall_sum[i]
                    if ss >= 0.01: 
                        parts.append(f"{self.format_precipitation(ss)} snow")

                if cfg_daily.get('rain_sum', False) and i < len(rain_sum):
                    rs = rain_sum[i]
                    if rs >= 0.01: 
                        parts.append(f"{self.format_precipitation(rs)} rain")

                if cfg_daily.get('showers_sum', False) and i < len(showers_sum):
                    shs = showers_sum[i]
                    if shs >= 0.01: 
                        parts.append(f"{self.format_precipitation(shs)} showers")

                if cfg_daily.get('wind_speed_max', False) and i < len(wind_maxs):
                    parts.append(f"Max Wind {self.format_wind_speed(wind_maxs[i])}")

                if cfg_daily.get('wind_direction_dominant', False) and i < len(wind_doms):
                    wd = self.degrees_to_cardinal(wind_doms[i])
                    parts.append(f"Wind {wd}")
                
                if cfg_daily.get('sunrise', True) and i < len(sunrise):
                    sr = datetime.strptime(sunrise[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                    parts.append(f"Sunrise {sr}")
                
                if cfg_daily.get('sunset', True) and i < len(sunset):
                    ss = datetime.strptime(sunset[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                    parts.append(f"Sunset {ss}")
                    
                lines.append("".join(parts))
                
        lines.append("")
        lines.append("Data by Open-Meteo.com (CC BY 4.0)")
        return lines


if __name__ == "__main__":
    app = wx.App()
    
    parser = argparse.ArgumentParser(description="FastWeather")
    parser.add_argument("--reset", action="store_true", help="Reset (delete) the saved city data file")
    parser.add_argument("-c", "--config", help="Path to a specific city data JSON file to use")
    args = parser.parse_args()
    
    app_name = "FastWeather"
    app.SetAppName(app_name)
    sp = wx.StandardPaths.Get()
    user_data_dir = sp.GetUserDataDir()
    
    if not os.path.exists(user_data_dir):
        os.makedirs(user_data_dir)
        
    city_file = args.config if args.config else os.path.join(user_data_dir, "city.json")
    
    if args.reset:
        target_file = city_file
        if os.path.exists(target_file):
            try:
                os.remove(target_file)
                print(f"Reset complete: Removed {target_file}")
            except Exception as e:
                print(f"Error resetting data: {e}")
        else:
            print(f"No data file found at {target_file} to reset.")
            
    AccessibleWeatherApp(city_file).Show()
    app.MainLoop()
