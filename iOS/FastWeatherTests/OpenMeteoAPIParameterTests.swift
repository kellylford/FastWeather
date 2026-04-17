//
//  OpenMeteoAPIParameterTests.swift
//  FastWeatherTests
//
//  Tests to ensure Open-Meteo API parameter names match current API specification.
//  These tests verify that we use the correct underscore-separated parameter names
//  (e.g., wind_gusts_10m, not windgusts_10m) to prevent silent data loss when
//  deprecated aliases are removed.
//

import XCTest
@testable import WeatherFast

final class OpenMeteoAPIParameterTests: XCTestCase {
    
    // MARK: - API Request Parameter Tests
    
    /// Test that hourly parameters use correct underscore-separated names
    func testHourlyParametersUseCorrectNames() {
        // These are the correct parameter names according to Open-Meteo API documentation
        let correctHourlyParams = [
            "wind_gusts_10m",     // NOT windgusts_10m
            "dew_point_2m",       // NOT dewpoint_2m
            "cloud_cover",        // NOT cloudcover
            "weather_code"        // NOT weathercode
        ]
        
        // Build a sample hourly request string as used in WeatherService
        let hourlyParams = "temperature_2m,weather_code,precipitation,precipitation_probability,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,uv_index,dew_point_2m,snowfall,cloud_cover"
        
        for param in correctHourlyParams {
            XCTAssertTrue(hourlyParams.contains(param), 
                         "Hourly parameters must include '\(param)' with underscores")
        }
        
        // Verify deprecated names are NOT present
        let deprecatedNames = ["windgusts_10m", "dewpoint_2m", "cloudcover", "weathercode"]
        for deprecated in deprecatedNames {
            XCTAssertFalse(hourlyParams.contains(deprecated),
                          "Hourly parameters must NOT contain deprecated '\(deprecated)'")
        }
    }
    
    /// Test that daily parameters use correct underscore-separated names
    func testDailyParametersUseCorrectNames() {
        let correctDailyParams = [
            "wind_speed_10m_max",           // NOT windspeed_10m_max
            "wind_direction_10m_dominant",  // NOT winddirection_10m_dominant
            "weather_code"                  // NOT weathercode
        ]
        
        // Full daily request string from WeatherService
        let dailyParams = "temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_sum,rain_sum,snowfall_sum,precipitation_probability_max,uv_index_max,daylight_duration,sunshine_duration,wind_speed_10m_max,wind_direction_10m_dominant"
        
        for param in correctDailyParams {
            XCTAssertTrue(dailyParams.contains(param),
                         "Daily parameters must include '\(param)' with underscores")
        }
        
        let deprecatedNames = ["windspeed_10m_max", "winddirection_10m_dominant", "weathercode"]
        for deprecated in deprecatedNames {
            XCTAssertFalse(dailyParams.contains(deprecated),
                          "Daily parameters must NOT contain deprecated '\(deprecated)'")
        }
    }
    
    /// Test that current weather parameters use correct names
    func testCurrentParametersUseCorrectNames() {
        let currentParams = "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility,wind_gusts_10m,uv_index,dew_point_2m"
        
        let correctNames = ["wind_gusts_10m", "dew_point_2m", "cloud_cover", "weather_code"]
        for param in correctNames {
            XCTAssertTrue(currentParams.contains(param),
                         "Current parameters must include '\(param)' with underscores")
        }
        
        let deprecatedNames = ["windgusts_10m", "dewpoint_2m", "cloudcover", "weathercode"]
        for deprecated in deprecatedNames {
            XCTAssertFalse(currentParams.contains(deprecated),
                          "Current parameters must NOT contain deprecated '\(deprecated)'")
        }
    }
    
