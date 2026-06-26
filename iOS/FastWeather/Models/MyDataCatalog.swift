//
//  MyDataCatalog.swift
//  Fast Weather
//
//  Catalog of all Open-Meteo current-condition parameters available
//  for the user-configurable "My Data" section.
//

import Foundation

// MARK: - Categories for organizing data points

enum MyDataCategory: String, CaseIterable, Codable {
    case temperature = "Temperature"
    case humidity = "Humidity & Moisture"
    case wind = "Wind"
    case precipitation = "Precipitation"
    case pressure = "Pressure"
    case clouds = "Clouds & Visibility"
    case solar = "Solar & UV"
    case soil = "Soil"
    case atmosphere = "Atmosphere"
    case marine = "Marine & Ocean"
    case airQuality = "Air Quality"
    
    var displayName: String {
        switch self {
        case .temperature: return String(localized: "mydata.category.temperature.name", defaultValue: "Temperature", comment: "My Data category name")
        case .humidity: return String(localized: "mydata.category.humidity.name", defaultValue: "Humidity & Moisture", comment: "My Data category name")
        case .wind: return String(localized: "mydata.category.wind.name", defaultValue: "Wind", comment: "My Data category name")
        case .precipitation: return String(localized: "mydata.category.precipitation.name", defaultValue: "Precipitation", comment: "My Data category name")
        case .pressure: return String(localized: "mydata.category.pressure.name", defaultValue: "Pressure", comment: "My Data category name")
        case .clouds: return String(localized: "mydata.category.clouds.name", defaultValue: "Clouds & Visibility", comment: "My Data category name")
        case .solar: return String(localized: "mydata.category.solar.name", defaultValue: "Solar & UV", comment: "My Data category name")
        case .soil: return String(localized: "mydata.category.soil.name", defaultValue: "Soil", comment: "My Data category name")
        case .atmosphere: return String(localized: "mydata.category.atmosphere.name", defaultValue: "Atmosphere", comment: "My Data category name")
        case .marine: return String(localized: "mydata.category.marine.name", defaultValue: "Marine & Ocean", comment: "My Data category name")
        case .airQuality: return String(localized: "mydata.category.airQuality.name", defaultValue: "Air Quality", comment: "My Data category name")
        }
    }
}

// MARK: - All available Open-Meteo current-condition parameters

enum MyDataParameter: String, CaseIterable, Codable, Equatable, Hashable {
    // Temperature
    case temperature2m
    case apparentTemperature
    case temperature80m
    case temperature120m
    case temperature180m
    
    // Humidity & Moisture
    case relativeHumidity2m
    case dewPoint2m
    case vapourPressureDeficit
    
    // Wind
    case windSpeed10m
    case windSpeed80m
    case windSpeed120m
    case windSpeed180m
    case windDirection10m
    case windDirection80m
    case windDirection120m
    case windDirection180m
    case windGusts10m
    
    // Precipitation
    case precipitation
    case rain
    case showers
    case snowfall
    case snowDepth
    case freezingLevelHeight
    
    // Pressure
    case pressureMsl
    case surfacePressure
    
    // Clouds & Visibility
    case cloudCover
    case cloudCoverLow
    case cloudCoverMid
    case cloudCoverHigh
    case visibility
    case weatherCode
    case isDay
    
    // Solar & UV
    case uvIndex
    case shortwaveRadiation
    case directRadiation
    case directNormalIrradiance
    case diffuseRadiation
    case sunshineDuration
    
    // Soil
    case soilTemperature0cm
    case soilTemperature6cm
    case soilTemperature18cm
    case soilTemperature54cm
    case soilMoisture0to1cm
    case soilMoisture1to3cm
    case soilMoisture3to9cm
    case soilMoisture9to27cm
    case soilMoisture27to81cm
    
    // Atmosphere
    case cape
    case evapotranspiration
    case et0FaoEvapotranspiration
    
    // Marine & Ocean
    case waveHeight
    case waveDirection
    case wavePeriod
    case wavePeakPeriod
    case windWaveHeight
    case windWaveDirection
    case windWavePeriod
    case windWavePeakPeriod
    case swellWaveHeight
    case swellWaveDirection
    case swellWavePeriod
    case swellWavePeakPeriod
    case secondarySwellWaveHeight
    case secondarySwellWaveDirection
    case secondarySwellWavePeriod
    case tertiarySwellWaveHeight
    case tertiarySwellWaveDirection
    case tertiarySwellWavePeriod
    case oceanCurrentVelocity
    case oceanCurrentDirection
    case seaSurfaceTemperature
    case seaLevelHeightMsl
    
    // Air Quality
    case pm10
    case pm25
    case carbonMonoxide
    case nitrogenDioxide
    case sulphurDioxide
    case ozone
    case aerosolOpticalDepth
    case dust
    case uvIndexAirQuality
    case uvIndexClearSky
    case ammonia
    case carbonDioxide
    case methane
    case europeanAqi
    case usAqi
    case alderPollen
    case birchPollen
    case grassPollen
    case mugwortPollen
    case olivePollen
    case ragweedPollen
    
    // MARK: - Properties
    
