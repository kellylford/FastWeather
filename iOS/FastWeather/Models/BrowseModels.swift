//
//  BrowseModels.swift
//  Fast Weather
//
//  Shared models for city-browse features (state/country browsing, favorites)
//

import Foundation

// Sort options available when browsing cities by state or country
enum BrowseSortOrder: String, CaseIterable, Identifiable, Codable {
    case nameAZ      = "Name (A–Z)"
    case nameZA      = "Name (Z–A)"
    case northSouth  = "North to South"
    case southNorth  = "South to North"
    case eastWest    = "East to West"
    case westEast    = "West to East"
    case tempHighLow = "Temperature (High to Low)"
    case tempLowHigh = "Temperature (Low to High)"

    var id: String { rawValue }

    /// User-facing, localized label. The `rawValue` is a stable storage key — never display it.
    var localizedLabel: String {
        switch self {
        case .nameAZ:      String(localized: "sort.name_az", defaultValue: "Name (A–Z)", comment: "City sort order")
        case .nameZA:      String(localized: "sort.name_za", defaultValue: "Name (Z–A)", comment: "City sort order")
        case .northSouth:  String(localized: "sort.north_south", defaultValue: "North to South", comment: "City sort order (by latitude)")
        case .southNorth:  String(localized: "sort.south_north", defaultValue: "South to North", comment: "City sort order (by latitude)")
        case .eastWest:    String(localized: "sort.east_west", defaultValue: "East to West", comment: "City sort order (by longitude)")
        case .westEast:    String(localized: "sort.west_east", defaultValue: "West to East", comment: "City sort order (by longitude)")
        case .tempHighLow: String(localized: "sort.temp_high_low", defaultValue: "Temperature (High to Low)", comment: "City sort order")
        case .tempLowHigh: String(localized: "sort.temp_low_high", defaultValue: "Temperature (Low to High)", comment: "City sort order")
        }
    }

    var systemImage: String {
        switch self {
        case .nameAZ:      return "textformat.abc"
        case .nameZA:      return "textformat.abc"
        case .northSouth:  return "arrow.down"
        case .southNorth:  return "arrow.up"
        case .eastWest:    return "arrow.right"
        case .westEast:    return "arrow.left"
        case .tempHighLow: return "thermometer.high"
        case .tempLowHigh: return "thermometer.low"
        }
    }
}
