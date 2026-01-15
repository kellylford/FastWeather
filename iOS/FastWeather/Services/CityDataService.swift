//
//  CityDataService.swift
//  FastWeather
//
//  Service for browsing cities by state and country
//

import Foundation

class CityDataService: ObservableObject {
    @Published var usCitiesByState: [String: [CityLocation]] = [:]
    @Published var internationalCitiesByCountry: [String: [CityLocation]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init() {
        loadCityData()
    }
    
    private func loadCityData() {
        // Load US cities
        if let url = Bundle.main.url(forResource: "us-cities-cached", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([String: [CityLocation]].self, from: data)
                usCitiesByState = decoded
                print("✅ Loaded \(usCitiesByState.keys.count) US states")
            } catch {
                print("❌ Error loading US cities: \(error)")
                errorMessage = "Failed to load US cities: \(error.localizedDescription)"
            }
        } else {
            print("❌ Could not find us-cities-cached.json in bundle")
            errorMessage = "Could not find US cities data file"
        }
        
        // Load international cities
        if let url = Bundle.main.url(forResource: "international-cities-cached", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([String: [CityLocation]].self, from: data)
                internationalCitiesByCountry = decoded
                print("✅ Loaded \(internationalCitiesByCountry.keys.count) countries")
            } catch {
                print("❌ Error loading international cities: \(error)")
                errorMessage = "Failed to load international cities: \(error.localizedDescription)"
            }
        } else {
            print("❌ Could not find international-cities-cached.json in bundle")
            errorMessage = "Could not find international cities data file"
        }
    }
    
    var usStates: [String] {
        usCitiesByState.keys.sorted()
    }
    
    var countries: [String] {
        internationalCitiesByCountry.keys.sorted()
    }
    
    func cities(forState state: String) -> [CityLocation] {
        usCitiesByState[state] ?? []
    }
    
    func cities(forCountry country: String) -> [CityLocation] {
        internationalCitiesByCountry[country] ?? []
    }
}
