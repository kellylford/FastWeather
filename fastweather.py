#!/usr/bin/env python3
"""
Accessible GUI Weather Application using wxPython
Fully accessible with screen readers, keyboard navigation, and proper focus management
Uses Open-Meteo API (no API key required)
"""

import sys
import json
import requests
import logging
import argparse
from datetime import datetime
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
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

# Custom Events
WeatherReadyEvent, EVT_WEATHER_READY = wx.lib.newevent.NewEvent()
WeatherErrorEvent, EVT_WEATHER_ERROR = wx.lib.newevent.NewEvent()
GeoReadyEvent, EVT_GEO_READY = wx.lib.newevent.NewEvent()
GeoErrorEvent, EVT_GEO_ERROR = wx.lib.newevent.NewEvent()

class WeatherFetchThread(threading.Thread):
    def __init__(self, notify_window, city_name, lat, lon, detail="basic", forecast_days=7):
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
                "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m",
                "timezone": "auto",
            }
            
            if self.detail == "full":
                params["hourly"] = "temperature_2m,apparent_temperature,relative_humidity_2m,dewpoint_2m,precipitation,precipitation_probability,rain,showers,snowfall,snow_depth,weathercode,pressure_msl,surface_pressure,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,visibility,evapotranspiration,et0_fao_evapotranspiration,vapor_pressure_deficit,windspeed_10m,winddirection_10m,windgusts_10m,uv_index,uv_index_clear_sky,is_day,cape,freezing_level_height,soil_temperature_0cm"
                params["daily"] = "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,winddirection_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration"
                params["forecast_days"] = self.forecast_days
            else:
                params["hourly"] = "cloudcover"
            
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
            headers = {"User-Agent": "FastWeather GUI/1.0 (accessible weather app)"}
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
        
    def on_ok(self, event):
        sel = self.city_list.GetSelection()
        if sel != wx.NOT_FOUND:
            self.selected_match = self.matches[sel]
            self.EndModal(wx.ID_OK)
        else:
            event.Skip()

