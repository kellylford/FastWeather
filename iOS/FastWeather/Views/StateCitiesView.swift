//
//  StateCitiesView.swift
//  Weather Fast
//
//  View for displaying cities in a specific US state
//

import SwiftUI

struct StateCitiesView: View {
    let state: String
    @ObservedObject var cityDataService: CityDataService
    @EnvironmentObject var weatherService: WeatherService
    @State private var searchText = ""
    
    private var cities: [CityLocation] {
        cityDataService.cities(forState: state)
    }
    
    private var filteredCities: [CityLocation] {
        if searchText.isEmpty {
            return cities
        }
        return cities.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            ForEach(filteredCities, id: \.self) { cityLocation in
                NavigationLink(destination: CityLocationDetailView(cityLocation: cityLocation)) {
                    CityLocationRow(cityLocation: cityLocation)
                }
            }
        }
        .navigationTitle(state)
        .searchable(text: $searchText, prompt: "Search cities in \(state)")
        .accessibilityElement(children: .contain)
    }
}

struct CountryCitiesView: View {
    let country: String
    @ObservedObject var cityDataService: CityDataService
    @EnvironmentObject var weatherService: WeatherService
    @State private var searchText = ""
    
    private var cities: [CityLocation] {
        cityDataService.cities(forCountry: country)
    }
    
    private var filteredCities: [CityLocation] {
        if searchText.isEmpty {
            return cities
        }
        return cities.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            ForEach(filteredCities, id: \.self) { cityLocation in
                NavigationLink(destination: CityLocationDetailView(cityLocation: cityLocation)) {
                    CityLocationRow(cityLocation: cityLocation)
                }
            }
        }
        .navigationTitle(country)
        .searchable(text: $searchText, prompt: "Search cities in \(country)")
        .accessibilityElement(children: .contain)
    }
}

struct CityLocationRow: View {
    let cityLocation: CityLocation
    @EnvironmentObject var weatherService: WeatherService
    @State private var weatherData: WeatherData?
    @State private var isLoadingWeather = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(cityLocation.displayName)
                    .font(.body)
                
