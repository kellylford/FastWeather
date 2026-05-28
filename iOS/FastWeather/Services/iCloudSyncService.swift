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

    func pushCities(_ cities: [City]) {
        guard isEnabled else { return }
        guard let data = try? JSONEncoder().encode(cities) else { return }
        store.set(data, forKey: Self.citiesKey)
        AppLogger.persistence.debug("iCloud: pushed \(cities.count) cities")
    }

    // MARK: - Pull (iCloud → local)

    func pullSettings() -> AppSettings? {
        guard let data = store.data(forKey: Self.settingsKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    func pullCities() -> [City]? {
        guard let data = store.data(forKey: Self.citiesKey) else { return nil }
        return try? JSONDecoder().decode([City].self, from: data)
    }

    // MARK: - Remote change handler

    private func storeDidChange(_ notification: Notification) {
        guard isEnabled else { return }
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
