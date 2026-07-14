# iOS Releasing — TestFlight & App Store (READ THIS FIRST)

Canonical guide for shipping FastWeather iOS. If you are an AI or a new
contributor, read this before touching any release step — it encodes several
things that cost real time to discover.

---

## ⛔ GOLDEN RULE: never build App Store binaries on this Mac

**This development Mac runs a _beta_ macOS.** Apple rejects any App Store binary
built on a beta OS/SDK as **`INVALID_BINARY`** — no matter which Xcode you
select. Pinning the released `Xcode.app` does **not** help; the operating system
itself is the disqualifier. (Builds 4 and 5 were both rejected this way before
we understood it.)

- **App Store (public) builds → MUST come from GitHub Actions** (`ios-release.yml`),
  which runs on a GitHub-hosted **released**-macOS runner.
- **TestFlight builds → local is fine.** TestFlight accepts beta-OS binaries;
  the App Store review does not.

How to tell if a machine is on beta macOS: `sw_vers -buildVersion`. A build
number ending in a **lowercase letter** (e.g. `26A5378j`) is a beta seed; a
released build ends in a **digit** (e.g. `24A335`). The CI workflow has a guard
that aborts if its runner is somehow on a beta OS.

---

## Cutting an App Store release (the runbook)

1. **Bump the build number** (and marketing version if needed) in
   `FastWeather.xcodeproj/project.pbxproj`, commit to `main`. Build numbers must
   be **unique and increasing** per marketing version; a rejected build's number
   is spent — go to the next one.
2. **Trigger the cloud build** (released-macOS runner builds + uploads):
   ```bash
   gh workflow run ios-release.yml -f build_number=<N>
   # optional: -f marketing_version=1.5.9   (leave off to keep the project's value)
   gh run watch $(gh run list --workflow=ios-release.yml -L1 --json databaseId --jq '.[0].databaseId')
   ```
3. **Wait for the run to succeed.** It archives, exports, and uploads to App
   Store Connect. The build then processes for a few minutes (→ `VALID`).
