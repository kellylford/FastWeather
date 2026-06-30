//
//  iCloudSyncService.swift
//  Fast Weather
//
//  Opt-in iCloud Key-Value sync for AppSettings and saved cities.
//  Toggle controlled by UserDefaults key "iCloudSyncEnabled" (bound via @AppStorage in SettingsView).
//  When enabled, pushes local state to iCloud on every save and listens for remote changes.
//

import Foundation

final class iCloudSyncService {
    static let shared = iCloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default

    private static let settingsKey = "icloud_AppSettings"
    private static let citiesKey   = "icloud_SavedCities"
    private static let citiesTimestampKey = "icloud_SavedCities_ts"
    static let enabledKey          = "iCloudSyncEnabled"

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    private init() {}

    // Call once at app launch to register for remote-change notifications.
    func start() {
        let available = store.synchronize()
        AppLogger.persistence.debug("iCloud: start(), synchronize() available=\(available)")
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            self?.storeDidChange(notification)
        }
    }

    // Call when the app returns to foreground to fetch any pending changes from iCloud.
    func synchronize() {
        let available = store.synchronize()
        AppLogger.persistence.debug("iCloud: foreground synchronize(), available=\(available)")
    }

    // Returns true if iCloud already has a saved cities list (downloaded on a previous launch or by another device).
    func hasCloudCities() -> Bool {
        store.data(forKey: Self.citiesKey) != nil
    }

    // Returns true if iCloud already has saved settings.
    func hasCloudSettings() -> Bool {
        store.data(forKey: Self.settingsKey) != nil
    }

    // MARK: - Push (local → iCloud)

    func pushSettings(_ settings: AppSettings) {
        guard isEnabled else { return }
        guard let data = try? JSONEncoder().encode(settings) else { return }
        store.set(data, forKey: Self.settingsKey)
        AppLogger.persistence.debug("iCloud: pushed settings")
    }

    func pushCities(_ cities: [City], modified: Date = Date()) {
        guard isEnabled else { return }
        guard let data = try? JSONEncoder().encode(cities) else { return }
        store.set(data, forKey: Self.citiesKey)
        // Stamp the edit time so receivers can apply last-writer-wins and avoid a stale device
        // clobbering newer data (HI-4).
        store.set(modified.timeIntervalSince1970, forKey: Self.citiesTimestampKey)
        AppLogger.persistence.debug("iCloud: pushed \(cities.count) cities (ts \(modified.timeIntervalSince1970))")
    }

    /// The edit timestamp accompanying the cities currently in iCloud, or nil if none stored.
    func pullCitiesTimestamp() -> Date? {
        let ts = store.double(forKey: Self.citiesTimestampKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    // MARK: - Pull (iCloud → local)

    func pullSettings() -> AppSettings? {
        guard let data = store.data(forKey: Self.settingsKey) else { return nil }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            // Log instead of silently swallowing (L7) so a sync issue is diagnosable.
            AppLogger.persistence.error("iCloud: failed to decode remote settings: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func pullCities() -> [City]? {
        guard let data = store.data(forKey: Self.citiesKey) else { return nil }
        do {
            return try JSONDecoder().decode([City].self, from: data)
        } catch {
            AppLogger.persistence.error("iCloud: failed to decode remote cities: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Remote change handler

    private func storeDidChange(_ notification: Notification) {
        guard isEnabled else { return }
        // Surface KVS quota violations (1 MB total / per-key limit). On overflow the write was
        // silently dropped, so a "my cities didn't sync" report is otherwise undiagnosable (HI-4).
        if let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
           reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            AppLogger.persistence.error("iCloud: KVS quota violation — sync payload exceeds the 1 MB limit; some changes were not saved")
        }
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        if keys.contains(Self.settingsKey) {
            AppLogger.persistence.debug("iCloud: received remote settings change")
            NotificationCenter.default.post(name: .iCloudSettingsDidChangeExternally, object: nil)
        }
        if keys.contains(Self.citiesKey) {
            AppLogger.persistence.debug("iCloud: received remote cities change")
            NotificationCenter.default.post(name: .iCloudCitiesDidChangeExternally, object: nil)
        }
    }
}

extension Notification.Name {
    static let iCloudSettingsDidChangeExternally = Notification.Name("iCloudSettingsDidChangeExternally")
    static let iCloudCitiesDidChangeExternally   = Notification.Name("iCloudCitiesDidChangeExternally")
}
