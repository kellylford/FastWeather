#!/bin/bash
# ─────────────────────────────────────────────────────────────
# run_archive.sh  —  Radar test bed data capture
#
# Downloads NWS NEXRAD radar images, then runs them through
# Foundation Models (on-device, macOS 27) for AI descriptions.
# Optionally also runs Ollama local models.
#
# Usage:
#   ./run_archive.sh                   — capture all cities, run FM descriptions
#   ./run_archive.sh --no-alerts       — skip NWS alert hunting
#   ./run_archive.sh --no-local        — skip Ollama (FM still runs)
#   ./run_archive.sh --no-fm           — skip Foundation Models (images + Ollama only)
#   ./run_archive.sh --local-models minicpm-v4.6   — specific Ollama model
#
# Edit prompt.txt in this folder to change the AI prompt.
# The same prompt is used by Foundation Models and Ollama.
#
# After capture, open the images/ folder in the OneDrive app on your iPhone
# to get VoiceOver descriptions. Paste into the matching voiceover/*.txt files.
# ─────────────────────────────────────────────────────────────

set -e

RADAR_DATA_DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve tools via the shared sync script: the checked-out branch's tools/
# (every branch carries it), with a fallback to main's copy for old branches.
TOOLS_DIR="$(bash "$RADAR_DATA_DIR/fastweather-tools-sync.sh")" || {
    echo "ERROR: could not resolve FastWeather tools directory"; exit 1; }
QUICKRADAR_DIR="$TOOLS_DIR/quickradar"
VENV_DIR="$HOME/.radar_archive_venv"
XCODE_BETA="/Applications/Xcode-beta.app/Contents/Developer"
MACOS27_SDK="$XCODE_BETA/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.sdk"

# ── Parse --no-fm flag (all other args pass through to Python) ───────────────
RUN_FM=true
PYTHON_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--no-fm" ]; then
        RUN_FM=false
    else
        PYTHON_ARGS+=("$arg")
    fi
done

# ── Virtual environment setup ────────────────────────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    echo "First run: creating Python virtual environment at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install -q --upgrade pip
pip install -q requests Pillow

echo ""
echo "================================================================"
echo " RADAR ARCHIVE BUILDER"
echo " Output: $RADAR_DATA_DIR"
echo "================================================================"
echo ""

# ── Python: download images, pixel analysis, NWS data, Ollama ───────────────
python3 "$QUICKRADAR_DIR/build_radar_archive.py" \
    --output-dir "$RADAR_DATA_DIR" \
    --no-cloud \
    "${PYTHON_ARGS[@]}"

# ── Find the run directory Python just created ───────────────────────────────
NEW_RUN_DIR=$(ls -td "$RADAR_DATA_DIR/runs"/*/ 2>/dev/null | head -1 | sed 's|/$||')

if [ -z "$NEW_RUN_DIR" ]; then
    echo "⚠️  Could not find new run directory — skipping Foundation Models step"
    exit 0
fi

echo ""
echo "================================================================"
echo " FOUNDATION MODELS DESCRIPTIONS"
echo " Run: $(basename "$NEW_RUN_DIR")"
echo " Prompt: $RADAR_DATA_DIR/prompt.txt"
echo "================================================================"
echo ""

# ── Swift: run Foundation Models on all images in the new run ────────────────
if [ "$RUN_FM" = true ]; then
    if [ ! -f "$MACOS27_SDK/SDKSettings.json" ] && [ ! -f "$MACOS27_SDK/SDKSettings.plist" ]; then
        echo "⚠️  macOS 27 SDK not found at $MACOS27_SDK"
        echo "    Install Xcode beta to enable Foundation Models descriptions."
    else
        DEVELOPER_DIR="$XCODE_BETA" \
        swift \
            -sdk "$MACOS27_SDK" \
            "$RADAR_DATA_DIR/fm_describe.swift" \
            "$NEW_RUN_DIR"
    fi
else
    echo "Skipping Foundation Models (--no-fm)"
fi

echo ""
echo "All done. Run saved to:"
echo "  $NEW_RUN_DIR"
