"""MainFrame: the application window and controller.

Ported from the original AccessibleWeatherApp monolith onto the layered
package (CityStore, AppSettings, Formatter, services via FetchManager,
AccessibleLinesPanel, dialogs). Behavior and layout are preserved.
"""

import json
import os

import wx

from .city_data import load_cached_cities
from .models.city import CityStore
from .models.settings import AppSettings
from .models.weather import describe_cloud_cover
from .services import geocoding_service, weather_service
from .services.fetch_manager import FetchManager
from .ui.accessible_list import AccessibleLinesPanel
from .ui.dialogs.city_select import CitySelectionDialog
from .ui.dialogs.config_dialog import WeatherConfigDialog
from .ui.dialogs.location_browser import LocationBrowserDialog
from .ui.events import EVT_FETCH_RESULT
from .ui.formatters import Formatter
from .ui.full_weather_view import build_full_weather_lines
from .paths import user_data_dir


class MainFrame(wx.Frame):
    def __init__(self, city_file=None):
        super().__init__(None, title="FastWeather", size=(1000, 700))

        data_dir = user_data_dir()
        if city_file is None:
            self.city_file = os.path.join(data_dir, "city.json")
        else:
            self.city_file = city_file
        self.config_file = os.path.join(data_dir, "config.json")

        # Model / settings / helpers
        self.cities = CityStore(self.city_file)
        self.settings = AppSettings()
        self.fmt = Formatter(self.settings)

        # Cached city coordinates for browsing
        self.us_cities_cache, self.intl_cities_cache = load_cached_cities()

        self.cities.load()
        self.load_config()

        # Background fetch manager
        self.fetch = FetchManager(self)

        self.init_ui()
        self.setup_shortcuts()

        self.Bind(EVT_FETCH_RESULT, self.on_fetch_result)
        self.Bind(wx.EVT_CLOSE, self.on_close)

        wx.CallAfter(self.set_initial_focus)

    # -- configuration persistence -------------------------------------------
    def load_config(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file) as f:
                    self.settings.merge_saved(json.load(f))
            except Exception:
                pass

    def save_config(self):
        try:
            with open(self.config_file, "w") as f:
                json.dump(self.settings.to_dict(), f, indent=4)
        except Exception:
            pass

    # -- UI construction ------------------------------------------------------
    def init_ui(self):
        self.panel = wx.Panel(self)
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.book = wx.Simplebook(self.panel)

        # Main view
        self.main_view = wx.Panel(self.book)
        mv_sizer = wx.BoxSizer(wx.VERTICAL)

        sb_input = wx.StaticBox(self.main_view, label="Add New City")
        inp_box = wx.StaticBoxSizer(sb_input, wx.VERTICAL)
        inp_row = wx.BoxSizer(wx.HORIZONTAL)
        self.city_input = wx.TextCtrl(self.main_view, style=wx.TE_PROCESS_ENTER)
        self.city_input.SetHint("City name or zip code")
        self.add_btn = wx.Button(self.main_view, label="Add City")
        inp_row.Add(wx.StaticText(self.main_view, label="Enter city:"), 0,
                    wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 5)
        inp_row.Add(self.city_input, 1, wx.EXPAND | wx.RIGHT, 5)
        inp_row.Add(self.add_btn, 0)
        inp_box.Add(inp_row, 0, wx.EXPAND | wx.ALL, 5)

        browse_row = wx.BoxSizer(wx.HORIZONTAL)
        self.browse_btn = wx.Button(self.main_view, label="Browse Cities by State/Country")
        browse_row.Add(self.browse_btn, 1, wx.EXPAND)
        inp_box.Add(browse_row, 0, wx.EXPAND | wx.ALL, 5)

        mv_sizer.Add(inp_box, 0, wx.EXPAND | wx.ALL, 10)

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
        for b in [self.btn_up, self.btn_down, self.btn_remove, self.btn_refresh,
                  self.btn_full, self.btn_config_main]:
            btn_row.Add(b, 0, wx.RIGHT, 5)
        list_box.Add(btn_row, 0, wx.ALIGN_CENTER | wx.ALL, 5)
        mv_sizer.Add(list_box, 1, wx.EXPAND | wx.ALL, 10)

        self.main_view.SetSizer(mv_sizer)

        # Full view
        self.full_view = wx.Panel(self.book)
        fv_sizer = wx.BoxSizer(wx.VERTICAL)

        head_row = wx.BoxSizer(wx.HORIZONTAL)
        self.btn_back = wx.Button(self.full_view, label="<- Back")
        self.lbl_full_title = wx.StaticText(self.full_view, label="Full Weather")
        self.lbl_full_title.SetFont(
            wx.Font(14, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD)
        )
        self.btn_config = wx.Button(self.full_view, label="Configure")
        head_row.Add(self.btn_back, 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 10)
        head_row.Add(self.lbl_full_title, 1, wx.ALIGN_CENTER_VERTICAL)
        head_row.Add(self.btn_config, 0, wx.ALIGN_CENTER_VERTICAL)
        fv_sizer.Add(head_row, 0, wx.EXPAND | wx.ALL, 10)

        self.full_display = AccessibleLinesPanel(self.full_view)
        fv_sizer.Add(self.full_display, 1, wx.EXPAND | wx.ALL, 10)
        self.full_view.SetSizer(fv_sizer)

        self.book.AddPage(self.main_view, "Main")
        self.book.AddPage(self.full_view, "Full")
        self.sizer.Add(self.book, 1, wx.EXPAND)
        self.panel.SetSizer(self.sizer)

        self.statusbar = self.CreateStatusBar(2)
        self.statusbar.SetStatusText("Ready", 0)
        self.statusbar.SetStatusText(
            "Weather: Open-Meteo.com | Geocoding: OpenStreetMap", 1
        )

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
            (wx.ACCEL_CTRL, ord("R"), self.ID_REFRESH),
            (wx.ACCEL_NORMAL, wx.WXK_DELETE, self.ID_REMOVE),
            (wx.ACCEL_ALT, ord("U"), self.ID_MOVE_UP),
            (wx.ACCEL_ALT, ord("D"), self.ID_MOVE_DOWN),
            (wx.ACCEL_NORMAL, wx.WXK_ESCAPE, self.ID_ESCAPE),
            (wx.ACCEL_ALT, ord("F"), self.ID_FULL_WEATHER),
            (wx.ACCEL_ALT, ord("N"), self.ID_NEW_CITY),
            (wx.ACCEL_ALT, ord("C"), self.ID_CONFIGURE),
        ]
        self.SetAcceleratorTable(wx.AcceleratorTable(accel))

    def on_escape(self, event):
        if self.book.GetSelection() == 1:
            self.on_back(event)

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
        for b in [self.btn_remove, self.btn_refresh, self.btn_full]:
            b.Enable(has_sel)
        self.btn_up.Enable(has_sel and sel > 0)
        self.btn_down.Enable(has_sel and sel < self.city_list.GetCount() - 1)

    # -- city list ------------------------------------------------------------
    def update_city_list(self, reload=True):
        sel_str = (
            self.city_list.GetStringSelection().split(" - ")[0]
            if self.city_list.GetSelection() != wx.NOT_FOUND else None
        )
        self.city_list.Clear()
        for city in self.cities.names():
            self.city_list.Append(f"{city} - Loading...")
        if reload:
            self.load_all_weather()

        if sel_str:
            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(sel_str):
                    self.city_list.SetSelection(i)
                    break
        elif self.city_list.GetCount() > 0:
            self.city_list.SetSelection(0)
        self.update_buttons()

    def load_all_weather(self):
        for city in self.cities.names():
            lat, lon = self.cities.coords(city)
            self._fetch_weather(city, lat, lon, "basic")

    def _fetch_weather(self, city, lat, lon, detail):
        self.fetch.submit(
            "weather",
            lambda: weather_service.fetch_weather(lat, lon, detail),
            request_id=city,
        )

    # -- add / browse ---------------------------------------------------------
    def on_add_city(self, event):
        val = self.city_input.GetValue().strip()
        if val:
            self.statusbar.SetStatusText("Searching...", 0)
            self.add_btn.Disable()
            self.fetch.submit(
                "geo", lambda: geocoding_service.geocode(val), request_id=val
            )

    def on_geo_ready(self, orig, matches):
        self.add_btn.Enable()
        self.statusbar.SetStatusText("Ready", 0)
        if not matches:
            wx.MessageBox("City not found", "Error", wx.OK | wx.ICON_WARNING)
            return
        if len(matches) == 1:
            self.add_city_match(matches[0])
        else:
            dlg = CitySelectionDialog(self, matches, orig)
            if dlg.ShowModal() == wx.ID_OK:
                self.add_city_match(dlg.selected_match)
            dlg.Destroy()

    def on_geo_error(self, err):
        self.add_btn.Enable()
        wx.MessageBox(f"Error: {err}", "Error", wx.OK | wx.ICON_ERROR)

    def add_city_match(self, match):
        name = match["display"]
        if name in self.cities:
            return
        self.cities.add(name, match["lat"], match["lon"])
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
                "Data Not Available", wx.OK | wx.ICON_INFORMATION,
            )
            return

        dlg = LocationBrowserDialog(self, self.us_cities_cache, self.intl_cities_cache)
        if dlg.ShowModal() == wx.ID_OK:
            cities_to_add = dlg.get_selected_cities()
            added_count = 0
            skipped_count = 0
            for city_name, lat, lon in cities_to_add:
                if self.cities.add(city_name, lat, lon):
                    added_count += 1
                else:
                    skipped_count += 1

            if added_count > 0:
                self.update_city_list()
                msg = f"Added {added_count} cit{'y' if added_count == 1 else 'ies'}"
                if skipped_count > 0:
                    msg += f" ({skipped_count} already in list)"
                wx.MessageBox(msg, "Cities Added", wx.OK | wx.ICON_INFORMATION)
            elif skipped_count > 0:
                wx.MessageBox(
                    f"All {skipped_count} selected "
                    f"cit{'y was' if skipped_count == 1 else 'ies were'} already in your list",
                    "No New Cities", wx.OK | wx.ICON_INFORMATION,
                )
        dlg.Destroy()

    # -- list actions ---------------------------------------------------------
    def on_select(self, event):
        self.update_buttons()

    def on_remove(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        city = self.city_list.GetString(sel).split(" - ")[0]
        if wx.MessageBox(f"Remove {city}?", "Confirm", wx.YES_NO) == wx.YES:
            self.cities.remove(city)
            self.update_city_list(False)

    def on_move_up(self, event):
        self.move_city(-1)

    def on_move_down(self, event):
        self.move_city(1)

    def move_city(self, direction):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        new_sel = sel + direction
        if not (0 <= new_sel < self.city_list.GetCount()):
            return

        self.cities.swap(sel, new_sel)
        t1, t2 = self.city_list.GetString(sel), self.city_list.GetString(new_sel)
        self.city_list.SetString(sel, t2)
        self.city_list.SetString(new_sel, t1)
        self.city_list.SetSelection(new_sel)
        self.update_buttons()

    def on_refresh(self, event):
        sel = self.city_list.GetSelection()
        if sel != wx.NOT_FOUND:
            city = self.city_list.GetString(sel).split(" - ")[0]
            lat, lon = self.cities.coords(city)
            self._fetch_weather(city, lat, lon, "basic")

    def on_full_weather(self, event):
        sel = self.city_list.GetSelection()
        if sel == wx.NOT_FOUND:
            return
        city = self.city_list.GetString(sel).split(" - ")[0]
        lat, lon = self.cities.coords(city)
        self.current_full_city = (city, lat, lon)
        self.lbl_full_title.SetLabel(f"Full Weather - {city}")
        self.full_display.set_message("Loading...")
        self.book.SetSelection(1)
        self.full_display.set_focus()
        self._fetch_weather(city, lat, lon, "full")

    def on_back(self, event):
        self.book.SetSelection(0)
        self.city_list.SetFocus()

    def on_config(self, event):
        dlg = WeatherConfigDialog(self, self.settings.to_dict())
        if dlg.ShowModal() == wx.ID_OK:
            self.settings.replace(dlg.get_configuration())
            self.save_config()
            if hasattr(self, "current_full_city"):
                self.on_full_weather(None)
        dlg.Destroy()

    def apply_config_changes(self, new_config):
        self.settings.replace(new_config)
        self.save_config()
        self.load_all_weather()
        if hasattr(self, "current_full_city") and self.book.GetSelection() == 1:
            self.on_full_weather(None)

    # -- async result dispatch ------------------------------------------------
    def on_fetch_result(self, event):
        if event.kind == "weather":
            if event.error:
                self.on_weather_error(event.request_id, event.error)
            else:
                self.on_weather_ready(event.request_id, event.payload)
        elif event.kind == "geo":
            if event.error:
                self.on_geo_error(event.error)
            else:
                self.on_geo_ready(event.request_id, event.payload)

    def on_weather_ready(self, city, data):
        curr = data.get("current", data.get("current_weather", {}))
        if curr:
            temp_c = curr.get("temperature_2m", curr.get("temperature", 0))

            cloud_text = ""
            if "cloud_cover" in curr:
                cloud_text = f", {describe_cloud_cover(curr['cloud_cover'])}"
            else:
                hourly = data.get("hourly", {})
                if hourly and "time" in hourly and "cloudcover" in hourly:
                    times = hourly["time"]
                    cloudcover = hourly["cloudcover"]
                    curr_time_str = curr.get("time")
                    idx = -1
                    if curr_time_str in times:
                        idx = times.index(curr_time_str)
                    else:
                        try:
                            from datetime import datetime
                            curr_dt = datetime.strptime(curr_time_str, "%Y-%m-%dT%H:%M")
                            for i, t_str in enumerate(times):
                                try:
                                    t_dt = datetime.strptime(t_str, "%Y-%m-%dT%H:%M")
                                    if t_dt.replace(minute=0) == curr_dt.replace(minute=0):
                                        idx = i
                                        break
                                except Exception:
                                    continue
                        except Exception:
                            pass
                    if idx != -1 and idx < len(cloudcover):
                        cloud_text = f", {describe_cloud_cover(cloudcover[idx])}"

            daily_temps = ""
            daily = data.get("daily", {})
            if daily and daily.get("temperature_2m_max") and daily.get("temperature_2m_min"):
                temp_max = self.fmt.temperature_short(daily["temperature_2m_max"][0])
                temp_min = self.fmt.temperature_short(daily["temperature_2m_min"][0])
                daily_temps = f" (High: {temp_max}, Low: {temp_min})"

            precip_text = ""
            snowfall = curr.get("snowfall", 0)
            rain = curr.get("rain", 0)
            showers = curr.get("showers", 0)
            if snowfall >= 0.01:
                precip_text = " [Snow]"
            elif rain >= 0.01 or showers >= 0.01:
                precip_text = " [Rain]"

            temp_display = self.fmt.temperature_short(temp_c)
            new_text = f"{city} - {temp_display}{cloud_text}{precip_text}{daily_temps}"

            for i in range(self.city_list.GetCount()):
                if self.city_list.GetString(i).startswith(city + " - "):
                    self.city_list.SetString(i, new_text)
                    break

        if (hasattr(self, "current_full_city")
                and self.current_full_city[0] == city
                and self.book.GetSelection() == 1):
            lines = build_full_weather_lines(city, data, self.settings, self.fmt)
            self.full_display.set_lines(lines)

    def on_weather_error(self, city, err):
        if (self.book.GetSelection() == 1
                and self.lbl_full_title.GetLabel().endswith(city)):
            self.full_display.append(f"Error: {err}")

    def on_close(self, event):
        self.fetch.shutdown()
        event.Skip()
