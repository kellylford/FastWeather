# tools/wrappers — versioned copies of the OneDrive launch set

Everything in this folder LIVES AND RUNS in
`~/Library/CloudStorage/OneDrive-Personal/RadarData/` — these are the
version-controlled copies, so the launch set is in git and a new machine (or
a wiped RadarData folder) can be restored by copying this folder's contents
there and marking the `.command` files executable.

The set:

- `fastweather-tools-sync.sh` — resolves the `tools/` directory for every
  wrapper: the checked-out repo's `tools/` (all current branches carry it),
  falling back to `git archive` of main's copy for old branches.
- `Test Nowcast Data.command` — runs `tools/datatesting/nowcast_data_test.py`;
  results to `RadarData/datatesting/run-<timestamp>/`.
- `Test Live Radar.command` — runs `tools/quickradar/run_test_prompt.sh`;
  results to `RadarData/test_logs/`.
- `Madison Diagnostic.command` — runs `tools/datatesting/madison_diag.py`;
  report to `RadarData/datatesting/madison-diag-<timestamp>.txt`.
- `Capture Radar Images.command` — thin delegate to `run_archive.sh`.
- `run_archive.sh` — radar archive builder: NEXRAD capture +
  Foundation Models descriptions (+ optional Ollama); output to
  `RadarData/runs/`.
- `fm_describe.swift` — Foundation Models description runner used by
  `run_archive.sh`; must sit next to `prompt.txt` at runtime (it reads the
  prompt from its own directory).
- `prompt.txt` — the LIVE, user-editable FM radar-description prompt for the
  archive builder. NOTE: distinct from `tools/quickradar/prompt.txt`, which
  is quickradar.py's config file — same filename, different artifact.

Sync discipline: the RadarData copies are the live ones. After editing a
wrapper here, copy it to RadarData; after editing a live copy there
(especially `prompt.txt`), snapshot it back here and commit on main.
