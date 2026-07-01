# WeatherFast — Test Plan (branch `code-review-fixes`)

Step-by-step tests for everything changed on this branch, plus general regression checks. Written for a VoiceOver-first workflow: each test says what to do and **what to listen for**. Check the box when it passes.

**Legend:** 🔊 = VoiceOver-specific behavior to verify · 💵 = touches paid-API cost · ⚠️ = safety-relevant.

---

## 0. Setup & how to build

```bash
# From repo root, build + install to a connected iPhone (wireless can be flaky — retry install once if it drops):
xcodebuild -project iOS/FastWeather.xcodeproj -scheme FastWeather -configuration Debug \
  -sdk iphoneos -destination generic/platform=iOS \
  -derivedDataPath /tmp/FastWeatherDeviceBuild -allowProvisioningUpdates build

xcrun devicectl device install app --device <DEVICE_ID> \
  /tmp/FastWeatherDeviceBuild/Build/Products/Debug-iphoneos/WeatherFast.app
```
Get `<DEVICE_ID>` from `xcrun devicectl list devices` (the physical one).

**This build installs over your existing app** (same bundle id), so your real saved cities/settings carry over — good for the persistence tests below.

**Test data you'll want:** at least one **US** city (for NWS alerts, e.g. a city where a real alert might exist, or just any US city), one **far-away-timezone** city (e.g. Tokyo or Sydney — for moon/time tests), and a couple of others.

---

## 1. Settings persistence (CR-1, CR-2)

### 1.1 — Settings survive an app restart 🔊
- [ ] Settings → change **Temperature unit** (e.g. to Fahrenheit) and toggle a couple of "City List View" fields.
- [ ] Force-quit the app, reopen.
- [ ] **Expected:** all your changes are still there. Nothing reset to defaults.
  *(CR-1: the settings-version gate no longer silently discards saved settings.)*

### 1.2 — "My Data" custom parameters actually appear (CR-2) 💵
- [ ] Settings → **My Data** configuration → add a parameter you don't normally see (e.g. **Soil Temperature**, **CAPE**, or **Dew Point**).
- [ ] Open a saved city's detail and find the **My Data** section.
- [ ] **Expected:** the parameter you added shows a real value (not blank/missing).
  *(CR-2: My Data reads now come from the App Group suite; before, on a fresh install they silently read stale/empty settings and dropped these.)*

---

## 2. Weather display correctness (Product review #3, #5; HI-8)

### 2.1 — Future/past days show forecast High/Low, not a fake "current" ⚠️🔊  **(Product #3)**
- [ ] My Cities. Use the date control (or swipe) to move to **tomorrow** (or any future day).
- [ ] Open a city's detail.
- [ ] **Expected (visual):** the big number reads **"High ___"** with a smaller **"Low ___"** underneath — NOT a single number labeled "Current temperature."
- [ ] 🔊 **Expected (VoiceOver):** the hero reads as **"Forecast high ___, low ___"** — it must NOT say "Current temperature" for a non-today day.
- [ ] **Expected:** in the Current Conditions area there is **no "Cloud Cover 0%"** row on future/past days, and **no "Feels like"** line.
- [ ] Now go back to **today** and open a city.
- [ ] **Expected:** today still shows the real **"Current temperature"** (72pt) and, if available, "Feels like" and "Cloud Cover" as before. *(Regression check — today's behavior is unchanged.)*

### 2.2 — Moon times use the city's timezone 🔊  **(Product #5)**
- [ ] Open a city in a **far-away timezone** (e.g. Tokyo, Sydney).
- [ ] Find the **Astronomy** section → Moonrise / Moonset.
- [ ] **Expected:** moon times are in the **city's local time**, consistent with the **Sunrise/Sunset** shown in the same section (before, moon times were in *your device's* timezone — e.g. hours off for Tokyo).
- [ ] Sanity check: sunrise and moonrise should both look like that city's local clock, not yours.

### 2.3 — Hourly forecast doesn't show stale/past hours (HI-8)
- [ ] This is an edge case (only triggers when cached hourly data is fully in the past). Best-effort: open a city, view the **24-Hour Forecast**, confirm the first hour shown is **now-ish or later**, not early this morning.
- [ ] **Expected:** no obviously-past hours presented as upcoming. *(Hard to force manually; mainly a safety net.)*

---

## 3. Severe-weather alerts honesty (Product review #1) ⚠️🔊

This is the most important behavioral change and the one new VoiceOver state to confirm.

### 3.1 — Normal case: no alerts
- [ ] Open a US city with no active alerts.
- [ ] 🔊 **Expected:** Weather Alerts section reads **"No active alerts."**

### 3.2 — Failure case: "Couldn't check" instead of false "all clear" ⚠️🔊
- [ ] Put the phone in **Airplane Mode** (or otherwise kill network).
- [ ] Open a **US** city you haven't opened recently (so it isn't cached), scroll to **Weather Alerts**.
- [ ] **Expected (visual):** it shows **"Couldn't check for alerts"** with a **"Try Again"** button — NOT "No active alerts."
- [ ] 🔊 **Expected (VoiceOver):** you hear "Couldn't check for alerts" and a **"Try Again" button** with the hint "Retries checking for weather alerts."
- [ ] Turn network back on, activate **Try Again**.
- [ ] **Expected:** it re-checks and resolves to either real alerts or "No active alerts."
- [ ] ⚠️ **The key point:** a failed check must never read as "No active alerts." Confirm those two states are clearly different.

