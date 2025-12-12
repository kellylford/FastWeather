//
//  CityManager.swift
//  FastWeatherMac
//
//  Created on 12/12/2025.
//  Manages city list and persistence
//

import Foundation

class CityManager: ObservableObject {
    @Published var cities: [City] = []
    
    private let citiesKey = "savedCities"
    private let defaultCities: [City] = [
        City(name: "Madison", displayName: "Madison, Wisconsin, United States", latitude: 43.074761, longitude: -89.3837613, state: "Wisconsin", country: "United States"),
        City(name: "San Diego", displayName: "San Diego, California, United States", latitude: 32.7174202, longitude: -117.162772, state: "California", country: "United States"),
        City(name: "Portland", displayName: "Portland, Oregon, United States", latitude: 45.5202471, longitude: -122.674194, state: "Oregon", country: "United States"),
        City(name: "London", displayName: "London, England, United Kingdom", latitude: 51.5074456, longitude: -0.1277653, state: "England", country: "United Kingdom"),
        City(name: "Miami", displayName: "Miami, Florida, United States", latitude: 25.7741728, longitude: -80.19362, state: "Florida", country: "United States")
    ]
    
    init() {
        loadCities()
    }
    
    func loadCities() {
        if let data = UserDefaults.standard.data(forKey: citiesKey),
           let decoded = try? JSONDecoder().decode([City].self, from: data) {
            cities = decoded
        } else {
            cities = defaultCities
            saveCities()
        }
    }
    
    func saveCities() {
        if let encoded = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(encoded, forKey: citiesKey)
        }
    }
    
    func addCity(_ city: City) {
        cities.append(city)
        saveCities()
    }
    
    func removeCity(_ city: City) {
        cities.removeAll { $0.id == city.id }
        saveCities()
    }
    
    func moveCity(from source: IndexSet, to destination: Int) {
        cities.move(fromOffsets: source, toOffset: destination)
        saveCities()
    }
    
    func clearAllCities() {
        cities.removeAll()
        saveCities()
    }
}