    var displayName: String {
        switch self {
        case .temperature2m: return String(localized: "mydata.temperature2m.name", defaultValue: "Temperature (2m)", comment: "My Data parameter name")
        case .apparentTemperature: return String(localized: "mydata.apparentTemperature.name", defaultValue: "Feels Like", comment: "My Data parameter name")
        case .temperature80m: return String(localized: "mydata.temperature80m.name", defaultValue: "Temperature (80m)", comment: "My Data parameter name")
        case .temperature120m: return String(localized: "mydata.temperature120m.name", defaultValue: "Temperature (120m)", comment: "My Data parameter name")
        case .temperature180m: return String(localized: "mydata.temperature180m.name", defaultValue: "Temperature (180m)", comment: "My Data parameter name")
        case .relativeHumidity2m: return String(localized: "mydata.relativeHumidity2m.name", defaultValue: "Relative Humidity", comment: "My Data parameter name")
        case .dewPoint2m: return String(localized: "mydata.dewPoint2m.name", defaultValue: "Dew Point", comment: "My Data parameter name")
        case .vapourPressureDeficit: return String(localized: "mydata.vapourPressureDeficit.name", defaultValue: "Vapour Pressure Deficit", comment: "My Data parameter name")
        case .windSpeed10m: return String(localized: "mydata.windSpeed10m.name", defaultValue: "Wind Speed (10m)", comment: "My Data parameter name")
        case .windSpeed80m: return String(localized: "mydata.windSpeed80m.name", defaultValue: "Wind Speed (80m)", comment: "My Data parameter name")
        case .windSpeed120m: return String(localized: "mydata.windSpeed120m.name", defaultValue: "Wind Speed (120m)", comment: "My Data parameter name")
        case .windSpeed180m: return String(localized: "mydata.windSpeed180m.name", defaultValue: "Wind Speed (180m)", comment: "My Data parameter name")
        case .windDirection10m: return String(localized: "mydata.windDirection10m.name", defaultValue: "Wind Direction (10m)", comment: "My Data parameter name")
        case .windDirection80m: return String(localized: "mydata.windDirection80m.name", defaultValue: "Wind Direction (80m)", comment: "My Data parameter name")
        case .windDirection120m: return String(localized: "mydata.windDirection120m.name", defaultValue: "Wind Direction (120m)", comment: "My Data parameter name")
        case .windDirection180m: return String(localized: "mydata.windDirection180m.name", defaultValue: "Wind Direction (180m)", comment: "My Data parameter name")
        case .windGusts10m: return String(localized: "mydata.windGusts10m.name", defaultValue: "Wind Gusts", comment: "My Data parameter name")
        case .precipitation: return String(localized: "mydata.precipitation.name", defaultValue: "Precipitation", comment: "My Data parameter name")
        case .rain: return String(localized: "mydata.rain.name", defaultValue: "Rain", comment: "My Data parameter name")
        case .showers: return String(localized: "mydata.showers.name", defaultValue: "Showers", comment: "My Data parameter name")
        case .snowfall: return String(localized: "mydata.snowfall.name", defaultValue: "Snowfall", comment: "My Data parameter name")
        case .snowDepth: return String(localized: "mydata.snowDepth.name", defaultValue: "Snow Depth", comment: "My Data parameter name")
        case .freezingLevelHeight: return String(localized: "mydata.freezingLevelHeight.name", defaultValue: "Freezing Level", comment: "My Data parameter name")
        case .pressureMsl: return String(localized: "mydata.pressureMsl.name", defaultValue: "Sea Level Pressure", comment: "My Data parameter name")
        case .surfacePressure: return String(localized: "mydata.surfacePressure.name", defaultValue: "Surface Pressure", comment: "My Data parameter name")
        case .cloudCover: return String(localized: "mydata.cloudCover.name", defaultValue: "Cloud Cover", comment: "My Data parameter name")
        case .cloudCoverLow: return String(localized: "mydata.cloudCoverLow.name", defaultValue: "Low Clouds", comment: "My Data parameter name")
        case .cloudCoverMid: return String(localized: "mydata.cloudCoverMid.name", defaultValue: "Mid-Level Clouds", comment: "My Data parameter name")
        case .cloudCoverHigh: return String(localized: "mydata.cloudCoverHigh.name", defaultValue: "High Clouds", comment: "My Data parameter name")
        case .visibility: return String(localized: "mydata.visibility.name", defaultValue: "Visibility", comment: "My Data parameter name")
        case .weatherCode: return String(localized: "mydata.weatherCode.name", defaultValue: "Weather Code", comment: "My Data parameter name")
        case .isDay: return String(localized: "mydata.isDay.name", defaultValue: "Day or Night", comment: "My Data parameter name")
        case .uvIndex: return String(localized: "mydata.uvIndex.name", defaultValue: "UV Index", comment: "My Data parameter name")
        case .shortwaveRadiation: return String(localized: "mydata.shortwaveRadiation.name", defaultValue: "Solar Radiation", comment: "My Data parameter name")
        case .directRadiation: return String(localized: "mydata.directRadiation.name", defaultValue: "Direct Radiation", comment: "My Data parameter name")
        case .directNormalIrradiance: return String(localized: "mydata.directNormalIrradiance.name", defaultValue: "Direct Normal Irradiance", comment: "My Data parameter name")
        case .diffuseRadiation: return String(localized: "mydata.diffuseRadiation.name", defaultValue: "Diffuse Radiation", comment: "My Data parameter name")
        case .sunshineDuration: return String(localized: "mydata.sunshineDuration.name", defaultValue: "Sunshine Duration", comment: "My Data parameter name")
        case .soilTemperature0cm: return String(localized: "mydata.soilTemperature0cm.name", defaultValue: "Surface Soil Temp", comment: "My Data parameter name")
        case .soilTemperature6cm: return String(localized: "mydata.soilTemperature6cm.name", defaultValue: "Soil Temp (6 cm)", comment: "My Data parameter name")
        case .soilTemperature18cm: return String(localized: "mydata.soilTemperature18cm.name", defaultValue: "Soil Temp (18 cm)", comment: "My Data parameter name")
        case .soilTemperature54cm: return String(localized: "mydata.soilTemperature54cm.name", defaultValue: "Soil Temp (54 cm)", comment: "My Data parameter name")
        case .soilMoisture0to1cm: return String(localized: "mydata.soilMoisture0to1cm.name", defaultValue: "Soil Moisture (0–1 cm)", comment: "My Data parameter name")
        case .soilMoisture1to3cm: return String(localized: "mydata.soilMoisture1to3cm.name", defaultValue: "Soil Moisture (1–3 cm)", comment: "My Data parameter name")
        case .soilMoisture3to9cm: return String(localized: "mydata.soilMoisture3to9cm.name", defaultValue: "Soil Moisture (3–9 cm)", comment: "My Data parameter name")
        case .soilMoisture9to27cm: return String(localized: "mydata.soilMoisture9to27cm.name", defaultValue: "Soil Moisture (9–27 cm)", comment: "My Data parameter name")
        case .soilMoisture27to81cm: return String(localized: "mydata.soilMoisture27to81cm.name", defaultValue: "Soil Moisture (27–81 cm)", comment: "My Data parameter name")
        case .cape: return String(localized: "mydata.cape.name", defaultValue: "CAPE", comment: "My Data parameter name")
        case .evapotranspiration: return String(localized: "mydata.evapotranspiration.name", defaultValue: "Evapotranspiration", comment: "My Data parameter name")
        case .et0FaoEvapotranspiration: return String(localized: "mydata.et0FaoEvapotranspiration.name", defaultValue: "Reference Evapotranspiration", comment: "My Data parameter name")
        case .waveHeight: return String(localized: "mydata.waveHeight.name", defaultValue: "Wave Height", comment: "My Data parameter name")
        case .waveDirection: return String(localized: "mydata.waveDirection.name", defaultValue: "Wave Direction", comment: "My Data parameter name")
        case .wavePeriod: return String(localized: "mydata.wavePeriod.name", defaultValue: "Wave Period", comment: "My Data parameter name")
        case .wavePeakPeriod: return String(localized: "mydata.wavePeakPeriod.name", defaultValue: "Wave Peak Period", comment: "My Data parameter name")
        case .windWaveHeight: return String(localized: "mydata.windWaveHeight.name", defaultValue: "Wind Wave Height", comment: "My Data parameter name")
        case .windWaveDirection: return String(localized: "mydata.windWaveDirection.name", defaultValue: "Wind Wave Direction", comment: "My Data parameter name")
        case .windWavePeriod: return String(localized: "mydata.windWavePeriod.name", defaultValue: "Wind Wave Period", comment: "My Data parameter name")
        case .windWavePeakPeriod: return String(localized: "mydata.windWavePeakPeriod.name", defaultValue: "Wind Wave Peak Period", comment: "My Data parameter name")
        case .swellWaveHeight: return String(localized: "mydata.swellWaveHeight.name", defaultValue: "Swell Wave Height", comment: "My Data parameter name")
        case .swellWaveDirection: return String(localized: "mydata.swellWaveDirection.name", defaultValue: "Swell Wave Direction", comment: "My Data parameter name")
        case .swellWavePeriod: return String(localized: "mydata.swellWavePeriod.name", defaultValue: "Swell Wave Period", comment: "My Data parameter name")
        case .swellWavePeakPeriod: return String(localized: "mydata.swellWavePeakPeriod.name", defaultValue: "Swell Wave Peak Period", comment: "My Data parameter name")
        case .secondarySwellWaveHeight: return String(localized: "mydata.secondarySwellWaveHeight.name", defaultValue: "Secondary Swell Height", comment: "My Data parameter name")
        case .secondarySwellWaveDirection: return String(localized: "mydata.secondarySwellWaveDirection.name", defaultValue: "Secondary Swell Direction", comment: "My Data parameter name")
        case .secondarySwellWavePeriod: return String(localized: "mydata.secondarySwellWavePeriod.name", defaultValue: "Secondary Swell Period", comment: "My Data parameter name")
        case .tertiarySwellWaveHeight: return String(localized: "mydata.tertiarySwellWaveHeight.name", defaultValue: "Tertiary Swell Height", comment: "My Data parameter name")
        case .tertiarySwellWaveDirection: return String(localized: "mydata.tertiarySwellWaveDirection.name", defaultValue: "Tertiary Swell Direction", comment: "My Data parameter name")
        case .tertiarySwellWavePeriod: return String(localized: "mydata.tertiarySwellWavePeriod.name", defaultValue: "Tertiary Swell Period", comment: "My Data parameter name")
        case .oceanCurrentVelocity: return String(localized: "mydata.oceanCurrentVelocity.name", defaultValue: "Ocean Current Speed", comment: "My Data parameter name")
        case .oceanCurrentDirection: return String(localized: "mydata.oceanCurrentDirection.name", defaultValue: "Ocean Current Direction", comment: "My Data parameter name")
        case .seaSurfaceTemperature: return String(localized: "mydata.seaSurfaceTemperature.name", defaultValue: "Sea Surface Temperature", comment: "My Data parameter name")
        case .seaLevelHeightMsl: return String(localized: "mydata.seaLevelHeightMsl.name", defaultValue: "Sea Level Height", comment: "My Data parameter name")
        case .pm10: return String(localized: "mydata.pm10.name", defaultValue: "PM10 Particulates", comment: "My Data parameter name")
        case .pm25: return String(localized: "mydata.pm25.name", defaultValue: "PM2.5 Particulates", comment: "My Data parameter name")
        case .carbonMonoxide: return String(localized: "mydata.carbonMonoxide.name", defaultValue: "Carbon Monoxide (CO)", comment: "My Data parameter name")
        case .nitrogenDioxide: return String(localized: "mydata.nitrogenDioxide.name", defaultValue: "Nitrogen Dioxide (NO₂)", comment: "My Data parameter name")
        case .sulphurDioxide: return String(localized: "mydata.sulphurDioxide.name", defaultValue: "Sulphur Dioxide (SO₂)", comment: "My Data parameter name")
        case .ozone: return String(localized: "mydata.ozone.name", defaultValue: "Ozone (O₃)", comment: "My Data parameter name")
        case .aerosolOpticalDepth: return String(localized: "mydata.aerosolOpticalDepth.name", defaultValue: "Aerosol Optical Depth", comment: "My Data parameter name")
        case .dust: return String(localized: "mydata.dust.name", defaultValue: "Dust", comment: "My Data parameter name")
        case .uvIndexAirQuality: return String(localized: "mydata.uvIndexAirQuality.name", defaultValue: "UV Index", comment: "My Data parameter name")
        case .uvIndexClearSky: return String(localized: "mydata.uvIndexClearSky.name", defaultValue: "UV Index (Clear Sky)", comment: "My Data parameter name")
        case .ammonia: return String(localized: "mydata.ammonia.name", defaultValue: "Ammonia (NH₃)", comment: "My Data parameter name")
        case .carbonDioxide: return String(localized: "mydata.carbonDioxide.name", defaultValue: "Carbon Dioxide (CO₂)", comment: "My Data parameter name")
        case .methane: return String(localized: "mydata.methane.name", defaultValue: "Methane (CH₄)", comment: "My Data parameter name")
        case .europeanAqi: return String(localized: "mydata.europeanAqi.name", defaultValue: "European Air Quality Index", comment: "My Data parameter name")
        case .usAqi: return String(localized: "mydata.usAqi.name", defaultValue: "US Air Quality Index", comment: "My Data parameter name")
        case .alderPollen: return String(localized: "mydata.alderPollen.name", defaultValue: "Alder Pollen", comment: "My Data parameter name")
        case .birchPollen: return String(localized: "mydata.birchPollen.name", defaultValue: "Birch Pollen", comment: "My Data parameter name")
        case .grassPollen: return String(localized: "mydata.grassPollen.name", defaultValue: "Grass Pollen", comment: "My Data parameter name")
        case .mugwortPollen: return String(localized: "mydata.mugwortPollen.name", defaultValue: "Mugwort Pollen", comment: "My Data parameter name")
        case .olivePollen: return String(localized: "mydata.olivePollen.name", defaultValue: "Olive Pollen", comment: "My Data parameter name")
        case .ragweedPollen: return String(localized: "mydata.ragweedPollen.name", defaultValue: "Ragweed Pollen", comment: "My Data parameter name")
        }
    }
    
