#!/usr/bin/env python3
"""FastWeather entry shim.

The application was refactored from this single file into the ``fastweather``
package (services / models / cache / ui). This shim is kept as the runnable
entry point so ``python fastweather.py`` and the existing PyInstaller build
(entry ``fastweather.py``) keep working unchanged. All logic now lives in the
package; see ``fastweather/__main__.py``.
"""

from fastweather.__main__ import main

if __name__ == "__main__":
    main()
