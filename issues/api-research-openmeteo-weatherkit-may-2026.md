# Research Summary: Open-Meteo & Apple WeatherKit (May 2026)

---

## Open-Meteo

**Nothing broke.** The `/v1/forecast` endpoint, all current parameters, and JSON response format are unchanged and stable.

**Notable new capabilities:**

| Change | Date | Relevance to FastWeather |
|---|---|---|
| **ECMWF accuracy upgrade** — IFS HRES went from 28 km → 9 km resolution globally | Oct 2025 | Automatic if already using `models=auto` (the default). Free accuracy improvement with no code changes needed. |
| **New weather models** — UK Met Office (2–10 km, hourly updates) and ECMWF AIFS (AI-based, 15-day range) | Feb 2025 | Could expose model selection to power users, or use UKMO for better UK accuracy. |
| **`forecast_hours` / `past_hours` params** | Ongoing | More granular time range control; alternative to `forecast_days` for sub-day customization. |
| **Seasonal Forecast API** — 9-month outlooks, 51 ensemble members | Nov 2025 | Likely too specialized for FastWeather's use case. |
| **Single Runs API** — archived historical model runs | May 2025 | Standard plan does not include this; requires Professional tier. Not relevant. |

---

## Apple WeatherKit (iOS 18 / macOS 15)

**Important constraint:** FastWeather iOS currently targets **iOS 17.0**. All new WeatherKit types require **iOS 18.0+**. Any adoption requires bumping the minimum deployment target.

**Current WeatherKit usage in FastWeather:**
- International weather alerts (behind `weatherKitAlertsEnabled` feature flag) — fetches `.alerts` only
- Snow totals overlay (behind `weatherKitSnowEnabled` dev flag) — replaces Open-Meteo `snowfall_sum` only

The new iOS 18 features require fetching WeatherKit's full weather forecast, not just alerts or a single field. They do not slot into the current architecture without significant changes.

**Notable new capabilities:**

| New Type | What It Does | Relevance |
|---|---|---|
| **`DayPartForecast`** | Separate daytime vs. overnight conditions — temps, precip chance, wind, visibility per half-day | Requires WeatherKit as a co-primary data source. Not currently feasible. |
| **`WeatherChanges`** | Proactively surfaces significant upcoming weather shifts (e.g., "significant temperature drop tomorrow") | Same constraint. |
| **`CloudCoverByAltitude`** | Low/mid/high cloud fractions on both current conditions and day-part forecasts | Same constraint. |
| **`PrecipitationAmountByType`** + **`SnowfallAmount`** | Splits precipitation into rain/snow/sleet amounts | Could extend the existing snow overlay at some point. Minor improvement. |
| **Historical comparison types** | "5°F warmer than average for this date" statistics | Significant additional scope. |

**iOS 26 note:** Apple rebranded iOS 19 → iOS 26 (latest is iOS 26.5, released May 11, 2026). WWDC 2026 WeatherKit additions not yet publicly documented.

---

## Open-Meteo Subscription Clarification

The $30/month Standard plan does **not** include Historical Weather API, Single Runs API, Ensemble API, Climate API, or Satellite Radiation API. Those require the Professional plan (€99/month).

| API | What it answers | Plan required |
|---|---|---|
| **Historical Weather API** | What did the weather actually do on a past date? (ERA5 reanalysis) | Professional |
| **Single Runs API** | What did a specific model forecast when it ran at a given time? | Professional |

The Historical Weather API would be the more user-facing feature (past conditions lookup). Single Runs API is a research/data science tool with no clear consumer weather app use case.

---

## Decision: No Action at This Time

Neither data source requires changes. Revisit in approximately one month, after WWDC 2026 announcements.
