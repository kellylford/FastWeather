"""Background fetch orchestration.

Generalizes the original per-operation Thread subclasses into one
ThreadPoolExecutor-backed manager. Each ``submit`` runs a wx-free callable on a
worker thread and posts a single generic FetchResultEvent back to the target
window (safe cross-thread via wx.PostEvent). Views dispatch on ``kind`` and may
use ``request_id`` to ignore stale results.
"""

from concurrent.futures import ThreadPoolExecutor

import wx

from ..ui.events import FetchResultEvent


class FetchManager:
    """Owns a thread pool and bridges worker results to the wx event loop."""

    def __init__(self, target_window, max_workers=8):
        self.target = target_window
        self.executor = ThreadPoolExecutor(max_workers=max_workers)

    def submit(self, kind, fn, request_id=None):
        """Run ``fn()`` on a worker; post a FetchResultEvent when it finishes."""
        self.executor.submit(self._run, kind, fn, request_id)

    def _run(self, kind, fn, request_id):
        payload, error = None, None
        try:
            payload = fn()
        except Exception as e:  # noqa: BLE001 - surface any failure to the UI
            error = str(e)
        # The target may be destroyed during shutdown; guard the post.
        try:
            wx.PostEvent(
                self.target,
                FetchResultEvent(
                    kind=kind, request_id=request_id, payload=payload, error=error
                ),
            )
        except Exception:
            pass

    def shutdown(self):
        self.executor.shutdown(wait=False)
