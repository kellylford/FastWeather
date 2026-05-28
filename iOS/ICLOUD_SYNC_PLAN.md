# iCloud Settings & City Sync — Implementation Plan

## Goal

Sync `AppSettings` and `savedCities` across all of a user's devices using iCloud. When a user changes their temperature unit on iPhone, it should appear on their iPad automatically.

## Recommended Approach: NSUbiquitousKeyValueStore

Use **iCloud Key-Value Storage** (`NSUbiquitousKeyValueStore`), not CloudKit or SwiftData. Reasons:

- `AppSettings` is already a `Codable` struct with JSON encoding — maps directly to a KV entry
- `savedCities` is already JSON-encoded in UserDefaults — same pattern
- No user sign-in flow needed (uses existing Apple ID, silently ignored if not signed in)
- No server schema, no containers, no merge policies to define
- Syncs within seconds on the same account
- Limit: 1 MB total / 1024 keys — comfortably fits settings + city list

> **Not recommended:** SwiftData + iCloud or CloudKit. Both add significant complexity for data that is already JSON-serializable and small in size.

---

## What Gets Synced

| Data | Current Storage | Will Also Sync To |
|------|----------------|-------------------|
| `AppSettings` | `UserDefaults(suiteName:)` key `"AppSettings"` | iCloud KV key `"icloud_AppSettings"` |
| `savedCities` ([City]) | `UserDefaults(suiteName:)` key `"SavedCities"` | iCloud KV key `"icloud_SavedCities"` |
| `FeatureFlags` | `UserDefaults.standard` | **Not synced** — developer/device-specific |
| `BrowseFavorites` | `UserDefaults` | **Optional** — low value, defer |

---

## Prerequisite Steps (Done in Xcode Before Writing Code)

1. In Xcode, select the **FastWeather** target → Signing & Capabilities → **+ Capability** → add **iCloud**.
2. Under the iCloud capability, check **Key-value storage**. Xcode creates the entitlement automatically.
3. Do the same for the **FastWeatherWidget** target if you ever want widget-side reads (optional).
4. There is no App Store Connect setup required for KV storage — it uses your existing bundle ID.
5. Test with a physical device (iCloud KV doesn't work in Simulator reliably).

---

## Architecture

### New file: `Services/iCloudSyncService.swift`

```swift
import Foundation

final class iCloudSyncService {
    static let shared = iCloudSyncService()
    private let store = NSUbiquitousKeyValueStore.default

    private let settingsKey = "icloud_AppSettings"
    private let citiesKey   = "icloud_SavedCities"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    func start() {
        store.synchronize()
    }

    // MARK: - Write (local → iCloud)

    func pushSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        store.set(data, forKey: settingsKey)
    }

    func pushCities(_ cities: [City]) {
        guard let data = try? JSONEncoder().encode(cities) else { return }
        store.set(data, forKey: citiesKey)
    }

    // MARK: - Read (iCloud → local)

    func pullSettings() -> AppSettings? {
        guard let data = store.data(forKey: settingsKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    func pullCities() -> [City]? {
        guard let data = store.data(forKey: citiesKey) else { return nil }
        return try? JSONDecoder().decode([City].self, from: data)
    }

    // MARK: - Remote change notification

    @objc private func storeDidChange(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        if keys.contains(settingsKey) {
            NotificationCenter.default.post(name: .iCloudSettingsChanged, object: nil)
        }
        if keys.contains(citiesKey) {
            NotificationCenter.default.post(name: .iCloudCitiesChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let iCloudSettingsChanged = Notification.Name("iCloudSettingsChanged")
    static let iCloudCitiesChanged   = Notification.Name("iCloudCitiesChanged")
}
```

---

## Changes to Existing Files

### `SettingsManager.swift`

1. In `saveSettings()`, after writing to `sharedDefaults`, also call:
   ```swift
   iCloudSyncService.shared.pushSettings(settings)
   ```

2. In `init()`, after loading from `sharedDefaults`, check if iCloud has a newer copy. Use the `settingsVersion` field and a stored timestamp to decide which wins (see conflict resolution below).

3. Observe `Notification.Name.iCloudSettingsChanged` and reload settings when it fires:
   ```swift
   NotificationCenter.default.addObserver(
       forName: .iCloudSettingsChanged, object: nil, queue: .main
   ) { [weak self] _ in
       if let remote = iCloudSyncService.shared.pullSettings() {
           self?.settings = remote
           // Do NOT call saveSettings() here — avoid a write loop
           Self.sharedDefaults.set(try? JSONEncoder().encode(remote), forKey: Self.userDefaultsKey)
       }
   }
   ```

### `WeatherService.swift`

1. In `saveCities()` (wherever `savedCities` is persisted), also push to iCloud:
   ```swift
   iCloudSyncService.shared.pushCities(savedCities)
   ```

2. Observe `Notification.Name.iCloudCitiesChanged` and reload:
   ```swift
   NotificationCenter.default.addObserver(
       forName: .iCloudCitiesChanged, object: nil, queue: .main
   ) { [weak self] _ in
       if let remoteCities = iCloudSyncService.shared.pullCities() {
           self?.savedCities = remoteCities
       }
   }
   ```

### `WeatherFastApp.swift`

Call `iCloudSyncService.shared.start()` in the app's `init()` or `onAppear` on the root view. This triggers the initial `synchronize()` call.

---

## Conflict Resolution

NSUbiquitousKeyValueStore uses **last-write-wins** automatically — whichever device wrote most recently wins. For settings this is almost always fine. For `savedCities` there is a risk of one device's city list overwriting another's.

**Simple approach (recommended to start):** last-write-wins. If both devices are active, the last settings change or city add/remove wins.

**Safer approach for cities (defer until users report issues):** Store a `modifiedAt: Date` timestamp alongside the city list. On receiving `iCloudCitiesChanged`, compare the remote timestamp to the local `lastCityModification` timestamp and only apply if remote is newer.

---

## Settings Version Compatibility

`AppSettings.currentVersion` is currently `3`. When you bump this in the future, the existing version-mismatch wipe logic in `SettingsManager.init()` will already handle it locally. Add the same guard before applying an iCloud-pulled `AppSettings`:

```swift
if let remote = iCloudSyncService.shared.pullSettings(),
   remote.settingsVersion == AppSettings.currentVersion {
    // safe to apply
}
```

This prevents an older device running an older app version from corrupting a newer device's settings.

---

## User-Facing Considerations

- **No opt-in UI required** for launch — sync happens silently if the user is signed in to iCloud. If they are not, it gracefully does nothing.
- **Optional:** Add a "Sync with iCloud" toggle in Settings if you later want to let power users disable it. Keep it off the critical path for v1.
- **Privacy:** Only settings and city names/coordinates sync — no weather data, no location history, no personal identifiers beyond city names they chose.

---

## Testing

1. Install on two devices with the same Apple ID.
2. Change temperature unit on Device A — verify it appears on Device B within ~10 seconds.
3. Add a city on Device A — verify it appears on Device B.
4. Sign out of iCloud on Device B — verify local settings are unaffected.
5. Sign back in — verify Device B pulls the latest settings from Device A.
6. Test with airplane mode: changes queue and sync when connectivity returns.

---

## Estimated Effort

| Phase | Work |
|-------|------|
| Xcode capability setup | 15 min |
| `iCloudSyncService.swift` | 2–3 hours |
| Wire into `SettingsManager` | 1 hour |
| Wire into `WeatherService` | 1 hour |
| Testing (two devices required) | 3–5 hours |
| **Total** | **~1.5 days** |
