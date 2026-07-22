"""Reusable screen-reader-friendly "ListBox of lines" widget.

This is the accessibility backbone: weather data is rendered as individual
list items so screen-reader users navigate datum-by-datum with the arrow keys.
Empty and separator (---/===) lines are filtered out, matching the monolith.
"""

import wx


def _is_visible_line(line):
    stripped = line.strip()
    return bool(stripped) and not all(c in "-=" for c in stripped)


class AccessibleLinesPanel(wx.Panel):
    """A monospace single-select ListBox that renders a list of text lines."""

    def __init__(self, parent):
        super().__init__(parent)
        sizer = wx.BoxSizer(wx.VERTICAL)
        self.listbox = wx.ListBox(self, style=wx.LB_SINGLE)
        self.listbox.SetFont(
            wx.Font(10, wx.FONTFAMILY_TELETYPE, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL)
        )
        sizer.Add(self.listbox, 1, wx.EXPAND)
        self.SetSizer(sizer)

    def set_lines(self, lines):
        """Replace contents with the given lines (filtered for accessibility)."""
        self.listbox.Clear()
        for line in lines:
            if _is_visible_line(line):
                self.listbox.Append(line)
        if self.listbox.GetCount() > 0:
            self.listbox.SetSelection(0)

    def set_message(self, text):
        """Show a single status line (e.g. 'Loading...' or an error)."""
        self.listbox.Clear()
        self.listbox.Append(text)

    def append(self, text):
        self.listbox.Append(text)

    def clear(self):
        self.listbox.Clear()

    def set_focus(self):
        self.listbox.SetFocus()
