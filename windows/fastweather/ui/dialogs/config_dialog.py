"""Configure which weather fields display, plus unit selection.

Operates on a plain config dict (a copy of AppSettings.to_dict()); returns the
edited dict via get_configuration(). Apply previews changes live via the
parent's apply_config_changes(new_config).
"""

import copy

import wx


class WeatherConfigDialog(wx.Dialog):
    def __init__(self, parent, current_config):
        super().__init__(parent, title="Configure Weather Display", size=(600, 500))
        self.config = copy.deepcopy(current_config)

        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        vbox.Add(
            wx.StaticText(panel, label="Select weather details to display:"), 0, wx.ALL, 10
        )

        nb = wx.Notebook(panel)
        self.checkboxes = {"current": {}, "hourly": {}, "daily": {}}
        self.unit_controls = {}

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

        add_tab("Current", "current", [
            ("temperature", "Temperature"), ("feels_like", "Feels Like"),
            ("humidity", "Humidity"), ("wind_speed", "Wind Speed"),
            ("wind_direction", "Wind Direction"), ("pressure", "Pressure"),
            ("visibility", "Visibility"), ("uv_index", "UV Index"),
            ("precipitation", "Precipitation"), ("cloud_cover", "Cloud Cover"),
            ("snowfall", "Snowfall"), ("snow_depth", "Snow Depth"),
            ("rain", "Rain"), ("showers", "Showers"),
        ])
        add_tab("Hourly", "hourly", [
            ("temperature", "Temperature"), ("feels_like", "Feels Like"),
            ("humidity", "Humidity"), ("precipitation", "Precipitation"),
            ("wind_speed", "Wind Speed"), ("wind_direction", "Wind Direction"),
            ("cloud_cover", "Cloud Cover"), ("snowfall", "Snowfall"),
            ("rain", "Rain"), ("showers", "Showers"),
        ])
        add_tab("Daily", "daily", [
            ("temperature_max", "High Temp"), ("temperature_min", "Low Temp"),
            ("sunrise", "Sunrise"), ("sunset", "Sunset"),
            ("precipitation_sum", "Precip Total"), ("precipitation_hours", "Precip Hours"),
            ("wind_speed_max", "Max Wind"), ("wind_direction_dominant", "Wind Direction"),
            ("snowfall_sum", "Snowfall Total"), ("rain_sum", "Rain Total"),
            ("showers_sum", "Showers Total"),
        ])

        # Units tab
        units_panel = wx.Panel(nb)
        units_sizer = wx.BoxSizer(wx.VERTICAL)

        temp_box = wx.StaticBox(units_panel, label="Temperature")
        temp_sizer = wx.StaticBoxSizer(temp_box, wx.HORIZONTAL)
        self.unit_controls["temp_f"] = wx.RadioButton(
            units_panel, label="Fahrenheit (°F)", style=wx.RB_GROUP
        )
        self.unit_controls["temp_c"] = wx.RadioButton(units_panel, label="Celsius (°C)")
        self.unit_controls["temp_f"].SetValue(self.config["units"].get("temperature", "F") == "F")
        self.unit_controls["temp_c"].SetValue(self.config["units"].get("temperature", "F") == "C")
        temp_sizer.Add(self.unit_controls["temp_f"], 0, wx.ALL, 5)
        temp_sizer.Add(self.unit_controls["temp_c"], 0, wx.ALL, 5)
        units_sizer.Add(temp_sizer, 0, wx.EXPAND | wx.ALL, 10)

        wind_box = wx.StaticBox(units_panel, label="Wind Speed")
        wind_sizer = wx.StaticBoxSizer(wind_box, wx.HORIZONTAL)
        self.unit_controls["wind_mph"] = wx.RadioButton(
            units_panel, label="Miles per hour (mph)", style=wx.RB_GROUP
        )
        self.unit_controls["wind_kmh"] = wx.RadioButton(
            units_panel, label="Kilometers per hour (km/h)"
        )
        self.unit_controls["wind_mph"].SetValue(self.config["units"].get("wind_speed", "mph") == "mph")
        self.unit_controls["wind_kmh"].SetValue(self.config["units"].get("wind_speed", "mph") == "km/h")
        wind_sizer.Add(self.unit_controls["wind_mph"], 0, wx.ALL, 5)
        wind_sizer.Add(self.unit_controls["wind_kmh"], 0, wx.ALL, 5)
        units_sizer.Add(wind_sizer, 0, wx.EXPAND | wx.ALL, 10)

        precip_box = wx.StaticBox(units_panel, label="Precipitation")
        precip_sizer = wx.StaticBoxSizer(precip_box, wx.HORIZONTAL)
        self.unit_controls["precip_in"] = wx.RadioButton(
            units_panel, label="Inches (in)", style=wx.RB_GROUP
        )
        self.unit_controls["precip_mm"] = wx.RadioButton(units_panel, label="Millimeters (mm)")
        self.unit_controls["precip_in"].SetValue(self.config["units"].get("precipitation", "in") == "in")
        self.unit_controls["precip_mm"].SetValue(self.config["units"].get("precipitation", "in") == "mm")
        precip_sizer.Add(self.unit_controls["precip_in"], 0, wx.ALL, 5)
        precip_sizer.Add(self.unit_controls["precip_mm"], 0, wx.ALL, 5)
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

    def _harvest(self):
        for section in self.checkboxes:
            for key, cb in self.checkboxes[section].items():
                self.config[section][key] = cb.GetValue()
        self.config["units"]["temperature"] = "F" if self.unit_controls["temp_f"].GetValue() else "C"
        self.config["units"]["wind_speed"] = "mph" if self.unit_controls["wind_mph"].GetValue() else "km/h"
        self.config["units"]["precipitation"] = "in" if self.unit_controls["precip_in"].GetValue() else "mm"

    def on_ok(self, event):
        self._harvest()
        self.EndModal(wx.ID_OK)

    def on_apply(self, event):
        self._harvest()
        parent = self.GetParent()
        if parent and hasattr(parent, "apply_config_changes"):
            parent.apply_config_changes(self.config)

    def get_configuration(self):
        return self.config
