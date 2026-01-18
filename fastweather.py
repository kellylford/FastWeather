#!/usr/bin/env python3
"""
Accessible GUI Weather Application using wxPython
Fully accessible with screen readers, keyboard navigation, and proper focus management
Uses Open-Meteo API (no API key required)
"""

__version__ = "1.1"

import sys
import json
import requests
import argparse
from datetime import datetime, timedelta
import threading
import os
import time
from concurrent.futures import ThreadPoolExecutor
import wx
import wx.adv
import wx.lib.newevent

# Constants
KMH_TO_MPH = 0.621371
MM_TO_INCHES = 0.0393701
HPA_TO_INHG = 0.02953
OPEN_METEO_API_URL = "https://api.open-meteo.com/v1/forecast"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

# Performance settings
WEATHER_CACHE_MINUTES = 10  # Cache weather data for 10 minutes
MAX_CONCURRENT_REQUESTS = 5  # Limit parallel API calls to be respectful

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

# Custom Events
WeatherReadyEvent, EVT_WEATHER_READY = wx.lib.newevent.NewEvent()
WeatherErrorEvent, EVT_WEATHER_ERROR = wx.lib.newevent.NewEvent()
GeoReadyEvent, EVT_GEO_READY = wx.lib.newevent.NewEvent()
GeoErrorEvent, EVT_GEO_ERROR = wx.lib.newevent.NewEvent()

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
            headers = {"User-Agent": "FastWeather GUI/1.0"}
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
    """Dialog for browsing cities by US State or International Country with hierarchical navigation"""
    def __init__(self, parent, us_cities_cache, intl_cities_cache):
        super().__init__(parent, title="Browse Cities by Location", size=(700, 600))
        self.us_cities_cache = us_cities_cache
        self.intl_cities_cache = intl_cities_cache
        self.selected_cities = []  # List of (city_name, lat, lon) tuples
        
        # Navigation state
        self.nav_level = 'root'  # 'root', 'states', 'countries', 'cities'
        self.current_location = None  # Current state or country name
        self.current_type = None  # 'us' or 'intl'
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        
        # Title label (dynamic based on navigation level)
        self.title_label = wx.StaticText(panel, label="Browse by Location Type")
        self.title_label.SetFont(wx.Font(12, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
        vbox.Add(self.title_label, 0, wx.ALL, 10)
        
        # Navigation buttons
        nav_box = wx.BoxSizer(wx.HORIZONTAL)
        self.back_btn = wx.Button(panel, label="<- Back")
        self.back_btn.Enable(False)
        nav_box.Add(self.back_btn, 0, wx.RIGHT, 5)
        vbox.Add(nav_box, 0, wx.EXPAND | wx.ALL, 10)
        
        # Main list (for navigation items, states/countries, or cities)
        vbox.Add(wx.StaticText(panel, label="Select an item:"), 0, wx.LEFT | wx.RIGHT, 10)
        self.main_list = wx.ListBox(panel, style=wx.LB_SINGLE)
        vbox.Add(self.main_list, 1, wx.EXPAND | wx.ALL, 10)
        
        # Action buttons (context-sensitive)
        action_box = wx.BoxSizer(wx.HORIZONTAL)
        self.select_btn = wx.Button(panel, label="Select")
        self.add_btn = wx.Button(panel, label="Add to My Cities")
        self.add_btn.Enable(False)
        action_box.Add(self.select_btn, 0, wx.RIGHT, 5)
        action_box.Add(self.add_btn, 0)
        vbox.Add(action_box, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        # Dialog buttons
        btns = wx.StdDialogButtonSizer()
        done_btn = wx.Button(panel, wx.ID_OK, "Done")
        cancel_btn = wx.Button(panel, wx.ID_CANCEL)
        btns.AddButton(done_btn)
        btns.AddButton(cancel_btn)
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        
        # Bind events
        self.Bind(wx.EVT_BUTTON, self.on_back, self.back_btn)
        self.Bind(wx.EVT_BUTTON, self.on_select, self.select_btn)
        self.Bind(wx.EVT_BUTTON, self.on_add_city, self.add_btn)
        self.Bind(wx.EVT_LISTBOX_DCLICK, self.on_list_dclick, self.main_list)
        self.Bind(wx.EVT_LISTBOX, self.on_list_select, self.main_list)
        
        # Initialize with root level
        self.show_root_level()
    
    def show_root_level(self):
        """Show the root level with U.S. States and International options"""
        self.nav_level = 'root'
        self.current_location = None
        self.current_type = None
        
        self.title_label.SetLabel("Browse by Location Type")
        self.back_btn.Enable(False)
        self.add_btn.Enable(False)
        
        self.main_list.Clear()
        self.main_list.Append("U.S. States")
        self.main_list.Append("International")
        self.main_list.SetSelection(0)
    
    def show_states_list(self):
        """Show list of U.S. states"""
        self.nav_level = 'states'
        self.current_type = 'us'
        
        self.title_label.SetLabel("Select a U.S. State")
        self.back_btn.Enable(True)
        self.add_btn.Enable(False)
        
        self.main_list.Clear()
        if self.us_cities_cache:
            states = sorted(self.us_cities_cache.keys())
            for state in states:
                self.main_list.Append(state)
            if self.main_list.GetCount() > 0:
                self.main_list.SetSelection(0)
    
    def show_countries_list(self):
        """Show list of international countries"""
        self.nav_level = 'countries'
        self.current_type = 'intl'
        
        self.title_label.SetLabel("Select a Country")
        self.back_btn.Enable(True)
        self.add_btn.Enable(False)
        
        self.main_list.Clear()
        if self.intl_cities_cache:
            countries = sorted(self.intl_cities_cache.keys())
            for country in countries:
                self.main_list.Append(country)
            if self.main_list.GetCount() > 0:
                self.main_list.SetSelection(0)
    
    def show_cities_list(self, location_name):
        """Show list of cities for the selected state or country"""
        self.nav_level = 'cities'
        self.current_location = location_name
        
        self.title_label.SetLabel(f"Cities in {location_name}")
        self.back_btn.Enable(True)
        
        self.main_list.Clear()
        
        # Load cities based on type
        cities = []
        if self.current_type == 'us' and location_name in self.us_cities_cache:
            cities = self.us_cities_cache[location_name]
        elif self.current_type == 'intl' and location_name in self.intl_cities_cache:
            cities = self.intl_cities_cache[location_name]
        
        # Populate list
        for city_data in cities:
            # Build display name
            parts = [city_data['name']]
            if city_data.get('state'):
                parts.append(city_data['state'])
            parts.append(city_data['country'])
            display = ", ".join(parts)
            
            self.main_list.Append(display)
            # Store city data as client data
            self.main_list.SetClientData(self.main_list.GetCount() - 1, city_data)
        
        if self.main_list.GetCount() > 0:
            self.main_list.SetSelection(0)
            self.add_btn.Enable(True)
        else:
            self.add_btn.Enable(False)
    
    def on_back(self, event):
        """Navigate back to previous level"""
        if self.nav_level == 'cities':
            # Go back to states or countries list
            if self.current_type == 'us':
                self.show_states_list()
            else:
                self.show_countries_list()
        elif self.nav_level in ('states', 'countries'):
            # Go back to root
            self.show_root_level()
    
    def on_select(self, event):
        """Handle select button - navigate deeper or add city"""
        sel = self.main_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        
        if self.nav_level == 'root':
            # Navigate to states or countries
            selection = self.main_list.GetString(sel)
            if selection == "U.S. States":
                self.show_states_list()
            elif selection == "International":
                self.show_countries_list()
        elif self.nav_level in ('states', 'countries'):
            # Navigate to cities for selected location
            location_name = self.main_list.GetString(sel)
            self.show_cities_list(location_name)
        elif self.nav_level == 'cities':
            # Add city is handled by the Add button
            self.on_add_city(event)
    
    def on_list_dclick(self, event):
        """Handle double-click as select"""
        self.on_select(event)
    
    def on_list_select(self, event):
        """Handle list selection change"""
        # Enable/disable Add button based on context
        if self.nav_level == 'cities':
            self.add_btn.Enable(self.main_list.GetSelection() != wx.NOT_FOUND)
        else:
            self.add_btn.Enable(False)
    
    def on_add_city(self, event):
        """Add selected city to the list"""
        if self.nav_level != 'cities':
            return
        
        sel = self.main_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        
        city_data = self.main_list.GetClientData(sel)
        display_name = self.main_list.GetString(sel)
        
        # Add to selected cities
        city_tuple = (display_name, city_data['lat'], city_data['lon'])
        if city_tuple not in self.selected_cities:
            self.selected_cities.append(city_tuple)
            # Visual feedback
            wx.MessageBox(f"Added {display_name} to your selection.\n\nTotal cities selected: {len(self.selected_cities)}", 
                         "City Added", wx.OK | wx.ICON_INFORMATION)
    
    def get_selected_cities(self):
        return self.selected_cities

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
    # WMO Weather interpretation codes (WW)
    weather_code_description = {
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
            # If a specific city file is provided, we still try to use the standard user data dir for config
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
        
        # Performance optimizations: weather cache and thread pool
        self.weather_cache = {}  # {cache_key: {'data': {...}, 'timestamp': datetime}}
        self.weather_executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT_REQUESTS)
        
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
        
        wx.CallAfter(self.set_initial_focus)

    def init_ui(self):
        self.panel = wx.Panel(self)
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.book = wx.Simplebook(self.panel)
        
        # Browse navigation state
        self.browse_stack = []  # Navigation stack for browse view
        self.browse_cities_data = {}  # Store city data for browse view
        
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
        for b in [self.btn_up, self.btn_down, self.btn_remove, self.btn_refresh, self.btn_full, self.btn_config_main]:
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
        
        # Browse View (Gopher-style navigation)
        self.browse_view = wx.Panel(self.book)
        bv_sizer = wx.BoxSizer(wx.VERTICAL)
        
        browse_head_row = wx.BoxSizer(wx.HORIZONTAL)
        self.btn_browse_back = wx.Button(self.browse_view, label="<- Back")
        self.lbl_browse_title = wx.StaticText(self.browse_view, label="Browse Locations")
        self.lbl_browse_title.SetFont(wx.Font(14, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD))
        browse_head_row.Add(self.btn_browse_back, 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        browse_head_row.Add(self.lbl_browse_title, 1, wx.ALIGN_CENTER_VERTICAL)
        bv_sizer.Add(browse_head_row, 0, wx.EXPAND | wx.ALL, 10)
        
        # Browse list
        sb_browse = wx.StaticBox(self.browse_view, label="Locations")
        browse_list_box = wx.StaticBoxSizer(sb_browse, wx.VERTICAL)
        self.browse_list = wx.ListBox(self.browse_view, style=wx.LB_SINGLE | wx.WANTS_CHARS)
        browse_list_box.Add(self.browse_list, 1, wx.EXPAND | wx.ALL, 5)
        
        # Browse action buttons
        browse_btn_row = wx.BoxSizer(wx.HORIZONTAL)
        self.btn_browse_add = wx.Button(self.browse_view, label="Add to My Cities")
        self.btn_browse_add.Enable(False)
        browse_btn_row.Add(self.btn_browse_add, 0, wx.RIGHT, 5)
        browse_list_box.Add(browse_btn_row, 0, wx.ALIGN_CENTER | wx.ALL, 5)
        bv_sizer.Add(browse_list_box, 1, wx.EXPAND | wx.ALL, 10)
        
        self.browse_view.SetSizer(bv_sizer)
        
        self.book.AddPage(self.main_view, "Main")
        self.book.AddPage(self.full_view, "Full")
        self.book.AddPage(self.browse_view, "Browse")
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
        
        # Browse view bindings
        self.Bind(wx.EVT_BUTTON, self.on_browse_back, self.btn_browse_back)
        self.Bind(wx.EVT_BUTTON, self.on_browse_add_city, self.btn_browse_add)
        self.browse_list.Bind(wx.EVT_LISTBOX_DCLICK, self.on_browse_select)
        self.browse_list.Bind(wx.EVT_KEY_DOWN, self.on_browse_key)
        self.Bind(wx.EVT_LISTBOX, self.on_browse_list_select, self.browse_list)
        
        self.update_city_list()

    def on_list_key(self, event):
        keycode = event.GetKeyCode()
        if keycode == wx.WXK_RETURN or keycode == wx.WXK_NUMPAD_ENTER:
            self.on_full_weather(event)
        elif keycode == wx.WXK_TAB:
            # Manually handle Tab navigation since WANTS_CHARS consumes it
            flags = wx.NavigationKeyEvent.IsForward
            if event.ShiftDown():
                flags = wx.NavigationKeyEvent.IsBackward
            self.city_list.Navigate(flags)
        else:
            event.Skip()

    def setup_shortcuts(self):
        # Create IDs for accelerators
        self.ID_REFRESH = wx.NewIdRef()
        self.ID_REMOVE = wx.NewIdRef()
        self.ID_MOVE_UP = wx.NewIdRef()
        self.ID_MOVE_DOWN = wx.NewIdRef()
        self.ID_ESCAPE = wx.NewIdRef()
        self.ID_FULL_WEATHER = wx.NewIdRef()
        self.ID_NEW_CITY = wx.NewIdRef()
        self.ID_CONFIGURE = wx.NewIdRef()
        
        # Bind IDs to methods
        self.Bind(wx.EVT_MENU, self.on_refresh, id=self.ID_REFRESH)
        self.Bind(wx.EVT_MENU, self.on_remove, id=self.ID_REMOVE)
        self.Bind(wx.EVT_MENU, self.on_move_up, id=self.ID_MOVE_UP)
        self.Bind(wx.EVT_MENU, self.on_move_down, id=self.ID_MOVE_DOWN)
        self.Bind(wx.EVT_MENU, self.on_escape, id=self.ID_ESCAPE)
        self.Bind(wx.EVT_MENU, self.on_full_weather, id=self.ID_FULL_WEATHER)
        self.Bind(wx.EVT_MENU, self.on_focus_new_city, id=self.ID_NEW_CITY)
        self.Bind(wx.EVT_MENU, self.on_config, id=self.ID_CONFIGURE)
        
        accel = [
            (wx.ACCEL_NORMAL, wx.WXK_F5, self.ID_REFRESH),
            (wx.ACCEL_CTRL, ord('R'), self.ID_REFRESH),
            (wx.ACCEL_NORMAL, wx.WXK_DELETE, self.ID_REMOVE),
            (wx.ACCEL_ALT, ord('U'), self.ID_MOVE_UP),
            (wx.ACCEL_ALT, ord('D'), self.ID_MOVE_DOWN),
            (wx.ACCEL_NORMAL, wx.WXK_ESCAPE, self.ID_ESCAPE),
            (wx.ACCEL_ALT, ord('F'), self.ID_FULL_WEATHER),
            (wx.ACCEL_ALT, ord('N'), self.ID_NEW_CITY),
            (wx.ACCEL_ALT, ord('C'), self.ID_CONFIGURE)
        ]
        self.SetAcceleratorTable(wx.AcceleratorTable(accel))

    def on_escape(self, event):
        """Handle Escape key for hierarchical navigation back"""
        current_page = self.book.GetSelection()
        
        if current_page == 1:
            # Full weather view - go back to main
            self.on_back(event)
        elif current_page == 2:
            # Browse view - navigate back through hierarchy
            self.on_browse_back(event)
        # If on main view (0), Escape does nothing (already at root)
    
    def on_focus_new_city(self, event):
        """Focus the new city input field (Alt+N)"""
        if self.book.GetSelection() == 0:  # Only on main view
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
        for b in [self.btn_remove, self.btn_refresh, self.btn_full]: b.Enable(has_sel)
        self.btn_up.Enable(has_sel and sel > 0)
        self.btn_down.Enable(has_sel and sel < self.city_list.GetCount() - 1)

    def load_city_data(self):
        loaded = False
        # 1. Try User Data (AppData)
        if os.path.exists(self.city_file):
            try:
                with open(self.city_file) as f:
                    data = json.load(f)
                    if data:
                        self.city_data = data
                        loaded = True
            except:
                pass
        
        # 2. Try Bundled/Local Default if User Data missing
        if not loaded:
            default_path = None
            if getattr(sys, 'frozen', False):
                # Running as compiled exe - look in temp folder
                default_path = os.path.join(sys._MEIPASS, "city.json")
            else:
                # Running from source - look in script directory
                default_path = os.path.join(os.path.dirname(__file__), "city.json")
            
            if default_path and os.path.exists(default_path):
                try:
                    with open(default_path) as f:
                        self.city_data = json.load(f)
                        loaded = True
                except: pass

        # 3. Fallback to hardcoded defaults
        if not loaded:
            self.city_data = DEFAULT_CITIES.copy()
            
        # Save to user data so it exists for next time
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
                    # Merge saved config with defaults to handle new keys
                    for section, options in saved_config.items():
                        if section in self.weather_config:
                            for key, value in options.items():
                                self.weather_config[section][key] = value
            except: pass
    
    def load_cached_cities(self):
        """Load cached city coordinates for browsing by state/country"""
        # Try to load from multiple locations
        script_dir = os.path.dirname(__file__)
        possible_paths = [
            # In webapp folder (for development)
            os.path.join(script_dir, "webapp", "us-cities-cached.json"),
            os.path.join(script_dir, "webapp", "international-cities-cached.json"),
            # In same folder as script
            os.path.join(script_dir, "us-cities-cached.json"),
            os.path.join(script_dir, "international-cities-cached.json"),
            # If frozen/bundled
            os.path.join(getattr(sys, '_MEIPASS', script_dir), "us-cities-cached.json"),
            os.path.join(getattr(sys, '_MEIPASS', script_dir), "international-cities-cached.json"),
        ]
        
        # Load US cities cache
        for path in possible_paths:
            if "us-cities" in path and os.path.exists(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        self.us_cities_cache = json.load(f)
                        print(f"Loaded US cities cache from {path}")
                        break
                except Exception as e:
                    print(f"Error loading US cities cache from {path}: {e}")
        
        # Load international cities cache
        for path in possible_paths:
            if "international-cities" in path and os.path.exists(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        self.intl_cities_cache = json.load(f)
                        print(f"Loaded international cities cache from {path}")
                        break
                except Exception as e:
                    print(f"Error loading international cities cache from {path}: {e}")

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
                self.fetch_weather_with_cache(city, lat, lon, "basic")

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
        """Navigate to browse view - Gopher-style hierarchical navigation"""
        if not self.us_cities_cache and not self.intl_cities_cache:
            wx.MessageBox(
                "City data files not found. Please ensure us-cities-cached.json and "
                "international-cities-cached.json are in the application directory.",
                "Data Not Available",
                wx.OK | wx.ICON_INFORMATION
            )
            return
        
        # Initialize browse navigation at root level
        self.browse_stack = []
        self.browse_cities_data = {}
        self.show_browse_root()
        self.book.SetSelection(2)  # Switch to browse view
        self.browse_list.SetFocus()
    
    def show_browse_root(self):
        """Show root level of browse navigation"""
        self.lbl_browse_title.SetLabel("Browse by Location Type")
        self.btn_browse_back.Enable(False)
        self.btn_browse_add.Enable(False)
        
        self.browse_list.Clear()
        self.browse_list.Append("U.S. States")
        self.browse_list.Append("International")
        self.browse_list.SetSelection(0)
    
    def show_browse_states(self):
        """Show list of U.S. states"""
        self.lbl_browse_title.SetLabel("U.S. States")
        self.btn_browse_back.Enable(True)
        self.btn_browse_add.Enable(False)
        
        self.browse_list.Clear()
        if self.us_cities_cache:
            states = sorted(self.us_cities_cache.keys())
            for state in states:
                self.browse_list.Append(state)
            if self.browse_list.GetCount() > 0:
                self.browse_list.SetSelection(0)
    
    def show_browse_countries(self):
        """Show list of international countries"""
        self.lbl_browse_title.SetLabel("International Countries")
        self.btn_browse_back.Enable(True)
        self.btn_browse_add.Enable(False)
        
        self.browse_list.Clear()
        if self.intl_cities_cache:
            countries = sorted(self.intl_cities_cache.keys())
            for country in countries:
                self.browse_list.Append(country)
            if self.browse_list.GetCount() > 0:
                self.browse_list.SetSelection(0)
    
    def show_browse_cities(self, location_name, location_type):
        """Show cities for selected state/country with weather data"""
        self.lbl_browse_title.SetLabel(f"Cities in {location_name}")
        self.btn_browse_back.Enable(True)
        self.btn_browse_add.Enable(True)
        
        self.browse_list.Clear()
        self.browse_cities_data = {}
        
        # Get cities based on type
        cities = []
        if location_type == 'us' and location_name in self.us_cities_cache:
            cities = self.us_cities_cache[location_name]
        elif location_type == 'intl' and location_name in self.intl_cities_cache:
            cities = self.intl_cities_cache[location_name]
        
        # Sort cities alphabetically by name (handles international characters properly)
        cities = sorted(cities, key=lambda x: x['name'].lower())
        
        # Add cities to list with "Loading..." status
        for idx, city_data in enumerate(cities):
            parts = [city_data['name']]
            if city_data.get('state'):
                parts.append(city_data['state'])
            parts.append(city_data['country'])
            display_name = ", ".join(parts)
            
            self.browse_list.Append(f"{display_name} - Loading...")
            self.browse_cities_data[display_name] = {
                'lat': city_data['lat'],
                'lon': city_data['lon'],
                'name': city_data['name']
            }
            
            # Load weather with thread pool (respects MAX_CONCURRENT_REQUESTS limit)
            self.fetch_weather_with_cache(display_name, city_data['lat'], city_data['lon'], "basic")
        
        if self.browse_list.GetCount() > 0:
            self.browse_list.SetSelection(0)
    
    def on_browse_select(self, event):
        """Handle double-click or Enter key in browse list"""
        sel = self.browse_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        
        selection = self.browse_list.GetString(sel)
        
        # Determine what level we're at based on navigation stack
        if len(self.browse_stack) == 0:
            # Root level - navigate to states or countries
            if selection == "U.S. States":
                self.browse_stack.append(('root', selection, sel))
                self.show_browse_states()
            elif selection == "International":
                self.browse_stack.append(('root', selection, sel))
                self.show_browse_countries()
        elif len(self.browse_stack) == 1:
            # State/Country list - navigate to cities
            location_type = 'us' if self.browse_stack[0][1] == "U.S. States" else 'intl'
            self.browse_stack.append((location_type, selection, sel))
            self.show_browse_cities(selection, location_type)
        elif len(self.browse_stack) == 2:
            # City level - show full weather
            city_name = selection.split(" - ")[0]
            if city_name in self.browse_cities_data:
                city_info = self.browse_cities_data[city_name]
                self.current_full_city = (city_name, city_info['lat'], city_info['lon'])
                self.lbl_full_title.SetLabel(f"Full Weather - {city_name}")
                self.weather_display.Clear()
                self.weather_display.Append("Loading...")
                self.book.SetSelection(1)  # Switch to full weather view
                self.weather_display.SetFocus()
                self.fetch_weather_with_cache(city_name, city_info['lat'], city_info['lon'], "full")
    
    def on_browse_key(self, event):
        """Handle keyboard navigation in browse list"""
        keycode = event.GetKeyCode()
        if keycode == wx.WXK_RETURN or keycode == wx.WXK_NUMPAD_ENTER:
            self.on_browse_select(event)
        elif keycode == wx.WXK_TAB:
            # Manually handle Tab navigation
            flags = wx.NavigationKeyEvent.IsForward
            if event.ShiftDown():
                flags = wx.NavigationKeyEvent.IsBackward
            self.browse_list.Navigate(flags)
        else:
            event.Skip()
    
    def on_browse_back(self, event):
        """Navigate back in browse hierarchy"""
        if len(self.browse_stack) == 0:
            # Already at root, go back to main view
            self.book.SetSelection(0)
            self.city_list.SetFocus()
        elif len(self.browse_stack) == 1:
            # Go back to root
            prev_selection_idx = self.browse_stack[0][2] if len(self.browse_stack[0]) > 2 else 0
            self.browse_stack.pop()
            self.show_browse_root()
            # Restore previous selection
            if prev_selection_idx < self.browse_list.GetCount():
                self.browse_list.SetSelection(prev_selection_idx)
        elif len(self.browse_stack) == 2:
            # Go back to states or countries list
            prev_selection_idx = self.browse_stack[1][2] if len(self.browse_stack[1]) > 2 else 0
            self.browse_stack.pop()
            if self.browse_stack[0][1] == "U.S. States":
                self.show_browse_states()
            else:
                self.show_browse_countries()
            # Restore previous selection (state or country)
            if prev_selection_idx < self.browse_list.GetCount():
                self.browse_list.SetSelection(prev_selection_idx)
                self.browse_list.SetFocus()
    
    def on_browse_list_select(self, event):
        """Handle browse list selection change"""
        # Enable Add button only if we're at city level
        at_city_level = len(self.browse_stack) == 2
        self.btn_browse_add.Enable(at_city_level and self.browse_list.GetSelection() != wx.NOT_FOUND)
    
    def on_browse_add_city(self, event):
        """Add selected city from browse view to main city list"""
        if len(self.browse_stack) != 2:
            return
        
        sel = self.browse_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        
        # Extract city name (remove " - temperature..." suffix)
        full_text = self.browse_list.GetString(sel)
        city_name = full_text.split(" - ")[0]
        
        if city_name in self.browse_cities_data:
            city_info = self.browse_cities_data[city_name]
            
            # Check if already in list
            if city_name in self.city_data:
                wx.MessageBox(f"{city_name} is already in your city list", 
                             "Already Added", wx.OK | wx.ICON_INFORMATION)
                return
            
            # Add to city data
            self.city_data[city_name] = [city_info['lat'], city_info['lon']]
            self.save_city_data()
            self.update_city_list()
            
            # Select the newly added city in the main list
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(city_name + " - "):
                    self.city_list.SetSelection(i)
                    self.selectedCity = self.city_list.GetString(i)
                    break
            self.update_buttons()
            
            # Provide feedback
            wx.MessageBox(f"Added {city_name} to your cities", 
                         "City Added", wx.OK | wx.ICON_INFORMATION)

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
        
        # Swap text
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
            # Clear cache for this city to force refresh
            cache_key = f"{city}_basic"
            if cache_key in self.weather_cache:
                del self.weather_cache[cache_key]
            self.fetch_weather_with_cache(city, lat, lon, "basic")

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
        self.fetch_weather_with_cache(city, lat, lon, "full")

    def on_back(self, event):
        """Navigate back from full weather view"""
        # Check if we came from browse view
        if len(self.browse_stack) == 2:
            # Return to browse cities view
            self.book.SetSelection(2)
            self.browse_list.SetFocus()
        else:
            # Return to main city list
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
        """Apply configuration changes without closing the dialog"""
        self.weather_config = new_config.copy()
        self.save_config()
        # Refresh city list to show updated units
        self.load_all_weather()
        # Refresh full weather view if active
        if hasattr(self, 'current_full_city') and self.book.GetSelection() == 1:
            self.on_full_weather(None)

    def degrees_to_cardinal(self, degrees):
        directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        index = round(degrees / 45) % 8
        return directions[index]
    
    def fetch_weather_with_cache(self, city_name, lat, lon, detail="basic", forecast_days=16):
        """Fetch weather with caching and thread pooling to prevent system overload"""
        cache_key = f"{city_name}_{detail}"
        
        # Check cache first
        if cache_key in self.weather_cache:
            cached = self.weather_cache[cache_key]
            age_seconds = (datetime.now() - cached['timestamp']).total_seconds()
            if age_seconds < WEATHER_CACHE_MINUTES * 60:
                # Use cached data - post event on main thread
                wx.CallAfter(lambda: wx.PostEvent(self, WeatherReadyEvent(data=(city_name, cached['data']))))
                return
        
        # Submit to thread pool for async fetch
        def worker():
            try:
                params = {
                    "latitude": lat,
                    "longitude": lon,
                    "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility",
                    "timezone": "auto",
                }
                
                if detail == "full":
                    params["hourly"] = "temperature_2m,apparent_temperature,relative_humidity_2m,dewpoint_2m,precipitation,precipitation_probability,rain,showers,snowfall,snow_depth,weathercode,pressure_msl,surface_pressure,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,visibility,evapotranspiration,et0_fao_evapotranspiration,vapor_pressure_deficit,windspeed_10m,winddirection_10m,windgusts_10m,uv_index,uv_index_clear_sky,is_day,cape,freezing_level_height,soil_temperature_0cm"
                    params["daily"] = "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,winddirection_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration"
                    params["forecast_days"] = forecast_days
                else:
                    params["hourly"] = "cloudcover"
                    params["daily"] = "temperature_2m_max,temperature_2m_min"
                    params["forecast_days"] = 1
                
                response = requests.get(OPEN_METEO_API_URL, params=params, timeout=10)
                response.raise_for_status()
                data = response.json()
                
                # Cache the result
                self.weather_cache[cache_key] = {
                    'data': data,
                    'timestamp': datetime.now()
                }
                
                wx.PostEvent(self, WeatherReadyEvent(data=(city_name, data)))
            except Exception as e:
                wx.PostEvent(self, WeatherErrorEvent(data=(city_name, str(e))))
        
        self.weather_executor.submit(worker)
    
    def format_temperature(self, temp_c):
        """Convert temperature to configured unit and format"""
        if self.weather_config['units']['temperature'] == 'C':
            return f"{temp_c:.1f}°C"
        else:
            temp_f = (temp_c * 9/5) + 32
            return f"{temp_f:.1f}°F"
    
    def format_temperature_short(self, temp_c):
        """Convert temperature to configured unit (short format for lists)"""
        if self.weather_config['units']['temperature'] == 'C':
            return f"{temp_c:.0f}°C"
        else:
            temp_f = (temp_c * 9/5) + 32
            return f"{temp_f:.0f}°F"
    
    def format_wind_speed(self, wind_kmh):
        """Convert wind speed to configured unit and format"""
        if self.weather_config['units']['wind_speed'] == 'km/h':
            return f"{wind_kmh:.1f} km/h"
        else:
            wind_mph = wind_kmh * KMH_TO_MPH
            return f"{wind_mph:.1f} mph"
    
    def format_precipitation(self, precip_mm):
        """Convert precipitation to configured unit and format"""
        if self.weather_config['units']['precipitation'] == 'mm':
            return f"{precip_mm:.1f}mm"
        else:
            precip_in = precip_mm * MM_TO_INCHES
            return f"{precip_in:.2f}\""

    def on_weather_ready(self, event):
        city, data = event.data
        
        # Update list
        curr = data.get("current", data.get("current_weather", {}))
        if curr:
            # Handle key differences between 'current' and legacy 'current_weather'
            temp_c = curr.get("temperature_2m", curr.get("temperature", 0))
            temp_f = (temp_c * 9/5) + 32
            
            cloud_text = ""
            
            # Try to get cloud cover directly (new API)
            if "cloud_cover" in curr:
                cc = curr["cloud_cover"]
                if cc <= 12: desc = "clear"
                elif cc <= 37: desc = "mostly clear"
                elif cc <= 62: desc = "partly cloudy"
                elif cc <= 87: desc = "mostly cloudy"
                else: desc = "cloudy"
                cloud_text = f", {desc}"
            else:
                # Fallback to hourly matching
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
            
            # Get daily high and low temperatures
            daily_temps = ""
            daily = data.get("daily", {})
            if daily and daily.get("temperature_2m_max") and daily.get("temperature_2m_min"):
                temp_max_c = daily["temperature_2m_max"][0]
                temp_min_c = daily["temperature_2m_min"][0]
                temp_max = self.format_temperature_short(temp_max_c)
                temp_min = self.format_temperature_short(temp_min_c)
                daily_temps = f" (High: {temp_max}, Low: {temp_min})"
            
            # Check for current precipitation
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
            
            # Update main city list
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(city + " - "):
                    self.city_list.SetString(i, new_text)
                    break
            
            # Update browse list if active
            for i in range(self.browse_list.GetCount()):
                if self.browse_list.GetString(i).startswith(city + " - "):
                    self.browse_list.SetString(i, new_text)
                    break

        # Update full view if active
        if hasattr(self, 'current_full_city') and self.current_full_city[0] == city and self.book.GetSelection() == 1:
            self.weather_display.Clear()
            lines = self.format_full_weather(city, data)
            for line in lines:
                # Filter out empty lines and separator lines for accessibility
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
        
        # Handle both new 'current' and legacy 'current_weather'
        curr = data.get("current", data.get("current_weather", {}))
        hourly = data.get("hourly", {})
        daily = data.get("daily", {})
        
        cfg_curr = self.weather_config['current']
        if curr:
            lines.append("CURRENT")
            
            # Helper to get value from either new or legacy keys
            def get_val(keys, default=0):
                if isinstance(keys, str): keys = [keys]
                for k in keys:
                    if k in curr: return curr[k]
                return default

            # Temperature
            if cfg_curr.get('temperature', True):
                temp_c = get_val(['temperature_2m', 'temperature'])
                lines.append(f"Temp: {self.format_temperature(temp_c)}")
            
            # Feels Like
            if cfg_curr.get('feels_like', False):
                app_temp_c = get_val(['apparent_temperature'])
                lines.append(f"Feels Like: {self.format_temperature(app_temp_c)}")

            # Humidity
            if cfg_curr.get('humidity', False):
                hum = get_val(['relative_humidity_2m'])
                lines.append(f"Humidity: {hum}%")

            # Pressure
            if cfg_curr.get('pressure', False):
                pres = get_val(['pressure_msl', 'surface_pressure'])
                pres_in = pres * HPA_TO_INHG
                lines.append(f"Pressure: {pres_in:.2f} inHg")

            # Visibility
            if cfg_curr.get('visibility', False):
                vis_m = get_val(['visibility'])
                vis_miles = vis_m / 1609.34
                lines.append(f"Visibility: {vis_miles:.1f} miles")

            # UV Index (fetch from hourly if not in current)
            if cfg_curr.get('uv_index', False):
                uv = get_val(['uv_index'])
                if uv == 0 and hourly and 'uv_index' in hourly and 'time' in hourly:
                    # Try to find current hour in hourly data
                    curr_time = curr.get('time')
                    if curr_time in hourly['time']:
                        idx = hourly['time'].index(curr_time)
                        uv = hourly['uv_index'][idx]
                lines.append(f"UV Index: {uv}")

            # Precipitation
            if cfg_curr.get('precipitation', False):
                precip = get_val(['precipitation'])
                if precip > 0:
                    lines.append(f"Precipitation: {self.format_precipitation(precip)}")

            # Cloud Cover
            if cfg_curr.get('cloud_cover', False):
                cc = get_val(['cloud_cover', 'cloudcover'])
                if cc is not None:
                    if cc <= 12: desc = "Clear"
                    elif cc <= 37: desc = "Mostly Clear"
                    elif cc <= 62: desc = "Partly Cloudy"
                    elif cc <= 87: desc = "Mostly Cloudy"
                    else: desc = "Cloudy"
                    lines.append(f"Cloud Cover: {cc}% ({desc})")

            # Snowfall
            if cfg_curr.get('snowfall', False):
                snow = get_val(['snowfall'])
                if snow >= 0.01:
                    lines.append(f"Snowfall: {self.format_precipitation(snow)}")
                elif snow == 0:
                    lines.append(f"Snowfall: None")

            # Snow Depth
            if cfg_curr.get('snow_depth', False):
                depth = get_val(['snow_depth'])
                if depth >= 0.01:
                    depth_converted = depth * 1000  # Convert meters to mm for consistency
                    lines.append(f"Snow Depth: {self.format_precipitation(depth_converted)}")
                elif depth == 0:
                    lines.append(f"Snow Depth: None")

            # Rain
            if cfg_curr.get('rain', False):
                rain = get_val(['rain'])
                if rain >= 0.01:
                    lines.append(f"Rain: {self.format_precipitation(rain)}")
                elif rain == 0:
                    lines.append(f"Rain: None")

            # Showers
            if cfg_curr.get('showers', False):
                showers = get_val(['showers'])
                if showers >= 0.01:
                    lines.append(f"Showers: {self.format_precipitation(showers)}")
                elif showers == 0:
                    lines.append(f"Showers: None")

            # Wind
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
            snow_depth = hourly.get('snow_depth', [])
            rain = hourly.get('rain', [])
            showers = hourly.get('showers', [])
            
            # Find start
            start = 0
            curr_time = curr.get('time') if curr else None
            
            if curr_time and times:
                try:
                    # Calculate index based on time difference from start of list
                    # This is more robust than string matching
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
    
    # Determine standard path for user data
    app_name = "FastWeather"
    app.SetAppName(app_name)
    sp = wx.StandardPaths.Get()
    user_data_dir = sp.GetUserDataDir()
    
    # Ensure directory exists
    if not os.path.exists(user_data_dir):
        os.makedirs(user_data_dir)
        
    city_file = args.config if args.config else os.path.join(user_data_dir, "city.json")
    
    if args.reset:
        # If reset is used with a custom config, we reset that file
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
