"""Custom wx events posted from background worker threads.

A single generic FetchResultEvent carries every async result (keyed by ``kind``)
so new features do not each need a bespoke event class. ``request_id`` lets a
view discard stale results (e.g. the user switched cities mid-fetch).
"""

import wx.lib.newevent

# Generic async result event: fields kind, request_id, payload, error
FetchResultEvent, EVT_FETCH_RESULT = wx.lib.newevent.NewEvent()
