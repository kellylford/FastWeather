"""Disambiguation dialog shown when geocoding returns multiple matches."""

import wx


class CitySelectionDialog(wx.Dialog):
    def __init__(self, parent, matches, original_input):
        super().__init__(parent, title="Select City", size=(600, 400))
        self.matches = matches
        self.selected_match = None

        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        vbox.Add(
            wx.StaticText(panel, label=f"Multiple cities found for '{original_input}':"),
            0, wx.ALL, 10,
        )

        self.city_list = wx.ListBox(panel, style=wx.LB_SINGLE)
        for match in matches:
            self.city_list.Append(
                f"{match['display']} ({match['lat']:.4f}, {match['lon']:.4f})"
            )
        if matches:
            self.city_list.SetSelection(0)

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