    var explanation: String {
        switch self {
        case .temperature2m: return String(localized: "mydata.temperature2m.desc", defaultValue: "Air temperature at 2 meters above ground level", comment: "My Data parameter explanation")
        case .apparentTemperature: return String(localized: "mydata.apparentTemperature.desc", defaultValue: "Perceived temperature combining wind chill, humidity, and solar radiation", comment: "My Data parameter explanation")
        case .temperature80m: return String(localized: "mydata.temperature80m.desc", defaultValue: "Air temperature at 80 meters, useful for wind turbine operations", comment: "My Data parameter explanation")
        case .temperature120m: return String(localized: "mydata.temperature120m.desc", defaultValue: "Air temperature at 120 meters above ground", comment: "My Data parameter explanation")
        case .temperature180m: return String(localized: "mydata.temperature180m.desc", defaultValue: "Air temperature at 180 meters above ground", comment: "My Data parameter explanation")
        case .relativeHumidity2m: return String(localized: "mydata.relativeHumidity2m.desc", defaultValue: "Percentage of moisture in the air relative to saturation", comment: "My Data parameter explanation")
        case .dewPoint2m: return String(localized: "mydata.dewPoint2m.desc", defaultValue: "Temperature at which air becomes saturated and dew forms", comment: "My Data parameter explanation")
        case .vapourPressureDeficit: return String(localized: "mydata.vapourPressureDeficit.desc", defaultValue: "Difference between moisture in air and moisture at saturation, important for plant health", comment: "My Data parameter explanation")
        case .windSpeed10m: return String(localized: "mydata.windSpeed10m.desc", defaultValue: "Wind speed at standard 10-meter measurement height", comment: "My Data parameter explanation")
        case .windSpeed80m: return String(localized: "mydata.windSpeed80m.desc", defaultValue: "Wind speed at 80 meters, relevant for wind energy", comment: "My Data parameter explanation")
        case .windSpeed120m: return String(localized: "mydata.windSpeed120m.desc", defaultValue: "Wind speed at 120 meters above ground", comment: "My Data parameter explanation")
        case .windSpeed180m: return String(localized: "mydata.windSpeed180m.desc", defaultValue: "Wind speed at 180 meters above ground", comment: "My Data parameter explanation")
        case .windDirection10m: return String(localized: "mydata.windDirection10m.desc", defaultValue: "Direction wind is blowing from at 10 meters, in degrees", comment: "My Data parameter explanation")
        case .windDirection80m: return String(localized: "mydata.windDirection80m.desc", defaultValue: "Wind direction at 80 meters above ground", comment: "My Data parameter explanation")
        case .windDirection120m: return String(localized: "mydata.windDirection120m.desc", defaultValue: "Wind direction at 120 meters above ground", comment: "My Data parameter explanation")
        case .windDirection180m: return String(localized: "mydata.windDirection180m.desc", defaultValue: "Wind direction at 180 meters above ground", comment: "My Data parameter explanation")
        case .windGusts10m: return String(localized: "mydata.windGusts10m.desc", defaultValue: "Maximum wind gust speed in the preceding hour at 10 meters", comment: "My Data parameter explanation")
        case .precipitation: return String(localized: "mydata.precipitation.desc", defaultValue: "Total precipitation including rain, showers, and snow in the preceding hour", comment: "My Data parameter explanation")
        case .rain: return String(localized: "mydata.rain.desc", defaultValue: "Rainfall from large-scale weather systems in the preceding hour", comment: "My Data parameter explanation")
        case .showers: return String(localized: "mydata.showers.desc", defaultValue: "Convective precipitation from localized showers in the preceding hour", comment: "My Data parameter explanation")
        case .snowfall: return String(localized: "mydata.snowfall.desc", defaultValue: "Snowfall amount in the preceding hour", comment: "My Data parameter explanation")
        case .snowDepth: return String(localized: "mydata.snowDepth.desc", defaultValue: "Current snow depth on the ground", comment: "My Data parameter explanation")
        case .freezingLevelHeight: return String(localized: "mydata.freezingLevelHeight.desc", defaultValue: "Altitude where temperature reaches 0°C", comment: "My Data parameter explanation")
        case .pressureMsl: return String(localized: "mydata.pressureMsl.desc", defaultValue: "Atmospheric pressure adjusted to sea level", comment: "My Data parameter explanation")
        case .surfacePressure: return String(localized: "mydata.surfacePressure.desc", defaultValue: "Atmospheric pressure at the actual ground surface", comment: "My Data parameter explanation")
        case .cloudCover: return String(localized: "mydata.cloudCover.desc", defaultValue: "Total cloud cover as a percentage of sky", comment: "My Data parameter explanation")
        case .cloudCoverLow: return String(localized: "mydata.cloudCoverLow.desc", defaultValue: "Low-level clouds and fog up to 3 km altitude", comment: "My Data parameter explanation")
        case .cloudCoverMid: return String(localized: "mydata.cloudCoverMid.desc", defaultValue: "Mid-level clouds between 3 and 8 km altitude", comment: "My Data parameter explanation")
        case .cloudCoverHigh: return String(localized: "mydata.cloudCoverHigh.desc", defaultValue: "High-level clouds above 8 km altitude", comment: "My Data parameter explanation")
        case .visibility: return String(localized: "mydata.visibility.desc", defaultValue: "Maximum viewing distance through the atmosphere", comment: "My Data parameter explanation")
        case .weatherCode: return String(localized: "mydata.weatherCode.desc", defaultValue: "WMO weather interpretation code describing current conditions", comment: "My Data parameter explanation")
        case .isDay: return String(localized: "mydata.isDay.desc", defaultValue: "Whether the current time is during daylight hours", comment: "My Data parameter explanation")
        case .uvIndex: return String(localized: "mydata.uvIndex.desc", defaultValue: "Ultraviolet radiation index indicating sunburn risk", comment: "My Data parameter explanation")
        case .shortwaveRadiation: return String(localized: "mydata.shortwaveRadiation.desc", defaultValue: "Total incoming solar radiation on a horizontal surface", comment: "My Data parameter explanation")
        case .directRadiation: return String(localized: "mydata.directRadiation.desc", defaultValue: "Solar radiation arriving directly from the sun on a horizontal plane", comment: "My Data parameter explanation")
        case .directNormalIrradiance: return String(localized: "mydata.directNormalIrradiance.desc", defaultValue: "Solar radiation measured perpendicular to the sun's rays", comment: "My Data parameter explanation")
        case .diffuseRadiation: return String(localized: "mydata.diffuseRadiation.desc", defaultValue: "Solar radiation scattered by the atmosphere", comment: "My Data parameter explanation")
        case .sunshineDuration: return String(localized: "mydata.sunshineDuration.desc", defaultValue: "Duration of direct sunlight in the preceding hour", comment: "My Data parameter explanation")
        case .soilTemperature0cm: return String(localized: "mydata.soilTemperature0cm.desc", defaultValue: "Temperature at the soil surface", comment: "My Data parameter explanation")
        case .soilTemperature6cm: return String(localized: "mydata.soilTemperature6cm.desc", defaultValue: "Soil temperature at 6 cm depth", comment: "My Data parameter explanation")
        case .soilTemperature18cm: return String(localized: "mydata.soilTemperature18cm.desc", defaultValue: "Soil temperature at 18 cm depth", comment: "My Data parameter explanation")
        case .soilTemperature54cm: return String(localized: "mydata.soilTemperature54cm.desc", defaultValue: "Soil temperature at 54 cm depth", comment: "My Data parameter explanation")
        case .soilMoisture0to1cm: return String(localized: "mydata.soilMoisture0to1cm.desc", defaultValue: "Volumetric water content in the top 1 cm of soil", comment: "My Data parameter explanation")
        case .soilMoisture1to3cm: return String(localized: "mydata.soilMoisture1to3cm.desc", defaultValue: "Volumetric water content at 1 to 3 cm depth", comment: "My Data parameter explanation")
        case .soilMoisture3to9cm: return String(localized: "mydata.soilMoisture3to9cm.desc", defaultValue: "Volumetric water content at 3 to 9 cm depth", comment: "My Data parameter explanation")
        case .soilMoisture9to27cm: return String(localized: "mydata.soilMoisture9to27cm.desc", defaultValue: "Volumetric water content at 9 to 27 cm depth", comment: "My Data parameter explanation")
        case .soilMoisture27to81cm: return String(localized: "mydata.soilMoisture27to81cm.desc", defaultValue: "Volumetric water content at 27 to 81 cm depth", comment: "My Data parameter explanation")
        case .cape: return String(localized: "mydata.cape.desc", defaultValue: "Convective Available Potential Energy, indicating thunderstorm potential", comment: "My Data parameter explanation")
        case .evapotranspiration: return String(localized: "mydata.evapotranspiration.desc", defaultValue: "Water evaporated from soil and transpired by plants in the preceding hour", comment: "My Data parameter explanation")
        case .et0FaoEvapotranspiration: return String(localized: "mydata.et0FaoEvapotranspiration.desc", defaultValue: "Reference evapotranspiration assuming unlimited soil water", comment: "My Data parameter explanation")
        case .waveHeight: return String(localized: "mydata.waveHeight.desc", defaultValue: "Significant mean wave height from all wave sources", comment: "My Data parameter explanation")
        case .waveDirection: return String(localized: "mydata.waveDirection.desc", defaultValue: "Direction waves are coming from (0° = north, 90° = east)", comment: "My Data parameter explanation")
        case .wavePeriod: return String(localized: "mydata.wavePeriod.desc", defaultValue: "Time interval between successive wave crests", comment: "My Data parameter explanation")
        case .wavePeakPeriod: return String(localized: "mydata.wavePeakPeriod.desc", defaultValue: "Peak period showing dominant wave frequency", comment: "My Data parameter explanation")
        case .windWaveHeight: return String(localized: "mydata.windWaveHeight.desc", defaultValue: "Significant wave height from local wind-generated waves", comment: "My Data parameter explanation")
        case .windWaveDirection: return String(localized: "mydata.windWaveDirection.desc", defaultValue: "Direction of wind-generated waves", comment: "My Data parameter explanation")
        case .windWavePeriod: return String(localized: "mydata.windWavePeriod.desc", defaultValue: "Period of wind-generated waves", comment: "My Data parameter explanation")
        case .windWavePeakPeriod: return String(localized: "mydata.windWavePeakPeriod.desc", defaultValue: "Peak period of wind-generated waves", comment: "My Data parameter explanation")
        case .swellWaveHeight: return String(localized: "mydata.swellWaveHeight.desc", defaultValue: "Significant height of swell waves from distant weather systems", comment: "My Data parameter explanation")
        case .swellWaveDirection: return String(localized: "mydata.swellWaveDirection.desc", defaultValue: "Direction of primary swell waves", comment: "My Data parameter explanation")
        case .swellWavePeriod: return String(localized: "mydata.swellWavePeriod.desc", defaultValue: "Period of primary swell waves", comment: "My Data parameter explanation")
        case .swellWavePeakPeriod: return String(localized: "mydata.swellWavePeakPeriod.desc", defaultValue: "Peak period of primary swell waves", comment: "My Data parameter explanation")
        case .secondarySwellWaveHeight: return String(localized: "mydata.secondarySwellWaveHeight.desc", defaultValue: "Height of secondary swell component", comment: "My Data parameter explanation")
        case .secondarySwellWaveDirection: return String(localized: "mydata.secondarySwellWaveDirection.desc", defaultValue: "Direction of secondary swell", comment: "My Data parameter explanation")
        case .secondarySwellWavePeriod: return String(localized: "mydata.secondarySwellWavePeriod.desc", defaultValue: "Period of secondary swell waves", comment: "My Data parameter explanation")
        case .tertiarySwellWaveHeight: return String(localized: "mydata.tertiarySwellWaveHeight.desc", defaultValue: "Height of tertiary swell component", comment: "My Data parameter explanation")
        case .tertiarySwellWaveDirection: return String(localized: "mydata.tertiarySwellWaveDirection.desc", defaultValue: "Direction of tertiary swell", comment: "My Data parameter explanation")
        case .tertiarySwellWavePeriod: return String(localized: "mydata.tertiarySwellWavePeriod.desc", defaultValue: "Period of tertiary swell waves", comment: "My Data parameter explanation")
        case .oceanCurrentVelocity: return String(localized: "mydata.oceanCurrentVelocity.desc", defaultValue: "Speed of ocean current including tides and waves", comment: "My Data parameter explanation")
        case .oceanCurrentDirection: return String(localized: "mydata.oceanCurrentDirection.desc", defaultValue: "Direction the ocean current is flowing toward", comment: "My Data parameter explanation")
        case .seaSurfaceTemperature: return String(localized: "mydata.seaSurfaceTemperature.desc", defaultValue: "Water temperature at the ocean surface", comment: "My Data parameter explanation")
        case .seaLevelHeightMsl: return String(localized: "mydata.seaLevelHeightMsl.desc", defaultValue: "Sea level height accounting for tides and atmospheric pressure", comment: "My Data parameter explanation")
        case .pm10: return String(localized: "mydata.pm10.desc", defaultValue: "Particulate matter with diameter less than 10 micrometers", comment: "My Data parameter explanation")
        case .pm25: return String(localized: "mydata.pm25.desc", defaultValue: "Fine particulate matter with diameter less than 2.5 micrometers", comment: "My Data parameter explanation")
        case .carbonMonoxide: return String(localized: "mydata.carbonMonoxide.desc", defaultValue: "Toxic gas from incomplete combustion", comment: "My Data parameter explanation")
        case .nitrogenDioxide: return String(localized: "mydata.nitrogenDioxide.desc", defaultValue: "Pollutant from vehicle emissions and industrial processes", comment: "My Data parameter explanation")
        case .sulphurDioxide: return String(localized: "mydata.sulphurDioxide.desc", defaultValue: "Gas from burning fossil fuels, especially coal", comment: "My Data parameter explanation")
        case .ozone: return String(localized: "mydata.ozone.desc", defaultValue: "Ground-level ozone, a major air pollutant", comment: "My Data parameter explanation")
        case .aerosolOpticalDepth: return String(localized: "mydata.aerosolOpticalDepth.desc", defaultValue: "Measure of atmospheric haze and particle density", comment: "My Data parameter explanation")
        case .dust: return String(localized: "mydata.dust.desc", defaultValue: "Saharan dust particles in the atmosphere", comment: "My Data parameter explanation")
        case .uvIndexAirQuality: return String(localized: "mydata.uvIndexAirQuality.desc", defaultValue: "UV radiation index considering cloud cover", comment: "My Data parameter explanation")
        case .uvIndexClearSky: return String(localized: "mydata.uvIndexClearSky.desc", defaultValue: "UV index assuming clear sky conditions", comment: "My Data parameter explanation")
        case .ammonia: return String(localized: "mydata.ammonia.desc", defaultValue: "Gas from agricultural activities and industrial processes", comment: "My Data parameter explanation")
        case .carbonDioxide: return String(localized: "mydata.carbonDioxide.desc", defaultValue: "Primary greenhouse gas from burning fossil fuels", comment: "My Data parameter explanation")
        case .methane: return String(localized: "mydata.methane.desc", defaultValue: "Potent greenhouse gas from agriculture and natural sources", comment: "My Data parameter explanation")
        case .europeanAqi: return String(localized: "mydata.europeanAqi.desc", defaultValue: "European Air Quality Index (0-100+, higher is worse)", comment: "My Data parameter explanation")
        case .usAqi: return String(localized: "mydata.usAqi.desc", defaultValue: "US Air Quality Index (0-500, higher is worse)", comment: "My Data parameter explanation")
        case .alderPollen: return String(localized: "mydata.alderPollen.desc", defaultValue: "Pollen concentration from alder trees", comment: "My Data parameter explanation")
        case .birchPollen: return String(localized: "mydata.birchPollen.desc", defaultValue: "Pollen concentration from birch trees", comment: "My Data parameter explanation")
        case .grassPollen: return String(localized: "mydata.grassPollen.desc", defaultValue: "Pollen concentration from grass species", comment: "My Data parameter explanation")
        case .mugwortPollen: return String(localized: "mydata.mugwortPollen.desc", defaultValue: "Pollen concentration from mugwort plants", comment: "My Data parameter explanation")
        case .olivePollen: return String(localized: "mydata.olivePollen.desc", defaultValue: "Pollen concentration from olive trees", comment: "My Data parameter explanation")
        case .ragweedPollen: return String(localized: "mydata.ragweedPollen.desc", defaultValue: "Pollen concentration from ragweed plants", comment: "My Data parameter explanation")
        }
    }
    
