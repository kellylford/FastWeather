#!/bin/bash
# fastweather-tools-sync.sh — resolve the tools/ directory for the wrappers.
#
# The pattern: every branch carries tools/ (it lives on main, so new branches
# inherit it). Wrappers run the CHECKED-OUT repo's tools directly — whatever
# branch is open — so branch-local tool changes are exercised. Only if an old
# branch without tools/ happens to be checked out do we fall back to
# exporting main's copy into a local cache. Results always log to this
# OneDrive folder either way.
#
# Prints the tools directory path on success.
REPO="/Users/kellyford/Documents/GitHub/FastWeather"
CACHE="$HOME/.fastweather-tools"

# Normal case: the checked-out branch has tools/.
if [ -d "$REPO/tools/datatesting" ]; then
    echo "$REPO/tools"
    exit 0
fi

# Fallback: old branch without tools/ — use main's copy via git archive.
echo "Checked-out branch has no tools/; using main's copy." >&2
if ! git -C "$REPO" rev-parse --verify main >/dev/null 2>&1; then
    echo "ERROR: cannot read branch main in $REPO" >&2
    exit 1
fi
mkdir -p "$CACHE"
rm -rf "$CACHE/tools"
if ! git -C "$REPO" archive main tools 2>/dev/null | tar -x -C "$CACHE"; then
    echo "ERROR: could not export tools/ from main" >&2
    exit 1
fi
echo "$CACHE/tools"
