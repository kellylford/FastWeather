# FastWeather iOS — TestFlight release

> **For the full release guide — including the critical beta-macOS constraint and
> the App Store submission flow — read [`../RELEASING.md`](../RELEASING.md) first.**
> This file only covers the local TestFlight script's flags.

One command builds, uploads, and wires a new build into TestFlight — no Xcode
Organizer, no manual App Store Connect clicking.

## One-time setup (already done)

Credentials and the App Store Connect API client live **outside the repo** in
`~/.fastweather-keys/` (never committed):

- `asc.json` — key id, issuer id, `.p8` path, app bundle id, team id
- `asc.py` — ASC REST client (signs its own ES256 JWT; stdlib + `cryptography`)
- `AuthKey_38ANZ53D9L.p8` — the ASC API private key (also in
  `~/.appstoreconnect/private_keys/`, where `altool` looks for it)

If the key is ever rotated, drop the new `.p8` in
`~/.appstoreconnect/private_keys/` and update `key_id` / `issuer_id` in
`asc.json`. The **Issuer ID** is only shown in App Store Connect →
Users and Access → Integrations.

## Cut a release

1. Bump the version/build in Xcode (or the pbxproj): `MARKETING_VERSION` and
   `CURRENT_PROJECT_VERSION`. Commit.
2. Edit `scripts/RELEASE_NOTES.txt` with this build's What-to-Test text.
3. Run:

   ```bash
   cd iOS
   scripts/release-testflight.sh --notes scripts/RELEASE_NOTES.txt
   ```

That archives (Release, automatic signing), exports a signed App Store IPA,
validates + uploads it via `altool`, waits for App Store Connect to finish
processing, then sets the notes, assigns the **Internal test** + **External**
groups, and submits external Beta App Review.

Internal testers get it immediately; external testers once review clears.

## Options

| Flag | Effect |
|------|--------|
| `--notes <file>` | **required** — path to the What-to-Test text |
| `--groups "A,B"` | which beta groups to assign (default `Internal test,External`) |
| `--no-external-review` | assign groups but don't submit for Beta App Review |
| `--wire-only --version X --build Y` | skip build/upload; just wire an already-uploaded build (e.g. one uploaded from Xcode) |

## Just the TestFlight wiring

If you uploaded from Xcode and only want the notes/groups/review applied:

```bash
scripts/release-testflight.sh --wire-only --version 1.5.9 --build 4 \
  --notes scripts/RELEASE_NOTES.txt
```

## Inspect state

```bash
python3 ~/.fastweather-keys/asc.py probe      # auth check
python3 ~/.fastweather-keys/asc.py discover   # app, recent builds, beta groups
```

## Notes / gotchas

- Signing is **automatic** (team `P887QF74N8`); the script passes
  `-allowProvisioningUpdates` so xcodebuild fetches the distribution profile.
- Export uses `scripts/ExportOptions.plist` (method `app-store-connect`).
- Build artifacts go to `iOS/build/` (gitignored).
- `altool` is deprecated by Apple but still the supported CLI upload path; if it
  is ever removed, swap the upload step for `xcrun notarytool`'s successor or
  Transporter — the wiring step (`asc.py testflight`) is unaffected.