4. **Attach the build to the App Store version and submit for review** — see
   [App Store submission flow](#app-store-submission-flow-via-ascpy) below.

That's it. Do **not** run a local `xcodebuild archive` for an App Store build.

---

## Versioning rules (learned the hard way)

- **Binary version** — `CFBundleShortVersionString` / `MARKETING_VERSION` must be
  **at most three integers**. `1.5.8.5` is rejected at upload (`error 90060`).
  Keep the binary at `1.5.8`.
- **Store label** — `appStoreVersions.versionString` MAY be four parts and does
  **not** have to equal the binary version. Kelly's convention labels the store
  version `X.Y.Z.build` (e.g. **`1.5.8.5`** for build 5) while the binary stays
  `1.5.8`. Set that label on the version record (see `rename_appstore_version`),
  not in the project.
- So a typical cycle: binary `1.5.8` / build `6`, store label `1.5.8.6`.

---

## Credentials & tooling (all OUTSIDE the repo)

Nothing secret is committed. Everything lives in `~/.fastweather-keys/`:

| File | What |
|------|------|
| `asc.json` | App Store Connect API config: `key_id`, `issuer_id`, `p8_path`, `app_bundle_id`, `team_id`. **The Issuer ID exists only here and in Apple's web UI** (Users and Access → Integrations) — it is not in the `.p8`. |
| `asc.py` | App Store Connect REST client. Signs its own ES256 JWT with the `cryptography` lib (no PyJWT). Reads `asc.json`. |
| `AuthKey_*.p8` | The ASC API private key (also in `~/.appstoreconnect/private_keys/`, where `altool` looks). |

`asc.py` subcommands:
```bash
python3 ~/.fastweather-keys/asc.py probe       # auth check — list visible apps
python3 ~/.fastweather-keys/asc.py discover    # app id, recent builds, beta group ids
python3 ~/.fastweather-keys/asc.py testflight --version 1.5.8 --build 6 \
        --notes-file scripts/RELEASE_NOTES.txt --groups "Internal test,External"
```
For one-off calls: `import asc; asc.api(method, path, body=, query=)`.

### GitHub Actions secrets (already configured)
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `DIST_CERT_P12_BASE64`,
`DIST_CERT_PASSWORD`, `OPENMETEO_API_KEY`. To (re)set them — e.g. after a cert
renewal — run **`scripts/setup-release-secrets.sh`** (or double-click the Desktop
`Setup FastWeather Release Secrets.command`). It reads the local `.p8` and a
distribution `.p12`, prompts for the `.p12` password, verifies the cert is an
**Apple Distribution** cert via `security import` (see gotchas), and sets each
secret with `gh secret set`. **A human runs it** so the password never lands in a
transcript.

---

## Scripts in this folder

| Script | Purpose |
|--------|---------|
| `.github/workflows/ios-release.yml` (repo root) | **App Store build** on a released-macOS runner. The only correct way to build for the App Store from this environment. |
| `scripts/release-testflight.sh` | **Local TestFlight** pipeline. `--upload-only` = build+upload only; `--wire-only --version X --build Y` = skip build, just wire an already-uploaded build (notes + groups + beta review). **Do not use for App Store** — see the golden rule. |
| `scripts/setup-release-secrets.sh` | (Re)set the GitHub Actions secrets from local files. Human-run. |
| `scripts/ExportOptions.plist` | App Store export options (method `app-store-connect`, automatic signing, team). |
| `scripts/RELEASE_NOTES.txt` | Working TestFlight "What to Test" text. |

---

## App Store submission flow (via `asc.py`)

After the cloud build is uploaded and `VALID`. Helper functions in `asc.py`;
the raw REST endpoints are noted so this works even without the client.

1. **Find the build id**: `find_build(app, "1.5.8", "6")` — note `Build.version`
   is the build number; the `1.5.8` comes from `preReleaseVersion.version`.
   ⚠️ ASC **sparse fieldsets drop relationships**: request
   `fields[builds]=version,processingState,preReleaseVersion` or the
   `preReleaseVersion` link is omitted and the version can't be matched.
2. **Prepare the version record** (`GET /v1/apps/{app}/appStoreVersions`):
   - Reuse the pending version (it holds the release notes). If its label needs
     to change, `rename_appstore_version(vid, "1.5.8.6")`
     (`PATCH /v1/appStoreVersions/{vid}` → `versionString`). Renaming preserves
     the `appStoreVersionLocalizations` (release notes / whatsNew).
3. **Attach the build**: `attach_build_to_appstore_version(vid, build_id)`
   (`PATCH /v1/appStoreVersions/{vid}/relationships/build`). This moves the
   version `INVALID_BINARY` → `PREPARE_FOR_SUBMISSION`.
4. **Clear stale submissions**: a version stays locked to a prior submission. If
   `add_review_item` returns `409 ITEM_PART_OF_ANOTHER_SUBMISSION`, cancel the old
   one: `cancel_review_submission(id)` (`PATCH …/reviewSubmissions/{id}` →
   `canceled:true`). A rejected submission shows `state=UNRESOLVED_ISSUES` with
   its item `REJECTED`.
5. **Create → add → submit**:
   - `create_review_submission(app)` → `POST /v1/reviewSubmissions` (platform IOS + app)
   - `add_review_item(sub, vid)` → `POST /v1/reviewSubmissionItems`
     (**retry for ~10-20s** while the cancel from step 4 propagates)
   - `submit_review_submission(sub)` → `PATCH …/reviewSubmissions/{sub}` `submitted:true`
6. **Verify**: version state should read `WAITING_FOR_REVIEW`.

---

## TestFlight (local build is OK)

```bash
cd iOS
scripts/release-testflight.sh --notes scripts/RELEASE_NOTES.txt
```
Builds, uploads, sets the What-to-Test notes, assigns the **Internal test** and
**External** beta groups, and submits external Beta App Review. Internal testers
get it immediately; external testers after beta review. Run
`python3 ~/.fastweather-keys/asc.py discover` to see group ids. See
`scripts/RELEASE.md` for flag details.

---

## Gotchas that already bit us (don't rediscover them)

- **Beta macOS ⇒ invalid App Store binary.** The whole reason `ios-release.yml`
  exists. (Golden rule above.)
- **`CFBundleShortVersionString` ≤ 3 integers** at the binary level; the 4-part
  label goes on the store version record only.
- **OpenSSL 3 cannot read a Keychain-exported `.p12`** (legacy encryption) — it
  false-fails "password wrong." Verify/import with Apple's `security` tool
  instead (that's also what the CI runner uses).
- **`GROUPS` is a reserved bash array** (the user's group IDs). A shell var named
  `GROUPS` silently becomes `20` (the `staff` gid) on macOS. Name it anything
  else (`BETA_GROUPS`).
- **macOS default bash is 3.2** and `sed` is BSD (no `\b`). Scripts target that.
- **ASC sparse fieldsets drop relationships** unless the relationship name is in
  `fields[...]`.
- **Build numbers are single-use.** Rejected build 4 → had to go to 5 → 6.