### 3.3 — Real alert still works (if you can find one)
- [ ] If a US city currently has a live NWS alert, open it.
- [ ] 🔊 **Expected:** the alert is listed, reads as "<severity> alert: <event>", double-tap opens details. *(Regression check.)*

---

## 4. iCloud sync (HI-4 + PR-feedback #1/#2) — needs 2 devices or a reinstall ⚠️

Only relevant if you use iCloud sync. These are the trickiest changes; skip if you don't rely on cross-device sync.

### 4.1 — Basic sync still works
- [ ] On device A: Settings → enable **Sync with iCloud** (push your list up).
- [ ] On device B (same Apple ID): enable sync, choose **"Use iCloud List"** when prompted.
- [ ] **Expected:** device B shows device A's cities.

### 4.2 — Newer edit wins; stale device doesn't clobber ⚠️
- [ ] On device A: add a distinctive city (e.g. "Reykjavík"). Wait a few seconds for it to sync.
- [ ] On device B: confirm it appears.
- [ ] **Expected:** the more-recent edit propagates; you should **not** see a city you just added disappear. *(HI-4 last-writer-wins by timestamp.)*

### 4.3 — Explicit choice is honored (PR-feedback #2) ⚠️
- [ ] With cities in iCloud and different cities locally, toggle sync and pick **"Use iCloud List"**.
- [ ] **Expected:** you get the **iCloud** list (your explicit choice is honored, not silently overridden by local). Then pick **"Keep My List"** in the other direction on the other device and confirm that's honored too.
- [ ] **Expected:** whichever list you explicitly choose is the one that sticks.

---

## 5. Browse Cities sort — VoiceOver selected state (VO-4) 🔊

- [ ] Browse Cities → drill into a **state** or **country** list.
- [ ] Activate the **Sort** button → swipe through the sort options (Name A–Z, North to South, Temperature High–Low, etc.).
- [ ] 🔊 **Expected:** the **currently-active** sort option is announced as **"selected"** (e.g. "North to South, selected"). Before, VoiceOver gave no indication which one was active.
- [ ] Pick a different sort, reopen the menu, confirm the new one now reads "selected."

---

## 6. Cost / caching (HI-1, HI-6, marine) 💵 — mostly invisible, spot-check only

These reduce redundant paid API calls; behavior should look **identical**, just cheaper. Only worth a light sanity pass:
- [ ] Open **Weather Around Me** for a city, back out, reopen it a few times quickly. **Expected:** loads correctly each time, conditions match the rest of the app (WeatherKit condition overlay preserved). *(HI-1 caches the condition by coordinate — no visible change, fewer calls.)*
- [ ] Swipe across several future days for a city and back. **Expected:** data loads normally. *(HI-6 offset-aware cache.)*
- [ ] Open a coastal city's **Marine** data, remove that city, confirm no crash / weirdness. *(Marine cache cleanup.)*

---

## 7. Crash-safety (CR-3) — covered by tests; hard to trigger manually

CR-3 makes the daily/hourly forecast rendering safe against short/partial API responses (previously could crash). This is hard to force by hand (the API rarely returns short arrays). It's covered by unit tests (`SafeArrayAccessTests`). Manual best-effort:
- [ ] Open several cities' **16-Day Forecast** and tap into individual **day** detail screens across different cities/countries. **Expected:** no crashes navigating any day. *(Especially international cities and far-future days.)*

---

## 8. General regression / smoke pass

Quick "did we break anything" sweep:
- [ ] App launches; My Cities list loads with weather for all saved cities.
- [ ] Add a city (search) and remove a city — both work, no crash.
- [ ] Open a city detail: current conditions, hourly, 16-day, astronomy all render.
- [ ] Historical Weather opens and loads for a city.
- [ ] Expected Precipitation (radar) sheet opens and reads correctly. 🔊 Confirm the "now / 5 / 10 … 60 min" precipitation points are navigable (unchanged — this was verified good previously).
- [ ] Settings screens all open; Developer Settings toggles work.
- [ ] 🔊 General VoiceOver sweep of My Cities and one city detail — labels read sensibly, buttons have hints, nothing reads as raw/garbled.

---

## What is NOT in this build (tracked separately)

So you don't test for things that aren't done yet:
- **Background/push severe-weather alerts** — not implemented; alerts are checked only when you open a city. (Issue #78.)
- **Directional "nearest precipitation"** honesty relabel — deferred. (Issue #79.)
- **WeatherKit/Open-Meteo** condition consistency + `.blizzard`/`.hurricane` mapping — deferred. (Issue #80.)
- **Radar plain-text intensity summary** — deferred. (Issue #81.)
- **Large hero temperature Dynamic Type scaling** — deferred. (Issue #76.)

---

## Reporting results

For anything that fails, note: which test number, what you did, what VoiceOver said (or what you saw), and what you expected. The alert "Couldn't check" state (3.2) and the future-day High/Low (2.1) are the two most important new behaviors to confirm by VoiceOver.
