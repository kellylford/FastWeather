"""Weather Alerts sheet (US / NWS).

Distinguishes three states clearly: active alerts, no active alerts, and
"couldn't check" (fetch failed) - the last must never read as "no alerts".
"""

import threading
from datetime import datetime

import wx

from ...services import alert_service
from ..accessible_list import AccessibleLinesPanel


def _fmt_time(iso):
    if not iso:
        return ""
    try:
        return datetime.fromisoformat(iso).strftime("%a %b %d %I:%M %p")
    except Exception:
        return iso


class AlertsDialog(wx.Dialog):
    def __init__(self, parent, center):
        super().__init__(parent, title=f"Weather Alerts - {center[0]}", size=(680, 560))
        self.center = center
        self._alive = True

        panel = wx.Panel(self)
        vbox = wx.BoxSizer(wx.VERTICAL)
        self.status = wx.StaticText(panel, label="Checking for alerts...")
        vbox.Add(self.status, 0, wx.ALL, 8)
        self.lines = AccessibleLinesPanel(panel)
        vbox.Add(self.lines, 1, wx.EXPAND | wx.ALL, 8)
        btns = wx.StdDialogButtonSizer()
        btns.AddButton(wx.Button(panel, wx.ID_CLOSE))
        btns.Realize()
        vbox.Add(btns, 0, wx.ALIGN_CENTER | wx.ALL, 8)
        panel.SetSizer(vbox)
        self.Bind(wx.EVT_BUTTON, lambda e: self.Close(), id=wx.ID_CLOSE)
        self.Bind(wx.EVT_CLOSE, self._on_close)

        wx.CallAfter(self.load)

    def load(self):
        self.lines.set_message("Checking...")
        name, lat, lon = self.center

        def work():
            try:
                alerts = alert_service.fetch_alerts(lat, lon)
            except Exception as e:  # noqa: BLE001
                wx.CallAfter(self._error, str(e))
                return
            wx.CallAfter(self._ready, alerts)

        threading.Thread(target=work, daemon=True).start()

    def _error(self, err):
        if not self._alive:
            return
        # Safety invariant: a failure is NOT "no alerts".
        self.status.SetLabel("Could not check alerts.")
        self.lines.set_lines([
            "Could not check for weather alerts.",
            f"Reason: {err}",
            "",
            "This does NOT mean there are no alerts. Try again, or check "
            "weather.gov directly.",
        ])

    def _ready(self, alerts):
        if not self._alive:
            return
        if not alerts:
            self.status.SetLabel("No active alerts.")
            self.lines.set_lines([f"No active weather alerts for {self.center[0]}.",
                                  "(US National Weather Service)"])
            return
        self.status.SetLabel(
            f"{len(alerts)} active alert{'s' if len(alerts) != 1 else ''}.")
        lines = []
        for i, a in enumerate(alerts, 1):
            lines.append(f"[{a.severity}] {a.event}")
            if a.area:
                lines.append(f"  Area: {a.area}")
            when = " - ".join(x for x in [_fmt_time(a.onset), _fmt_time(a.ends)] if x)
            if when:
                lines.append(f"  When: {when}")
            if a.headline:
                lines.append(f"  {a.headline}")
            if a.description:
                for seg in a.description.split("\n"):
                    seg = seg.strip()
                    if seg:
                        lines.append(f"  {seg}")
            if a.instruction:
                lines.append(f"  Instructions: {a.instruction}")
            # Unindented header of the next alert delimits entries.
        self.lines.set_lines(lines)
        self.lines.set_focus()

    def _on_close(self, event):
        self._alive = False
        event.Skip()
