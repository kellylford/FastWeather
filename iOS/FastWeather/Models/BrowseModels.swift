//
//  BrowseModels.swift
//  Fast Weather
//
//  Shared models for city-browse features (state/country browsing, favorites)
//

import Foundation

// Sort options available when browsing cities by state or country
enum BrowseSortOrder: String, CaseIterable, Identifiable, Codable {
    case nameAZ     = "Name (A–Z)"
    case nameZA     = "Name (Z–A)"
    case northSouth = "North to South"
    case southNorth = "South to North"
    case eastWest   = "East to West"
    case westEast   = "West to East"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nameAZ:     return "textformat.abc"
        case .nameZA:     return "textformat.abc"
        case .northSouth: return "arrow.down"
        case .southNorth: return "arrow.up"
        case .eastWest:   return "arrow.right"
        case .westEast:   return "arrow.left"
        }
    }
}