    /// The Open-Meteo API parameter name for the query string
    var apiKey: String {
        switch self {
        case .temperature2m: return "temperature_2m"
        case .apparentTemperature: return "apparent_temperature"
        case .temperature80m: return "temperature_80m"
        case .temperature120m: return "temperature_120m"
        case .temperature180m: return "temperature_180m"
        case .relativeHumidity2m: return "relative_humidity_2m"
        case .dewPoint2m: return "dewpoint_2m"
        case .vapourPressureDeficit: return "vapour_pressure_deficit"
        case .windSpeed10m: return "wind_speed_10m"
        case .windSpeed80m: return "wind_speed_80m"
        case .windSpeed120m: return "wind_speed_120m"
        case .windSpeed180m: return "wind_speed_180m"
        case .windDirection10m: return "wind_direction_10m"
        case .windDirection80m: return "wind_direction_80m"
        case .windDirection120m: return "wind_direction_120m"
        case .windDirection180m: return "wind_direction_180m"
        case .windGusts10m: return "wind_gusts_10m"
        case .precipitation: return "precipitation"
        case .rain: return "rain"
        case .showers: return "showers"
        case .snowfall: return "snowfall"
        case .snowDepth: return "snow_depth"
        case .freezingLevelHeight: return "freezing_level_height"
        case .pressureMsl: return "pressure_msl"
        case .surfacePressure: return "surface_pressure"
        case .cloudCover: return "cloud_cover"
        case .cloudCoverLow: return "cloud_cover_low"
        case .cloudCoverMid: return "cloud_cover_mid"
        case .cloudCoverHigh: return "cloud_cover_high"
        case .visibility: return "visibility"
        case .weatherCode: return "weather_code"
        case .isDay: return "is_day"
        case .uvIndex: return "uv_index"
        case .shortwaveRadiation: return "shortwave_radiation"
        case .directRadiation: return "direct_radiation"
        case .directNormalIrradiance: return "direct_normal_irradiance"
        case .diffuseRadiation: return "diffuse_radiation"
        case .sunshineDuration: return "sunshine_duration"
        case .soilTemperature0cm: return "soil_temperature_0cm"
        case .soilTemperature6cm: return "soil_temperature_6cm"
        case .soilTemperature18cm: return "soil_temperature_18cm"
        case .soilTemperature54cm: return "soil_temperature_54cm"
        case .soilMoisture0to1cm: return "soil_moisture_0_to_1cm"
        case .soilMoisture1to3cm: return "soil_moisture_1_to_3cm"
        case .soilMoisture3to9cm: return "soil_moisture_3_to_9cm"
        case .soilMoisture9to27cm: return "soil_moisture_9_to_27cm"
        case .soilMoisture27to81cm: return "soil_moisture_27_to_81cm"
        case .cape: return "cape"
        case .evapotranspiration: return "evapotranspiration"
        case .et0FaoEvapotranspiration: return "et0_fao_evapotranspiration"
        case .waveHeight: return "wave_height"
        case .waveDirection: return "wave_direction"
        case .wavePeriod: return "wave_period"
        case .wavePeakPeriod: return "wave_peak_period"
        case .windWaveHeight: return "wind_wave_height"
        case .windWaveDirection: return "wind_wave_direction"
        case .windWavePeriod: return "wind_wave_period"
        case .windWavePeakPeriod: return "wind_wave_peak_period"
        case .swellWaveHeight: return "swell_wave_height"
        case .swellWaveDirection: return "swell_wave_direction"
        case .swellWavePeriod: return "swell_wave_period"
        case .swellWavePeakPeriod: return "swell_wave_peak_period"
        case .secondarySwellWaveHeight: return "secondary_swell_wave_height"
        case .secondarySwellWaveDirection: return "secondary_swell_wave_direction"
        case .secondarySwellWavePeriod: return "secondary_swell_wave_period"
        case .tertiarySwellWaveHeight: return "tertiary_swell_wave_height"
        case .tertiarySwellWaveDirection: return "tertiary_swell_wave_direction"
        case .tertiarySwellWavePeriod: return "tertiary_swell_wave_period"
        case .oceanCurrentVelocity: return "ocean_current_velocity"
        case .oceanCurrentDirection: return "ocean_current_direction"
        case .seaSurfaceTemperature: return "sea_surface_temperature"
        case .seaLevelHeightMsl: return "sea_level_height_msl"
        case .pm10: return "pm10"
        case .pm25: return "pm2_5"
        case .carbonMonoxide: return "carbon_monoxide"
        case .nitrogenDioxide: return "nitrogen_dioxide"
        case .sulphurDioxide: return "sulphur_dioxide"
        case .ozone: return "ozone"
        case .aerosolOpticalDepth: return "aerosol_optical_depth"
        case .dust: return "dust"
        case .uvIndexAirQuality: return "uv_index"
        case .uvIndexClearSky: return "uv_index_clear_sky"
        case .ammonia: return "ammonia"
        case .carbonDioxide: return "carbon_dioxide"
        case .methane: return "methane"
        case .europeanAqi: return "european_aqi"
        case .usAqi: return "us_aqi"
        case .alderPollen: return "alder_pollen"
        case .birchPollen: return "birch_pollen"
        case .grassPollen: return "grass_pollen"
        case .mugwortPollen: return "mugwort_pollen"
        case .olivePollen: return "olive_pollen"
        case .ragweedPollen: return "ragweed_pollen"
        }
    }
    
