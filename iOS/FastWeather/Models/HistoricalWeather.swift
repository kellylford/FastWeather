//
//  HistoricalWeather.swift
//  Fast Weather
//
//  Historical weather data models
//

import Foundation

// Historical weather response from Open-Meteo Archive API
struct HistoricalWeatherResponse: Codable {
    let daily: HistoricalDailyWeather
    
    struct HistoricalDailyWeather: Codable {
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let apparentTemperatureMax: [Double]
        let apparentTemperatureMin: [Double]
        let sunrise: [String]
        let sunset: [String]
        let precipitationSum: [Double]
        let rainSum: [Double]
        let snowfallSum: [Double]
        let precipitationHours: [Double]
        let windSpeed10mMax: [Double]
        
        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weathercode"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case apparentTemperatureMax = "apparent_temperature_max"
            case apparentTemperatureMin = "apparent_temperature_min"
            case sunrise
            case sunset
            case precipitationSum = "precipitation_sum"
            case rainSum = "rain_sum"
            case snowfallSum = "snowfall_sum"
            case precipitationHours = "precipitation_hours"
            case windSpeed10mMax = "windspeed_10m_max"
        }
    }
}

// Single historical day data
struct HistoricalDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    let year: Int
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
    let apparentTempMax: Double
    let apparentTempMin: Double
    let sunrise: String
    let sunset: String
    let precipitationSum: Double
    let rainSum: Double
    let snowfallSum: Double
    let precipitationHours: Double
    let windSpeedMax: Double
    
    init(date: Date, year: Int, weatherCode: Int, tempMax: Double, tempMin: Double,
         apparentTempMax: Double, apparentTempMin: Double, sunrise: String, sunset: String,
         precipitationSum: Double, rainSum: Double, snowfallSum: Double,
         precipitationHours: Double, windSpeedMax: Double) {
        self.id = UUID()
        self.date = date
        self.year = year
        self.weatherCode = weatherCode
        self.tempMax = tempMax
        self.tempMin = tempMin
        self.apparentTempMax = apparentTempMax
        self.apparentTempMin = apparentTempMin
        self.sunrise = sunrise
        self.sunset = sunset
        self.precipitationSum = precipitationSum
        self.rainSum = rainSum
        self.snowfallSum = snowfallSum
        self.precipitationHours = precipitationHours
        self.windSpeedMax = windSpeedMax
    }
    
    var weatherCodeEnum: WeatherCode? {
        WeatherCode(rawValue: weatherCode)
    }
}

// Date selection for historical weather
struct HistoricalDate: Equatable {
    var year: Int
    var month: Int
    var day: Int
    
    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
    
    init(from date: Date) {
        let calendar = Calendar.current
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)
        self.day = calendar.component(.day, from: date)
    }
    
    var dateString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        if let date = toDate() {
            return formatter.string(from: date)
        }
        return dateString
    }
    
    var monthDayKey: String {
        String(format: "%02d-%02d", month, day)
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return String(month)
    }
    
    func toDate() -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
    
    mutating func addDays(_ days: Int) {
        guard let date = toDate() else { return }
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) else { return }
        self = HistoricalDate(from: newDate)
    }
    
    static var today: HistoricalDate {
        HistoricalDate(from: Date())
    }
}