                if isLoadingWeather {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading weather...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let weatherData = weatherData {
                    HStack(spacing: 8) {
                        if let weatherCode = weatherData.current.weatherCodeEnum {
                            Image(systemName: weatherCode.systemImageName)
                                .foregroundColor(.blue)
                        }
                        Text(String(format: "%.0f°", weatherData.current.temperature2m))
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let weatherCode = weatherData.current.weatherCodeEnum {
                            Text(weatherCode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Tap to view details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .onAppear {
            if weatherData == nil {
                loadWeather()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weatherAccessibilityLabel)
        .accessibilityAction(named: "Add to My Cities") {
            addCity()
        }
    }
    
    private var weatherAccessibilityLabel: String {
        var label = cityLocation.displayName
        if let weatherData = weatherData {
            let temp = String(format: "%.0f degrees", weatherData.current.temperature2m)
            let desc = weatherData.current.weatherCodeEnum?.description ?? "unknown conditions"
            label += ", \(temp), \(desc)"
        } else if isLoadingWeather {
            label += ", loading weather"
        }
        return label
    }
    
    private func loadWeather() {
        guard !isLoadingWeather else { return }
        isLoadingWeather = true
        
        Task {
            do {
                let fetchedWeather = try await weatherService.fetchWeather(
                    latitude: cityLocation.latitude,
                    longitude: cityLocation.longitude
                )
                await MainActor.run {
                    weatherData = fetchedWeather
                    isLoadingWeather = false
                }
            } catch {
                await MainActor.run {
                    isLoadingWeather = false
                }
            }
        }
    }
    
    private func addCity() {
        let city = cityLocation.toCity()
        weatherService.addCity(city)
        
        // Announce to VoiceOver
        UIAccessibility.post(notification: .announcement, argument: "\(cityLocation.displayName) added to My Cities")
    }
}

// Detail view for a city from browsing (not yet added)
struct CityLocationDetailView: View {
    let cityLocation: CityLocation
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var weatherData: WeatherData?
    @State private var isLoadingWeather = true
    
    private var isAlreadyAdded: Bool {
        weatherService.savedCities.contains { city in
            city.latitude == cityLocation.latitude &&
            city.longitude == cityLocation.longitude
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoadingWeather {
                    ProgressView("Loading weather data...")
                        .padding()
                } else if let weather = weatherData {
                    // Main weather display
                    VStack(spacing: 16) {
                        // Temperature and condition
                        if let weatherCode = weather.current.weatherCodeEnum {
                            Image(systemName: weatherCode.systemImageName)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                            
                            Text(weatherCode.description)
                                .font(.title2)
                                .accessibilityLabel("Conditions: \(weatherCode.description)")
                        }
                        
                        Text(formatTemperature(weather.current.temperature2m))
                            .font(.system(size: 72, weight: .bold))
                            .accessibilityLabel("Temperature \(formatTemperature(weather.current.temperature2m))")
                        
                        Text("Feels like \(formatTemperature(weather.current.apparentTemperature))")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Add/Remove button
                    Button(action: toggleCity) {
                        Label(isAlreadyAdded ? "Remove from My Cities" : "Add to My Cities",
                              systemImage: isAlreadyAdded ? "minus.circle.fill" : "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isAlreadyAdded ? Color.red : Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .accessibilityLabel(isAlreadyAdded ? "Remove from My Cities" : "Add to My Cities")
                    
                    // Current conditions
                    GroupBox(label: Label("Current Conditions", systemImage: "thermometer")) {
                        VStack(spacing: 12) {
                            DetailRow(label: "Humidity", value: "\(weather.current.relativeHumidity2m)%")
                            Divider()
                            DetailRow(label: "Wind Speed", value: formatWindSpeed(weather.current.windSpeed10m))
                            Divider()
                            DetailRow(label: "Wind Direction", value: formatWindDirection(weather.current.windDirection10m))
                            Divider()
                            DetailRow(label: "Pressure", value: String(format: "%.1f hPa", weather.current.pressureMsl))
                            Divider()
                            DetailRow(label: "Visibility", value: formatVisibility(weather.current.visibility))
                            Divider()
                            DetailRow(label: "Cloud Cover", value: "\(weather.current.cloudCover)%")
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .contain)
                    
                    // Precipitation
                    GroupBox(label: Label("Precipitation", systemImage: "cloud.rain")) {
                        VStack(spacing: 12) {
                            DetailRow(label: "Total", value: formatPrecipitation(weather.current.precipitation))
                            Divider()
                            DetailRow(label: "Rain", value: formatPrecipitation(weather.current.rain))
                            Divider()
                            DetailRow(label: "Showers", value: formatPrecipitation(weather.current.showers))
                            Divider()
                            DetailRow(label: "Snowfall", value: formatPrecipitation(weather.current.snowfall))
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .contain)
                    
                    // Daily info
                    if let daily = weather.daily {
                        GroupBox(label: Label("Today", systemImage: "calendar")) {
                            VStack(spacing: 12) {
                                DetailRow(label: "High", value: formatTemperature(daily.temperature2mMax[0]))
                                Divider()
                                DetailRow(label: "Low", value: formatTemperature(daily.temperature2mMin[0]))
                                Divider()
                                DetailRow(label: "Sunrise", value: formatTime(daily.sunrise[0]))
                                Divider()
                                DetailRow(label: "Sunset", value: formatTime(daily.sunset[0]))
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        .accessibilityElement(children: .contain)
                    }
                } else {
                    Text("Unable to load weather data")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(cityLocation.displayName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadWeather()
        }
    }
    
    private func loadWeather() {
        isLoadingWeather = true
        Task {
            do {
                let fetchedWeather = try await weatherService.fetchWeather(
                    latitude: cityLocation.latitude,
                    longitude: cityLocation.longitude
                )
                await MainActor.run {
                    weatherData = fetchedWeather
                    isLoadingWeather = false
                }
            } catch {
                await MainActor.run {
                    isLoadingWeather = false
                }
            }
        }
    }
    
    private func toggleCity() {
        if isAlreadyAdded {
            // Find and remove the city
            if let existingCity = weatherService.savedCities.first(where: { city in
                city.latitude == cityLocation.latitude && city.longitude == cityLocation.longitude
            }) {
                weatherService.removeCity(existingCity)
                UIAccessibility.post(notification: .announcement, argument: "\(cityLocation.displayName) removed from My Cities")
            }
        } else {
            let city = cityLocation.toCity()
            weatherService.addCity(city)
            UIAccessibility.post(notification: .announcement, argument: "\(cityLocation.displayName) added to My Cities")
        }
    }
    
    // Formatting helpers
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatWindSpeed(_ kmh: Double) -> String {
        let speed = settingsManager.settings.windSpeedUnit.convert(kmh)
        return String(format: "%.1f %@", speed, settingsManager.settings.windSpeedUnit.rawValue)
    }
    
    private func formatWindDirection(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) / 45.0).rounded()) % 8
        return "\(directions[index]) (\(degrees)°)"
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        return String(format: "%.1f mi", miles)
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

#Preview {
    StateCitiesView(state: "California", cityDataService: CityDataService())
        .environmentObject(WeatherService())
}