    var category: MyDataCategory {
        switch self {
        case .temperature2m, .apparentTemperature, .temperature80m, .temperature120m, .temperature180m:
            return .temperature
        case .relativeHumidity2m, .dewPoint2m, .vapourPressureDeficit:
            return .humidity
        case .windSpeed10m, .windSpeed80m, .windSpeed120m, .windSpeed180m,
             .windDirection10m, .windDirection80m, .windDirection120m, .windDirection180m,
             .windGusts10m:
            return .wind
        case .precipitation, .rain, .showers, .snowfall, .snowDepth, .freezingLevelHeight:
            return .precipitation
        case .pressureMsl, .surfacePressure:
            return .pressure
        case .cloudCover, .cloudCoverLow, .cloudCoverMid, .cloudCoverHigh,
             .visibility, .weatherCode, .isDay:
            return .clouds
        case .uvIndex, .shortwaveRadiation, .directRadiation, .directNormalIrradiance,
             .diffuseRadiation, .sunshineDuration:
            return .solar
        case .soilTemperature0cm, .soilTemperature6cm, .soilTemperature18cm, .soilTemperature54cm,
             .soilMoisture0to1cm, .soilMoisture1to3cm, .soilMoisture3to9cm,
             .soilMoisture9to27cm, .soilMoisture27to81cm:
            return .soil
        case .cape, .evapotranspiration, .et0FaoEvapotranspiration:
            return .atmosphere
        case .waveHeight, .waveDirection, .wavePeriod, .wavePeakPeriod,
             .windWaveHeight, .windWaveDirection, .windWavePeriod, .windWavePeakPeriod,
             .swellWaveHeight, .swellWaveDirection, .swellWavePeriod, .swellWavePeakPeriod,
             .secondarySwellWaveHeight, .secondarySwellWaveDirection, .secondarySwellWavePeriod,
             .tertiarySwellWaveHeight, .tertiarySwellWaveDirection, .tertiarySwellWavePeriod,
             .oceanCurrentVelocity, .oceanCurrentDirection,
             .seaSurfaceTemperature, .seaLevelHeightMsl:
            return .marine
        case .pm10, .pm25, .carbonMonoxide, .nitrogenDioxide, .sulphurDioxide, .ozone,
             .aerosolOpticalDepth, .dust, .uvIndexAirQuality, .uvIndexClearSky,
             .ammonia, .carbonDioxide, .methane,
             .europeanAqi, .usAqi,
             .alderPollen, .birchPollen, .grassPollen, .mugwortPollen, .olivePollen, .ragweedPollen:
            return .airQuality
        }
    }
    
