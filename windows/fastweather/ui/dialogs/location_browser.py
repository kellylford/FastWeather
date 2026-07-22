"""Browse cities by US state or international country (multi-select add)."""

import wx


class LocationBrowserDialog(wx.Dialog):
    """Dialog for browsing cities by US State or International Country."""

    def __init__(self, parent, us_cities_cache, intl_cities_cache):
        super().__init__(parent, title="Browse Cities by Location", size=(700, 600))
        self.us_cities_cache = us_cities_cache
        self.intl_cities_cache = intl_cities_cache
        self.selected_cities = []  # (display_name, lat, lon)

        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)

        self.notebook = wx.Notebook(panel)

        # US States tab
        us_panel = wx.Panel(self.notebook)
        us_sizer = wx.BoxSizer(wx.VERTICAL)
        us_sizer.Add(wx.StaticText(us_panel, label="Select a U.S. State:"), 0, wx.ALL, 10)
        self.state_choice = wx.Choice(us_panel)
        if us_cities_cache:
            self.state_choice.Append("-- Select a State --")
            for state in sorted(us_cities_cache.keys()):
                self.state_choice.Append(state)
            self.state_choice.SetSelection(0)
        us_sizer.Add(self.state_choice, 0, wx.EXPAND | wx.ALL, 10)
        self.load_state_btn = wx.Button(us_panel, label="Load Cities")
        us_sizer.Add(self.load_state_btn, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        us_panel.SetSizer(us_sizer)

        # International tab
        intl_panel = wx.Panel(self.notebook)
        intl_sizer = wx.BoxSizer(wx.VERTICAL)
        intl_sizer.Add(wx.StaticText(intl_panel, label="Select a Country:"), 0, wx.ALL, 10)
        self.country_choice = wx.Choice(intl_panel)
        if intl_cities_cache:
            self.country_choice.Append("-- Select a Country --")
            for country in sorted(intl_cities_cache.keys()):
                self.country_choice.Append(country)
            self.country_choice.SetSelection(0)
        intl_sizer.Add(self.country_choice, 0, wx.EXPAND | wx.ALL, 10)
        self.load_country_btn = wx.Button(intl_panel, label="Load Cities")
        intl_sizer.Add(self.load_country_btn, 0, wx.ALIGN_CENTER | wx.ALL, 10)
        intl_panel.SetSizer(intl_sizer)

        self.notebook.AddPage(us_panel, "U.S. States")
        self.notebook.AddPage(intl_panel, "International")
        vbox.Add(self.notebook, 0, wx.EXPAND | wx.ALL, 10)

        vbox.Add(
            wx.StaticText(panel, label="Select cities to add (check multiple cities):"),
            0, wx.ALL, 10,
        )
        self.cities_list = wx.CheckListBox(panel)
        vbox.Add(self.cities_list, 1, wx.EXPAND | wx.ALL, 10)

        sel_box = wx.BoxSizer(wx.HORIZONTAL)
        self.select_all_btn = wx.Button(panel, label="Select All")
        self.deselect_all_btn = wx.Button(panel, label="Deselect All")
        sel_box.Add(self.select_all_btn, 0, wx.RIGHT, 5)
        sel_box.Add(self.deselect_all_btn, 0)
        vbox.Add(sel_box, 0, wx.ALIGN_CENTER | wx.ALL, 10)

        btns = wx.StdDialogButtonSizer()
        add_btn = wx.Button(panel, wx.ID_OK, "Add Selected Cities")
        cancel_btn = wx.Button(panel, wx.ID_CANCEL)
        btns.AddButton(add_btn)
        btns.AddButton(cancel_btn)
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 10)

        panel.SetSizer(vbox)

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
            for city_data in self.us_cities_cache[state_name]:
                display = f"{city_data['name']}, {city_data['state']}, {city_data['country']}"
                self.cities_list.Append(display)
                self.cities_list.SetClientData(
                    self.cities_list.GetCount() - 1,
                    (city_data["name"], city_data["lat"], city_data["lon"],
                     city_data["state"], city_data["country"]),
                )

    def on_load_country(self, event):
        sel = self.country_choice.GetSelection()
        if sel == 0 or sel == wx.NOT_FOUND:
            wx.MessageBox("Please select a country", "No Selection", wx.OK | wx.ICON_WARNING)
            return
        country_name = self.country_choice.GetString(sel)
        if country_name in self.intl_cities_cache:
            self.cities_list.Clear()
            for city_data in self.intl_cities_cache[country_name]:
                parts = [city_data["name"]]
                if city_data.get("state"):
                    parts.append(city_data["state"])
                parts.append(country_name)
                display = ", ".join(parts)
                self.cities_list.Append(display)
                self.cities_list.SetClientData(
                    self.cities_list.GetCount() - 1,
                    (city_data["name"], city_data["lat"], city_data["lon"],
                     city_data.get("state", ""), country_name),
                )

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
                name, lat, lon, state, country = self.cities_list.GetClientData(i)
                parts = [name]
                if state:
                    parts.append(state)
                parts.append(country)
                self.selected_cities.append((", ".join(parts), lat, lon))

        if not self.selected_cities:
            wx.MessageBox(
                "Please select at least one city to add", "No Cities Selected",
                wx.OK | wx.ICON_WARNING,
            )
            return
        self.EndModal(wx.ID_OK)

    def get_selected_cities(self):
        return self.selected_cities
