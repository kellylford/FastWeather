# Security Policy

## Supported Versions

| Platform | Supported |
|----------|-----------|
| iOS (latest App Store release) | ✅ |
| Web (weatherfast.online) | ✅ |
| Windows (latest release) | ✅ |

Older versions are not actively patched. Please update to the latest release before reporting.

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Email **kelly@theideaplace.net** with:

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- Which platform(s) are affected (iOS, Web, Windows)
- Your name/handle if you'd like credit

I'll acknowledge receipt within 48 hours and aim to release a fix within 14 days for high-severity issues.

## Scope

In scope:
- FastWeather iOS app (App Store)
- weatherfast.online web app
- FastWeather Windows desktop app
- This repository's source code

Out of scope:
- Open-Meteo API (third-party — report to them directly)
- Apple WeatherKit (third-party — report to Apple)
- Nominatim/OpenStreetMap geocoding (third-party)

## Notes

FastWeather does not collect, transmit, or store personal data on any server. Weather data comes from Open-Meteo. City preferences are stored locally on your device only. There are no user accounts, passwords, or payment flows.