    /// Unit type for determining how to format and convert values
    var unitType: MyDataUnitType {
        switch self {
        case .temperature2m, .apparentTemperature, .temperature80m, .temperature120m, .temperature180m,
             .dewPoint2m, .soilTemperature0cm, .soilTemperature6cm, .soilTemperature18cm, .soilTemperature54cm:
            return .temperature
        case .windSpeed10m, .windSpeed80m, .windSpeed120m, .windSpeed180m, .windGusts10m:
            return .windSpeed
        case .windDirection10m, .windDirection80m, .windDirection120m, .windDirection180m:
            return .degrees
        case .precipitation, .rain, .showers, .evapotranspiration, .et0FaoEvapotranspiration:
            return .precipitationMM
        case .snowfall:
            return .snowfallCM
        case .snowDepth:
            return .distanceMeters
        case .freezingLevelHeight:
            return .altitudeMeters
        case .pressureMsl, .surfacePressure:
            return .pressure
        case .cloudCover, .cloudCoverLow, .cloudCoverMid, .cloudCoverHigh, .relativeHumidity2m:
            return .percent
        case .visibility:
            return .visibilityMeters
        case .weatherCode:
            return .weatherCode
        case .isDay:
            return .boolean
        case .uvIndex:
            return .index
        case .shortwaveRadiation, .directRadiation, .directNormalIrradiance, .diffuseRadiation:
            return .wattsPerSquareMeter
        case .sunshineDuration:
            return .seconds
        case .soilMoisture0to1cm, .soilMoisture1to3cm, .soilMoisture3to9cm,
             .soilMoisture9to27cm, .soilMoisture27to81cm:
            return .cubicMeterPerCubicMeter
        case .vapourPressureDeficit:
            return .kiloPascal
        case .cape:
            return .joulesPerKg
        case .waveHeight, .windWaveHeight, .swellWaveHeight,
             .secondarySwellWaveHeight, .tertiarySwellWaveHeight, .seaLevelHeightMsl:
            return .distanceMeters
        case .waveDirection, .windWaveDirection, .swellWaveDirection,
             .secondarySwellWaveDirection, .tertiarySwellWaveDirection, .oceanCurrentDirection:
            return .degrees
        case .wavePeriod, .wavePeakPeriod, .windWavePeriod, .windWavePeakPeriod,
             .swellWavePeriod, .swellWavePeakPeriod, .secondarySwellWavePeriod, .tertiarySwellWavePeriod:
            return .seconds
        case .oceanCurrentVelocity:
            return .windSpeed  // Uses km/h like wind speed
        case .seaSurfaceTemperature:
            return .temperature
        case .pm10, .pm25, .carbonMonoxide, .nitrogenDioxide, .sulphurDioxide, .ozone,
             .dust, .ammonia, .methane:
            return .microgramsPerCubicMeter
        case .carbonDioxide:
            return .ppm
        case .aerosolOpticalDepth:
            return .index  // Dimensionless
        case .uvIndexAirQuality, .uvIndexClearSky:
            return .index
        case .europeanAqi, .usAqi:
            return .airQualityIndex
        case .alderPollen, .birchPollen, .grassPollen, .mugwortPollen, .olivePollen, .ragweedPollen:
            return .pollen
        }
    }
    
