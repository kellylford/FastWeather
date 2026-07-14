#!/usr/bin/env bash
#
# setup-release-secrets.sh — one-time: load the GitHub Actions secrets that
# .github/workflows/ios-release.yml needs to build + upload from a released-
# macOS runner (which is how we avoid the beta-macOS "invalid binary" reject).
#
# YOU run this (not Claude) so your private key + password never leave your
# machine. It reads local files, base64-encodes them, prompts for the .p12
# password, and sets each repo secret via the gh CLI.
#
# Usage:
#   cd iOS && scripts/setup-release-secrets.sh [/path/to/dist.p12]
#
set -euo pipefail

ASC_JSON="$HOME/.fastweather-keys/asc.json"
P12="${1:-$HOME/Desktop/FastWeatherDist.p12}"
SECRETS_SWIFT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/FastWeather/Services/Secrets.swift"

die() { echo "❌ $*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not found"
gh auth status >/dev/null 2>&1 || die "gh not authenticated (run: gh auth login)"
[[ -f "$ASC_JSON" ]] || die "missing $ASC_JSON"
[[ -f "$P12" ]] || die "distribution .p12 not found at: $P12  (pass the path as an argument)"

KEY_ID="$(python3 -c "import json;print(json.load(open('$ASC_JSON'))['key_id'])")"
ISSUER="$(python3 -c "import json;print(json.load(open('$ASC_JSON'))['issuer_id'])")"
P8="$(python3 -c "import json,os;print(os.path.expanduser(json.load(open('$ASC_JSON'))['p8_path']))")"
[[ -f "$P8" ]] || die "ASC .p8 not found at: $P8"

echo "Distribution cert: $P12"
echo "ASC key:           $P8  (key id $KEY_ID)"
echo ""

# --- .p12 password: prompt, then verify it actually opens the cert ---
printf "Enter the password you set when exporting the .p12: "
read -rs P12_PW; echo ""
[[ -n "$P12_PW" ]] || die "empty password"

# Verify the password + cert type with Apple's own `security import` into a
# throwaway keychain — this is exactly how the CI runner imports it, and unlike
# OpenSSL 3 it reads macOS Keychain's legacy-encrypted .p12 without complaint.
VKC="${TMPDIR:-/tmp}/fw-verify-$$.keychain-db"
VKP="$(uuidgen)"
security create-keychain -p "$VKP" "$VKC" >/dev/null 2>&1 || die "could not create a temp keychain to verify the .p12"
if ! security import "$P12" -k "$VKC" -P "$P12_PW" -T /usr/bin/codesign >/dev/null 2>&1; then
  security delete-keychain "$VKC" >/dev/null 2>&1 || true
  die "The password did not unlock the .p12. Double-check it and re-run."
fi
IDENT="$(security find-identity -v -p codesigning "$VKC" 2>/dev/null)"
security delete-keychain "$VKC" >/dev/null 2>&1 || true
echo "Cert in .p12: $(printf '%s\n' "$IDENT" | grep -oE '"[^"]+"' | head -1)"
case "$IDENT" in
  *"Apple Distribution"*|*"iPhone Distribution"*) echo "✅ Distribution certificate — good." ;;
  *"Apple Development"*|*"iPhone Developer"*)
    die "This is a DEVELOPMENT cert, not a Distribution cert. App Store builds need 'Apple Distribution'. Create/export that instead." ;;
  *) echo "⚠️  Could not confirm the cert type, continuing anyway." ;;
esac
echo ""

echo "Setting GitHub Actions secrets…"
gh secret set ASC_KEY_ID           --body "$KEY_ID"
gh secret set ASC_ISSUER_ID        --body "$ISSUER"
base64 < "$P8"  | gh secret set ASC_KEY_P8_BASE64
base64 < "$P12" | gh secret set DIST_CERT_P12_BASE64
printf '%s' "$P12_PW" | gh secret set DIST_CERT_PASSWORD

# --- optional: paid Open-Meteo key from local (gitignored) Secrets.swift ---
if [[ -f "$SECRETS_SWIFT" ]]; then
  OM_KEY="$(sed -n 's/.*openMeteoAPIKey[^"]*"\([^"]*\)".*/\1/p' "$SECRETS_SWIFT" | head -1)"
  if [[ -n "${OM_KEY:-}" ]]; then
    printf '%s' "$OM_KEY" | gh secret set OPENMETEO_API_KEY
    echo "  set OPENMETEO_API_KEY from Secrets.swift"
  else
    echo "  (no Open-Meteo key in Secrets.swift — build will use the free tier unless you set OPENMETEO_API_KEY)"
  fi
fi

unset P12_PW
echo ""
echo "Configured secrets:"
gh secret list
echo ""
echo "✅ Done. Next: trigger the cloud build with a fresh build number, e.g.:"
echo "   gh workflow run ios-release.yml -f build_number=6"