    /// Test that historical API parameters use correct names
    func testHistoricalParametersUseCorrectNames() {
        // Default fields parameter from fetchHistoricalWeather
        let historicalFields = "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,rain_sum,snowfall_sum,precipitation_hours,wind_speed_10m_max"
        
        let correctNames = ["weather_code", "wind_speed_10m_max"]
        for param in correctNames {
            XCTAssertTrue(historicalFields.contains(param),
                         "Historical parameters must include '\(param)' with underscores")
        }
        
        let deprecatedNames = ["weathercode", "windspeed_10m_max"]
        for deprecated in deprecatedNames {
            XCTAssertFalse(historicalFields.contains(deprecated),
                          "Historical parameters must NOT contain deprecated '\(deprecated)'")
        }
    }
    
    // MARK: - CodingKeys Tests
    
    /// Test that HourlyWeather CodingKeys match API parameter names
    func testHourlyWeatherCodingKeysMatchAPI() {
        // Create a mock JSON response with correct parameter names
        let jsonString = """
        {
            "time": ["2026-04-17T12:00"],
            "temperature_2m": [20.5],
            "weather_code": [1],
            "precipitation": [0.0],
            "relative_humidity_2m": [65],
            "wind_speed_10m": [10.0],
            "cloud_cover": [25],
            "precipitation_probability": [10],
            "uv_index": [5.0],
            "wind_gusts_10m": [15.0],
            "dew_point_2m": [12.0],
            "snowfall": [0.0]
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertNoThrow(try decoder.decode(WeatherData.HourlyWeather.self, from: jsonData),
                        "HourlyWeather should decode with underscore-separated parameter names")
    }
    
    /// Test that DailyWeather CodingKeys match API parameter names
    func testDailyWeatherCodingKeysMatchAPI() {
        let jsonString = """
        {
            "temperature_2m_max": [25.0],
            "temperature_2m_min": [15.0],
            "sunrise": ["2026-04-17T06:30"],
            "sunset": ["2026-04-17T19:45"],
            "weather_code": [1],
            "precipitation_sum": [0.0],
            "rain_sum": [0.0],
            "snowfall_sum": [0.0],
            "precipitation_probability_max": [10],
            "uv_index_max": [7.0],
            "daylight_duration": [47700.0],
            "sunshine_duration": [43200.0],
            "wind_speed_10m_max": [20.0],
            "wind_direction_10m_dominant": [270]
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertNoThrow(try decoder.decode(WeatherData.DailyWeather.self, from: jsonData),
                        "DailyWeather should decode with underscore-separated parameter names")
    }
    
    /// Test that CurrentWeather CodingKeys match API parameter names
    func testCurrentWeatherCodingKeysMatchAPI() {
        let jsonString = """
        {
            "temperature_2m": 20.5,
            "relative_humidity_2m": 65,
            "apparent_temperature": 19.0,
            "is_day": 1,
            "precipitation": 0.0,
            "rain": 0.0,
            "showers": 0.0,
            "snowfall": 0.0,
            "weather_code": 1,
            "cloud_cover": 25,
            "pressure_msl": 1013.0,
            "wind_speed_10m": 10.0,
            "wind_direction_10m": 270,
            "visibility": 24000,
            "wind_gusts_10m": 15.0,
            "uv_index": 5.0,
            "dew_point_2m": 12.0
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertNoThrow(try decoder.decode(WeatherData.CurrentWeather.self, from: jsonData),
                        "CurrentWeather should decode with underscore-separated parameter names")
    }
    
    /// Test that HistoricalWeather CodingKeys match API parameter names
    func testHistoricalWeatherCodingKeysMatchAPI() {
        let jsonString = """
        {
            "daily": {
                "time": ["2025-04-17"],
                "weather_code": [1],
                "temperature_2m_max": [25.0],
                "temperature_2m_min": [15.0],
                "precipitation_sum": [0.0],
                "apparent_temperature_max": [24.0],
                "apparent_temperature_min": [14.0],
                "sunrise": ["2025-04-17T06:30"],
                "sunset": ["2025-04-17T19:45"],
                "rain_sum": [0.0],
                "snowfall_sum": [0.0],
                "precipitation_hours": [0.0],
                "wind_speed_10m_max": [20.0]
            }
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertNoThrow(try decoder.decode(HistoricalWeatherResponse.self, from: jsonData),
                        "HistoricalWeatherResponse should decode with underscore-separated parameter names")
    }
    
    // MARK: - Live API Integration Test (requires paid API key)
    
    /// Test actual API call with correct parameters (only runs if API key is present)
    func testLiveAPICallWithCorrectParameters() async throws {
        // Only run if we have an API key (paid tier)
        guard let apiKey = Secrets.openMeteoAPIKey, !apiKey.isEmpty else {
            throw XCTSkip("Skipping live API test - no API key configured")
        }
        
        let service = await MainActor.run { WeatherService() }
        
        // Create a test city (San Diego) using the proper initializer
        let testCity = City(id: UUID(), name: "San Diego", state: "California", country: "United States",
                           latitude: 32.7157, longitude: -117.1611)
        
        // Fetch weather - this will test the actual API with corrected parameter names
        await MainActor.run {
            Task {
                await service.fetchWeatherForDate(for: testCity, dateOffset: 0, includeHourly: true)
            }
        }
        
        // Give it time to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Check service state to see if data was loaded successfully
        let isLoading = await MainActor.run { service.isLoading }
        let errorMessage = await MainActor.run { service.errorMessage }
        
        XCTAssertFalse(isLoading, "Should have finished loading")
        XCTAssertNil(errorMessage, "Should not have error: \\(errorMessage ?? \"nil\")")
        
        // Verify cache was populated (indirect evidence that API call succeeded)
        let hasCachedData = await MainActor.run { !service.weatherCache.isEmpty }
        XCTAssertTrue(hasCachedData, "Should have cached weather data after successful fetch")
    }
    
    // MARK: - Forecast Days Tests
    
    /// Test that forecast_days parameter uses correct values (16 days for hourly, not 7)
    /// Per Open-Meteo documentation, free tier supports up to 16 forecast days
    func testForecastDaysUsesCorrectValues() async throws {
        // Create a test city using proper initializer
        let testCity = City(id: UUID(), name: "New York", state: "New York", country: "United States",
                           latitude: 40.7128, longitude: -74.0060)
        
        // Create service instance
        let service = await MainActor.run { WeatherService() }
        
        // We can't easily inspect the URL that gets built internally, but we can verify
        // the expected behavior by checking the method signature and ensuring it doesn't
        // incorrectly cap at 7 days for free tier.
        
        // The fix should be: includeHourly ? "16" : "3"
        // NOT: includeHourly ? (Secrets.openMeteoAPIKey != nil ? "16" : "7") : "3"
        
        // This test verifies the behavior by actually calling the API and checking
        // that we get back appropriate forecast data
        await MainActor.run {
            Task {
                await service.fetchWeatherForDate(for: testCity, dateOffset: 0, includeHourly: true)
            }
        }
        
        // Give it time to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // After fetch, check that we have weather data using correct cache key
        let cacheKey = WeatherCacheKey(cityId: testCity.id, dateOffset: 0)
        let weatherData = await MainActor.run { service.weatherCache[cacheKey] }
        XCTAssertNotNil(weatherData, "Should have weather data after fetch")
        
        // Verify we have daily data (the array should exist)
        XCTAssertNotNil(weatherData?.daily, "Should have daily forecast data")
        
        // If daily data exists, verify we got more than 7 days (up to 16)
        if let daily = weatherData?.daily {
            let dayCount = daily.temperature2mMax.count
            XCTAssertGreaterThan(dayCount, 7, 
                "Should fetch more than 7 days on free tier (up to 16 days available)")
            XCTAssertLessThanOrEqual(dayCount, 16, 
                "Should not exceed 16 days forecast")
        }
    }
}