    /// API endpoint required to fetch this parameter
    var apiEndpoint: MyDataAPIEndpoint {
        switch self {
        // Marine API parameters
        case .waveHeight, .waveDirection, .wavePeriod, .wavePeakPeriod,
             .windWaveHeight, .windWaveDirection, .windWavePeriod, .windWavePeakPeriod,
             .swellWaveHeight, .swellWaveDirection, .swellWavePeriod, .swellWavePeakPeriod,
             .secondarySwellWaveHeight, .secondarySwellWaveDirection, .secondarySwellWavePeriod,
             .tertiarySwellWaveHeight, .tertiarySwellWaveDirection, .tertiarySwellWavePeriod,
             .oceanCurrentVelocity, .oceanCurrentDirection,
             .seaSurfaceTemperature, .seaLevelHeightMsl:
            return .marine
            
        // Air Quality API parameters
        case .pm10, .pm25, .carbonMonoxide, .nitrogenDioxide, .sulphurDioxide, .ozone,
             .aerosolOpticalDepth, .dust, .uvIndexAirQuality, .uvIndexClearSky,
             .ammonia, .carbonDioxide, .methane,
             .europeanAqi, .usAqi,
             .alderPollen, .birchPollen, .grassPollen, .mugwortPollen, .olivePollen, .ragweedPollen:
            return .airQuality
            
        // All other parameters use the standard forecast API
        default:
            return .forecast
        }
    }
    
