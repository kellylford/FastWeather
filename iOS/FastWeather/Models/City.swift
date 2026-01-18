//
//  City.swift
//  Fast Weather
//
//  Model for city data
//

import Foundation

struct City: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let state: String?
    let country: String
    let latitude: Double
    let longitude: Double
    
    var displayName: String {
        if let state = state, !state.isEmpty {
            // For US cities, show City, State format (without country)
            if country == "United States" || country == "USA" {
                return "\(name), \(state)"
            }
            return "\(name), \(state), \(country)"
        }
        // For international cities without state, just show City, Country
        if country == "United States" || country == "USA" {
            return name
        }
        return "\(name), \(country)"
    }
    
    init(id: UUID = UUID(), name: String, state: String? = nil, country: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}

// City cache data structure for browsing
struct CityLocation: Codable, Hashable {
    let name: String
    let state: String?
    let country: String
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case name
        case state
        case country
        case latitude = "lat"
        case longitude = "lon"
    }
    
    var displayName: String {
        if let state = state, !state.isEmpty {
            return "\(name), \(state)"
        }
        return name
    }
    
    var cacheKey: String {
        "\(latitude),\(longitude)"
    }
    
    func toCity() -> City {
        City(name: name, state: state, country: country, latitude: latitude, longitude: longitude)
    }
}
