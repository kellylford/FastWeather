# tools — testing and validation tooling

Single home for every out-of-app testing tool. **The pattern (use it for all
future diagnostic tools):**

1. **Tools live here, on `main`** — the single source of truth. Develop new
   tools on main (or merge them to main promptly) so every new branch
   inherits them automatically.
2. **Tools are run from the OneDrive folder**
   (`~/Library/CloudStorage/OneDrive-Personal/RadarData/`) via Finder
   double-clickable `.command` wrappers. Each wrapper first calls
   `fastweather-tools-sync.sh` (in that folder), which exports main's
   `tools/` to a local cache (`~/.fastweather-tools`) using `git archive` —
   so a run always uses main's current tools no matter which branch is
   checked out in the repo, and nothing needs manual re-copying.
3. **Results always log to the OneDrive folder** (per-run subfolders like
   `datatesting/run-<timestamp>/`), never into the repo.

Adding a new tool: put it in `tools/<area>/` on main, keep it Python-stdlib
only where possible, make it take an `--output-root`-style flag, and add a
`.command` wrapper in RadarData that syncs then runs it.

## tools/datatesting — nowcast data validation

Validates the nowcast feature set's data layer against live APIs with
line-for-line Python ports of the Swift algorithms. See
`tools/datatesting/README.md`.

- `nowcast_data_test.py` — 100-city old-vs-new comparison runs with
  consistency checks; results to CSV per run folder.
- `madison_diag.py` — one-off diagnostic comparing Storm Approach's ring
  (fixed ~43 mi) against the Weather Around Me directional tiles at the
  picker distance for east-side Madison; written to investigate the
  direction-disagreement report of 2026-07-04. Edit LAT/LON/DIST at top to
  reuse elsewhere.

Finder wrapper: `Test Nowcast Data.command` (in RadarData).

## tools/quickradar — radar image experiment lab

The radar-image and AI-description experiment suite from the
`docs/nowcasting-proposal` branch (collected here so it isn't stranded on
that branch). Fetches NWS/NOAA radar imagery, builds archives, runs and
compares AI descriptions (cloud + local models), and generates accessible
reports. See `tools/quickradar/README.md` and `resumework.md` for state.

Key entry points:
- `quickradar.py` — capture + describe radar for a zipcode/city
- `weather_lab.py` — full free NOAA image suite + per-type descriptions +
  audio sweep, output as accessible report.html
- `build_radar_archive.py` — archive builder (per-run folders, multi-model)
- `compare_models.py`, `run_*_experiment.py` — model comparison harnesses

Finder wrappers: `Test Live Radar.command`, `Capture Radar Images.command`
(in RadarData; they point at `tools/quickradar`).

Note: the AI/radar-image features these scripts supported were deliberately
NOT ported to the app (see `docs/NOWCASTING_AND_SHORT_TERM_FORECAST_PROPOSAL.md`).
The lab is kept for data-gathering and future reference.