    /// Parameters grouped by category
    static func parameters(for category: MyDataCategory) -> [MyDataParameter] {
        allCases.filter { $0.category == category }
    }
}

// MARK: - API Endpoint types

enum MyDataAPIEndpoint {
    case forecast      // api.open-meteo.com/v1/forecast
    case marine        // marine-api.open-meteo.com/v1/marine  
    case airQuality    // air-quality-api.open-meteo.com/v1/air-quality
}

// MARK: - Unit types for formatting

enum MyDataUnitType {
    case temperature
    case windSpeed
    case degrees
    case precipitationMM
    case snowfallCM
    case distanceMeters
    case altitudeMeters
    case pressure
    case percent
    case visibilityMeters
    case weatherCode
    case boolean
    case index
    case wattsPerSquareMeter
    case seconds
    case cubicMeterPerCubicMeter
    case kiloPascal
    case joulesPerKg
    case microgramsPerCubicMeter  // Air quality pollutants
    case pollen  // Pollen grains per cubic meter
    case airQualityIndex  // AQI values
    case ppm  // Parts per million (CO2)
}

// MARK: - Format helper

struct MyDataFormatHelper {
    
    /// Format a raw API value for display based on the parameter type and user's unit preferences
    static func format(parameter: MyDataParameter, value: Double, settings: AppSettings) -> String {
        switch parameter.unitType {
        case .temperature:
            let converted = settings.temperatureUnit.convert(value)
            return String(format: "%.1f%@", converted, settings.temperatureUnit.rawValue)
            
        case .windSpeed:
            let converted = settings.windSpeedUnit.convert(value)
            return String(format: "%.1f %@", converted, settings.windSpeedUnit.rawValue)
            
        case .degrees:
            let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            let index = Int((value / 45.0).rounded()) % 8
            return "\(directions[index]) (\(Int(value))°)"
            
        case .precipitationMM:
            let converted = settings.precipitationUnit.convert(value)
            return String(format: "%.2f %@", converted, settings.precipitationUnit.rawValue)
            
        case .snowfallCM:
            switch settings.precipitationUnit {
            case .inches:
                return String(format: "%.1f in", value * 0.393701)
            case .millimeters:
                return String(format: "%.1f cm", value)
            }
            
        case .distanceMeters:
            // Wave heights, sea level - convert to feet if using imperial
            switch settings.distanceUnit {
            case .miles:
                let feet = value * 3.28084
                return String(format: "%.1f ft", feet)
            case .kilometers:
                return String(format: "%.1f m", value)
            }
            
        case .altitudeMeters:
            switch settings.distanceUnit {
            case .miles:
                return String(format: "%.0f ft", value * 3.28084)
            case .kilometers:
                return String(format: "%.0f m", value)
            }
            
        case .pressure:
            let converted = settings.pressureUnit.convert(value)
            let formatString = settings.pressureUnit == .hPa ? "%.0f %@" : "%.2f %@"
            return String(format: formatString, converted, settings.pressureUnit.rawValue)
            
        case .percent:
            return String(format: "%.0f%%", value)
            
        case .visibilityMeters:
            let km = value / 1000.0
            let converted = settings.distanceUnit.convert(km)
            return settings.distanceUnit.format(converted, decimals: 1)
            
        case .weatherCode:
            if let code = WeatherCode(rawValue: Int(value)) {
                return code.description
            }
            return String(localized: "mydata.format.weather_code", defaultValue: "Code \(Int(value))", comment: "Fallback label for an unknown WMO weather code")

        case .boolean:
            return value == 1
                ? String(localized: "mydata.format.day", defaultValue: "Day", comment: "Day/night value when it is daytime")
                : String(localized: "mydata.format.night", defaultValue: "Night", comment: "Day/night value when it is nighttime")
            
        case .index:
            return String(format: "%.1f", value)
            
        case .wattsPerSquareMeter:
            return String(format: "%.0f W/m²", value)
            
        case .seconds:
            let minutes = Int(value) / 60
            if minutes >= 60 {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                return "\(hours)h \(remainingMinutes)m"
            }
            return "\(minutes) min"
            
        case .cubicMeterPerCubicMeter:
            return String(format: "%.3f m³/m³", value)
            
        case .kiloPascal:
            return String(format: "%.2f kPa", value)
            
        case .joulesPerKg:
            return String(format: "%.0f J/kg", value)
            
        case .microgramsPerCubicMeter:
            return String(format: "%.1f µg/m³", value)
            
        case .ppm:
            return String(format: "%.1f ppm", value)
            
        case .pollen:
            return String(format: "%.0f grains/m³", value)
            
        case .airQualityIndex:
            return String(format: "%.0f", value)
        }
    }
    
    /// Get the accessibility-friendly description of a formatted value
    static func accessibilityFormat(parameter: MyDataParameter, value: Double, settings: AppSettings) -> String {
        let formattedValue = format(parameter: parameter, value: value, settings: settings)
        return "\(parameter.displayName): \(formattedValue)"
    }
}