class WeatherConfigDialog(wx.Dialog):
    def __init__(self, parent, current_config):
        super().__init__(parent, title="Configure Weather Display", size=(600, 500))
        self.config = current_config.copy()
        
        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        vbox.Add(wx.StaticText(panel, label="Select weather details to display:"), 0, wx.ALL, 10)
        
        nb = wx.Notebook(panel)
        self.checkboxes = {'current': {}, 'hourly': {}, 'daily': {}}
        
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
            ('precipitation', 'Precipitation')
        ])
        
        add_tab("Hourly", 'hourly', [
            ('temperature', 'Temperature'), ('feels_like', 'Feels Like'),
            ('humidity', 'Humidity'), ('precipitation', 'Precipitation'),
            ('wind_speed', 'Wind Speed'), ('wind_direction', 'Wind Direction')
        ])
        
        add_tab("Daily", 'daily', [
            ('temperature_max', 'High Temp'), ('temperature_min', 'Low Temp'),
            ('sunrise', 'Sunrise'), ('sunset', 'Sunset'),
            ('precipitation_sum', 'Precip Total'), ('precipitation_hours', 'Precip Hours'),
            ('wind_speed_max', 'Max Wind'), ('wind_direction_dominant', 'Wind Direction')
        ])
        
        vbox.Add(nb, 1, wx.EXPAND | wx.ALL, 10)
        
        btns = wx.StdDialogButtonSizer()
        btns.AddButton(wx.Button(panel, wx.ID_OK))
        btns.AddButton(wx.Button(panel, wx.ID_CANCEL))
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        
        panel.SetSizer(vbox)
        self.Bind(wx.EVT_BUTTON, self.on_ok, id=wx.ID_OK)

    def on_ok(self, event):
        for section in self.checkboxes:
            for key, cb in self.checkboxes[section].items():
                self.config[section][key] = cb.GetValue()
        self.EndModal(wx.ID_OK)

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
        super().__init__(None, title="FastWeather - Accessible Weather App", size=(1000, 700))
        self.city_file = city_file or os.path.join(os.path.dirname(__file__), "city.json")
        self.city_data = {}
        self.weather_config = {
            'current': {'temperature': True, 'feels_like': True, 'humidity': True, 'wind_speed': True, 'wind_direction': True, 'pressure': False, 'visibility': False, 'uv_index': False, 'precipitation': True},
            'hourly': {'temperature': True, 'feels_like': False, 'humidity': False, 'precipitation': True, 'wind_speed': False, 'wind_direction': False},
            'daily': {'temperature_max': True, 'temperature_min': True, 'sunrise': True, 'sunset': True, 'precipitation_sum': True, 'precipitation_hours': False, 'wind_speed_max': False, 'wind_direction_dominant': False}
        }
        
        self.load_city_data()
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
        for b in [self.btn_up, self.btn_down, self.btn_remove, self.btn_refresh, self.btn_full]:
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
        self.Bind(wx.EVT_LISTBOX, self.on_select, self.city_list)
        self.city_list.Bind(wx.EVT_LISTBOX_DCLICK, self.on_full_weather)
        self.Bind(wx.EVT_BUTTON, self.on_move_up, self.btn_up)
        self.Bind(wx.EVT_BUTTON, self.on_move_down, self.btn_down)
        self.Bind(wx.EVT_BUTTON, self.on_remove, self.btn_remove)
        self.Bind(wx.EVT_BUTTON, self.on_refresh, self.btn_refresh)
        self.Bind(wx.EVT_BUTTON, self.on_full_weather, self.btn_full)
        self.Bind(wx.EVT_BUTTON, self.on_back, self.btn_back)
        self.Bind(wx.EVT_BUTTON, self.on_config, self.btn_config)
        self.city_list.Bind(wx.EVT_KEY_DOWN, self.on_list_key)
        
        self.update_city_list()

    def on_list_key(self, event):
        keycode = event.GetKeyCode()
        if keycode == wx.WXK_RETURN or keycode == wx.WXK_NUMPAD_ENTER:
            self.on_full_weather(event)
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
        
        # Bind IDs to methods
        self.Bind(wx.EVT_MENU, self.on_refresh, id=self.ID_REFRESH)
        self.Bind(wx.EVT_MENU, self.on_remove, id=self.ID_REMOVE)
        self.Bind(wx.EVT_MENU, self.on_move_up, id=self.ID_MOVE_UP)
        self.Bind(wx.EVT_MENU, self.on_move_down, id=self.ID_MOVE_DOWN)
        self.Bind(wx.EVT_MENU, self.on_escape, id=self.ID_ESCAPE)
        self.Bind(wx.EVT_MENU, self.on_full_weather, id=self.ID_FULL_WEATHER)
        
        accel = [
            (wx.ACCEL_NORMAL, wx.WXK_F5, self.ID_REFRESH),
            (wx.ACCEL_CTRL, ord('R'), self.ID_REFRESH),
            (wx.ACCEL_NORMAL, wx.WXK_DELETE, self.ID_REMOVE),
            (wx.ACCEL_ALT, ord('U'), self.ID_MOVE_UP),
            (wx.ACCEL_ALT, ord('D'), self.ID_MOVE_DOWN),
            (wx.ACCEL_NORMAL, wx.WXK_ESCAPE, self.ID_ESCAPE),
            (wx.ACCEL_ALT, ord('F'), self.ID_FULL_WEATHER)
        ]
        self.SetAcceleratorTable(wx.AcceleratorTable(accel))

    def on_escape(self, event):
        if self.book.GetSelection() == 1: self.on_back(event)

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
        try:
            if os.path.exists(self.city_file):
                with open(self.city_file) as f: self.city_data = json.load(f)
        except: self.city_data = {}

    def save_city_data(self):
        try:
            with open(self.city_file, 'w') as f: json.dump(self.city_data, f, indent=4)
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
            if hasattr(self, 'current_full_city'):
                self.on_full_weather(None)
        dlg.Destroy()

    def degrees_to_cardinal(self, degrees):
        directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        index = round(degrees / 45) % 8
        return directions[index]

    def on_weather_ready(self, event):
        city, data = event.data
        
        # Update list
        curr = data.get("current_weather", {})
        if curr:
            temp_c = curr.get("temperature", 0)
            temp_f = (temp_c * 9/5) + 32
            
            hourly = data.get("hourly", {})
            cloud_text = ""
            
            if hourly and 'time' in hourly and 'cloudcover' in hourly:
                times = hourly['time']
                cloudcover = hourly['cloudcover']
                curr_time_str = curr.get('time')
                
                idx = -1
                # Try exact match first
                if curr_time_str in times:
                    idx = times.index(curr_time_str)
                else:
                    # Try datetime match
                    try:
                        curr_dt = datetime.strptime(curr_time_str, "%Y-%m-%dT%H:%M")
                        # Find closest hour
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
            
            new_text = f"{city} - {temp_f:.0f}°F{cloud_text}"
            
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(city + " - "):
                    self.city_list.SetString(i, new_text)
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
        
        curr = data.get("current_weather", {})
        cfg_curr = self.weather_config['current']
        if curr:
            lines.append("CURRENT")
            temp_c = curr.get("temperature", 0)
            temp_f = (temp_c * 9/5) + 32
            
            if cfg_curr.get('temperature', True):
                lines.append(f"Temp: {temp_f:.1f}°F ({temp_c:.1f}°C)")
            
            if cfg_curr.get('wind_speed', True):
                wind_mph = curr.get('windspeed', 0) * KMH_TO_MPH
                wind_dir = curr.get('winddirection', 0)
                wind_card = self.degrees_to_cardinal(wind_dir)
                
                if cfg_curr.get('wind_direction', True):
                    lines.append(f"Wind: {wind_mph:.1f} mph {wind_card} ({wind_dir}°)")
                else:
                    lines.append(f"Wind: {wind_mph:.1f} mph")
            elif cfg_curr.get('wind_direction', True):
                wind_dir = curr.get('winddirection', 0)
                wind_card = self.degrees_to_cardinal(wind_dir)
                lines.append(f"Wind Dir: {wind_card} ({wind_dir}°)")
                
            lines.append("")
            
        hourly = data.get("hourly", {})
        cfg_hourly = self.weather_config['hourly']
        # Check if any hourly option is enabled
        if hourly and any(cfg_hourly.values()):
            lines.append("HOURLY")
            times = hourly.get('time', [])
            temps = hourly.get('temperature_2m', [])
            precip = hourly.get('precipitation', [])
            humidity = hourly.get('relative_humidity_2m', [])
            
            # Find start
            start = 0
            if curr and curr.get('time') in times:
                start = times.index(curr.get('time'))
                
            for i in range(start, min(start+12, len(times))):
                parts = []
                t = datetime.strptime(times[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                parts.append(f"{t}:")
                
                if cfg_hourly.get('temperature', True):
                    tf = (temps[i] * 9/5) + 32
                    parts.append(f"{tf:.0f}°F")
                
                if cfg_hourly.get('precipitation', True):
                    p = precip[i] * MM_TO_INCHES
                    if p > 0: parts.append(f"{p:.2f}\" precip")
                
                if cfg_hourly.get('humidity', True) and humidity:
                    parts.append(f"{humidity[i]}% hum")
                    
                lines.append(" ".join(parts))
            lines.append("")
            
        daily = data.get("daily", {})
        cfg_daily = self.weather_config['daily']
        if daily and any(cfg_daily.values()):
            lines.append("DAILY")
            times = daily.get('time', [])
            maxs = daily.get('temperature_2m_max', [])
            mins = daily.get('temperature_2m_min', [])
            precip_sum = daily.get('precipitation_sum', [])
            sunrise = daily.get('sunrise', [])
            sunset = daily.get('sunset', [])
            
            for i in range(min(len(times), 7)):
                d = datetime.strptime(times[i], "%Y-%m-%d").strftime("%a %b %d")
                parts = [f"{d}:"]
                
                if cfg_daily.get('temperature_max', True):
                    hi = (maxs[i] * 9/5) + 32
                    parts.append(f"High {hi:.0f}°F")
                
                if cfg_daily.get('temperature_min', True):
                    lo = (mins[i] * 9/5) + 32
                    parts.append(f"Low {lo:.0f}°F")
                
                if cfg_daily.get('precipitation_sum', True) and precip_sum:
                    p = precip_sum[i] * MM_TO_INCHES
                    if p > 0: parts.append(f"{p:.2f}\" precip")
                
                if cfg_daily.get('sunrise', True) and sunrise:
                    sr = datetime.strptime(sunrise[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                    parts.append(f"Sunrise {sr}")
                
                if cfg_daily.get('sunset', True) and sunset:
                    ss = datetime.strptime(sunset[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                    parts.append(f"Sunset {ss}")
                    
                lines.append(" ".join(parts))
                
        lines.append("")
        lines.append("Data by Open-Meteo.com (CC BY 4.0)")
        return lines

if __name__ == "__main__":
    app = wx.App()
    AccessibleWeatherApp(None).Show()
    app.MainLoop()
