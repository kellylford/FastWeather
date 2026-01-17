//
//  CityDetailView.swift
//  Fast Weather
//
//  Detailed weather view for a city
//

import SwiftUI

struct CityDetailView: View {
    let city: City
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var settingsManager: SettingsManager
    
    private var weather: WeatherData? {
        weatherService.weatherCache[city.id]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let weather = weather {
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
                    
                    // Current conditions
                    GroupBox(label: Label("Current Conditions", systemImage: "thermometer")) {
                        VStack(spacing: 12) {
                            DetailRow(label: "Humidity", value: "\(weather.current.relativeHumidity2m)%")
                            Divider()
                            DetailRow(label: "Wind Speed", value: formatWindSpeed(weather.current.windSpeed10m))
                            Divider()
                            DetailRow(label: "Wind Direction", value: formatWindDirection(weather.current.windDirection10m))
                            Divider()
                            DetailRow(label: "Pressure", value: formatPressure(weather.current.pressureMsl))
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
                    
                    // Today's forecast
                    if let daily = weather.daily {
                        GroupBox(label: Label("Today's Forecast", systemImage: "calendar")) {
                            VStack(spacing: 12) {
                                if !daily.temperature2mMax.isEmpty {
                                    DetailRow(label: "High", value: formatTemperature(daily.temperature2mMax[0]))
                                    Divider()
                                }
                                if !daily.temperature2mMin.isEmpty {
                                    DetailRow(label: "Low", value: formatTemperature(daily.temperature2mMin[0]))
                                    Divider()
                                }
                                if !daily.sunrise.isEmpty {
                                    DetailRow(label: "Sunrise", value: formatTime(daily.sunrise[0]))
                                    Divider()
                                }
                                if !daily.sunset.isEmpty {
                                    DetailRow(label: "Sunset", value: formatTime(daily.sunset[0]))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        .accessibilityElement(children: .contain)
                    }
                    
                    // Hourly forecast (24 hours)
                    if let hourly = weather.hourly, !hourly.time.isEmpty {
                        GroupBox(label: Label("24-Hour Forecast", systemImage: "clock")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<min(24, hourly.time.count), id: \.self) { index in
                                        HourlyForecastCard(
                                            time: hourly.time[index],
                                            temperature: hourly.temperature2m[index],
                                            weatherCode: hourly.weatherCode[index],
                                            precipitation: hourly.precipitation[index],
                                            settingsManager: settingsManager
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 16-day forecast
                    if let daily = weather.daily, daily.temperature2mMax.count > 1 {
                        GroupBox(label: Label("16-Day Forecast", systemImage: "calendar")) {
                            VStack(spacing: 0) {
                                ForEach(0..<min(16, daily.temperature2mMax.count), id: \.self) { index in
                                    DailyForecastRow(
                                        dayIndex: index,
                                        sunrise: daily.sunrise[index],
                                        high: daily.temperature2mMax[index],
                                        low: daily.temperature2mMin[index],
                                        weatherCode: index < daily.weatherCode.count ? daily.weatherCode[index] : nil,
                                        precipitation: index < daily.precipitationSum.count ? daily.precipitationSum[index] : nil,
                                        settingsManager: settingsManager
                                    )
                                    if index < min(15, daily.temperature2mMax.count - 1) {
                                        Divider()
                                            .padding(.leading)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Location info
                    GroupBox(label: Label("Location", systemImage: "mappin.and.ellipse")) {
                        VStack(spacing: 12) {
                            DetailRow(label: "City", value: city.name)
                            if let state = city.state {
                                Divider()
                                DetailRow(label: "State", value: state)
                            }
                            Divider()
                            DetailRow(label: "Country", value: city.country)
                            Divider()
                            DetailRow(label: "Coordinates", value: String(format: "%.4f, %.4f", city.latitude, city.longitude))
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .contain)
                    
                } else {
                    ProgressView("Loading weather data...")
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(city.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await weatherService.fetchWeather(for: city)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityLabel("Refresh weather")
                }
            }
        }
    }
    
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
    
    private func formatPressure(_ hPa: Double) -> String {
        let pressure = settingsManager.settings.pressureUnit.convert(hPa)
        let formatString = settingsManager.settings.pressureUnit == .hPa ? "%.0f %@" : "%.2f %@"
        return String(format: formatString, pressure, settingsManager.settings.pressureUnit.rawValue)
    }
    
    private func formatVisibility(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        return String(format: "%.1f mi", miles)
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct HourlyForecastCard: View {
    let time: String
    let temperature: Double
    let weatherCode: Int
    let precipitation: Double
    let settingsManager: SettingsManager
    
    private var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: time) else { return "" }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h a"
        return timeFormatter.string(from: date)
    }
    
    private var weatherCodeEnum: WeatherCode? {
        WeatherCode(rawValue: weatherCode)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let weatherCode = weatherCodeEnum {
                Image(systemName: weatherCode.systemImageName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(height: 30)
            }
            
            Text(formatTemperature(temperature))
                .font(.body)
                .fontWeight(.semibold)
            
            if precipitation > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precipitation))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hour")
        .accessibilityValue("\(formattedTime), \(weatherCodeEnum?.description ?? "unknown conditions"), \(formatTemperature(temperature))\(precipitation > 0 ? ", \(formatPrecipitation(precipitation)) precipitation" : "")")
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
}

struct DailyForecastRow: View {
    let dayIndex: Int
    let sunrise: String
    let high: Double
    let low: Double
    let weatherCode: Int?
    let precipitation: Double?
    let settingsManager: SettingsManager
    
    private var dayName: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: sunrise) else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        
        if dayIndex == 0 {
            return "Today, \(dateString)"
        } else if dayIndex == 1 {
            return "Tomorrow, \(dateString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let weekdayName = dayFormatter.string(from: date)
            return "\(weekdayName), \(dateString)"
        }
    }
    
    private var weatherCodeEnum: WeatherCode? {
        if let code = weatherCode {
            return WeatherCode(rawValue: code)
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(.body)
            }
            .frame(width: 140, alignment: .leading)
            
            if let weatherCode = weatherCodeEnum {
                Image(systemName: weatherCode.systemImageName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)
            }
            
            Spacer()
            
            if let precip = precipitation, precip > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatPrecipitation(precip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
            }
            
            HStack(spacing: 8) {
                Text(formatTemperature(low))
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(formatTemperature(high))
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day")
        .accessibilityValue("\(dayName), \(weatherCodeEnum?.description ?? "unknown conditions"), High \(formatTemperature(high)), Low \(formatTemperature(low))\(precipitation != nil && precipitation! > 0 ? ", \(formatPrecipitation(precipitation!)) precipitation" : "")")
    }
    
    private func formatTemperature(_ celsius: Double) -> String {
        let temp = settingsManager.settings.temperatureUnit.convert(celsius)
        return String(format: "%.0f%@", temp, settingsManager.settings.temperatureUnit.rawValue)
    }
    
    private func formatPrecipitation(_ mm: Double) -> String {
        let precip = settingsManager.settings.precipitationUnit.convert(mm)
        return String(format: "%.2f %@", precip, settingsManager.settings.precipitationUnit.rawValue)
    }
}

#Preview {
    NavigationView {
        CityDetailView(
            city: City(name: "Madison", state: "Wisconsin", country: "United States", latitude: 43.074761, longitude: -89.3837613)
        )
        .environmentObject(WeatherService())
        .environmentObject(SettingsManager())
    }
}
