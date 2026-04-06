//
//  BrowseFavoritesService.swift
//  Fast Weather
//
//  Persistence and CRUD for browse destination favorites
//

import Foundation

@MainActor
class BrowseFavoritesService: ObservableObject {
    @Published var favorites: [BrowseFavorite] = []

    private let userDefaultsKey = "BrowseFavorites"

    init() {
        load()
    }

    func add(name: String, regionType: BrowseRegionType, sortOrder: BrowseSortOrder) {
        guard !isFavorite(name: name, regionType: regionType) else { return }
        let favorite = BrowseFavorite(regionType: regionType, name: name, sortOrder: sortOrder)
        favorites.append(favorite)
        save()
    }

    func remove(name: String, regionType: BrowseRegionType) {
        favorites.removeAll { $0.name == name && $0.regionType == regionType }
        save()
    }

    func isFavorite(name: String, regionType: BrowseRegionType) -> Bool {
        favorites.contains { $0.name == name && $0.regionType == regionType }
    }

    func favorite(for name: String, regionType: BrowseRegionType) -> BrowseFavorite? {
        favorites.first { $0.name == name && $0.regionType == regionType }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([BrowseFavorite].self, from: data) else {
            return
        }
        favorites = decoded
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
