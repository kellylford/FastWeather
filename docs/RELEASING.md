# Versioning and Releasing

FastWeather is one repository containing three independent apps (Windows, iOS,
Web). Each app has its **own version line** and its **own release tag prefix**,
so a release of one platform never collides with or triggers another.

## Tag convention

Use a platform prefix and a semantic version:

| Platform | Tag format          | Example            |
|----------|---------------------|--------------------|
| Windows  | `windows-v<semver>` | `windows-v3.0.0`   |
| iOS      | `ios-v<semver>`     | `ios-v1.5.8`       |
| Web      | `web-v<semver>`     | `web-v2.0.0`       |

Rules:
- Lowercase `v`, semantic version `MAJOR.MINOR.PATCH`.
- One prefix per platform; never a bare `vX` tag (it's ambiguous in a
  multi-platform repo and would match more than one automation).
- Tags are permanent history — do not delete or move published tags/releases.

### Legacy tags (pre-convention, left as history)

`v1.0`, `v1.1`, `v2WindowsApp`, `V2WebApp`, `v1.2-webapp`, `V1WebApp`,
`V1iOSBLD5`, `V1iOSBLD9`. These predate this convention and are kept as-is.
New releases follow the table above.

## Windows

Source of truth for the version is `windows/fastweather/__init__.py`
(`__version__`). To cut a release:

1. Bump `__version__` (e.g. `3.0.0`) and merge to `main`.
2. Tag and push: `git tag windows-v3.0.0 && git push origin windows-v3.0.0`.

The `windows-release` workflow (triggered by `windows-v*`) verifies the tag
matches `__version__`, runs the tests, builds the PyInstaller exe and the Inno
Setup installer, and publishes a GitHub Release with both assets. The in-app
auto-updater only considers `windows-v*` releases, compares against
`__version__`, and offers the `*-Setup.exe` asset.

The current Windows app is **v3.0.0** — a full rebuild that supersedes the
legacy `v2WindowsApp` build.

## iOS

Released via the `ios-release` workflow (manual `workflow_dispatch` with a build
number) to TestFlight / the App Store; see `.github/workflows/README-ios-release.md`
and `iOS/RELEASING.md`. Mark a shipped version with an `ios-v<marketing_version>`
tag for history. iOS releases are **not** cut by pushing a tag.

## Web

Deployed to weatherfast.online per `webapp/DEPLOYMENT.md`. Mark a shipped
version with a `web-v<semver>` tag for history.
