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
    
    var displayName: String { rawValue }
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
        case .temperature2m: return "Temperature (2m)"
        case .apparentTemperature: return "Feels Like"
        case .temperature80m: return "Temperature (80m)"
        case .temperature120m: return "Temperature (120m)"
        case .temperature180m: return "Temperature (180m)"
        case .relativeHumidity2m: return "Relative Humidity"
        case .dewPoint2m: return "Dew Point"
        case .vapourPressureDeficit: return "Vapour Pressure Deficit"
        case .windSpeed10m: return "Wind Speed (10m)"
        case .windSpeed80m: return "Wind Speed (80m)"
        case .windSpeed120m: return "Wind Speed (120m)"
        case .windSpeed180m: return "Wind Speed (180m)"
        case .windDirection10m: return "Wind Direction (10m)"
        case .windDirection80m: return "Wind Direction (80m)"
        case .windDirection120m: return "Wind Direction (120m)"
        case .windDirection180m: return "Wind Direction (180m)"
        case .windGusts10m: return "Wind Gusts"
        case .precipitation: return "Precipitation"
        case .rain: return "Rain"
        case .showers: return "Showers"
        case .snowfall: return "Snowfall"
        case .snowDepth: return "Snow Depth"
        case .freezingLevelHeight: return "Freezing Level"
        case .pressureMsl: return "Sea Level Pressure"
        case .surfacePressure: return "Surface Pressure"
        case .cloudCover: return "Cloud Cover"
        case .cloudCoverLow: return "Low Clouds"
        case .cloudCoverMid: return "Mid-Level Clouds"
        case .cloudCoverHigh: return "High Clouds"
        case .visibility: return "Visibility"
        case .weatherCode: return "Weather Code"
        case .isDay: return "Day or Night"
        case .uvIndex: return "UV Index"
        case .shortwaveRadiation: return "Solar Radiation"
        case .directRadiation: return "Direct Radiation"
        case .directNormalIrradiance: return "Direct Normal Irradiance"
        case .diffuseRadiation: return "Diffuse Radiation"
        case .sunshineDuration: return "Sunshine Duration"
        case .soilTemperature0cm: return "Surface Soil Temp"
        case .soilTemperature6cm: return "Soil Temp (6 cm)"
        case .soilTemperature18cm: return "Soil Temp (18 cm)"
        case .soilTemperature54cm: return "Soil Temp (54 cm)"
        case .soilMoisture0to1cm: return "Soil Moisture (0–1 cm)"
        case .soilMoisture1to3cm: return "Soil Moisture (1–3 cm)"
        case .soilMoisture3to9cm: return "Soil Moisture (3–9 cm)"
        case .soilMoisture9to27cm: return "Soil Moisture (9–27 cm)"
        case .soilMoisture27to81cm: return "Soil Moisture (27–81 cm)"
        case .cape: return "CAPE"
        case .evapotranspiration: return "Evapotranspiration"
        case .et0FaoEvapotranspiration: return "Reference Evapotranspiration"
        case .waveHeight: return "Wave Height"
        case .waveDirection: return "Wave Direction"
        case .wavePeriod: return "Wave Period"
        case .wavePeakPeriod: return "Wave Peak Period"
        case .windWaveHeight: return "Wind Wave Height"
        case .windWaveDirection: return "Wind Wave Direction"
        case .windWavePeriod: return "Wind Wave Period"
        case .windWavePeakPeriod: return "Wind Wave Peak Period"
        case .swellWaveHeight: return "Swell Wave Height"
        case .swellWaveDirection: return "Swell Wave Direction"
        case .swellWavePeriod: return "Swell Wave Period"
        case .swellWavePeakPeriod: return "Swell Wave Peak Period"
        case .secondarySwellWaveHeight: return "Secondary Swell Height"
        case .secondarySwellWaveDirection: return "Secondary Swell Direction"
        case .secondarySwellWavePeriod: return "Secondary Swell Period"
        case .tertiarySwellWaveHeight: return "Tertiary Swell Height"
        case .tertiarySwellWaveDirection: return "Tertiary Swell Direction"
        case .tertiarySwellWavePeriod: return "Tertiary Swell Period"
        case .oceanCurrentVelocity: return "Ocean Current Speed"
        case .oceanCurrentDirection: return "Ocean Current Direction"
        case .seaSurfaceTemperature: return "Sea Surface Temperature"
        case .seaLevelHeightMsl: return "Sea Level Height"
        case .pm10: return "PM10 Particulates"
        case .pm25: return "PM2.5 Particulates"
        case .carbonMonoxide: return "Carbon Monoxide (CO)"
        case .nitrogenDioxide: return "Nitrogen Dioxide (NO₂)"
        case .sulphurDioxide: return "Sulphur Dioxide (SO₂)"
        case .ozone: return "Ozone (O₃)"
        case .aerosolOpticalDepth: return "Aerosol Optical Depth"
        case .dust: return "Dust"
        case .uvIndexAirQuality: return "UV Index"
        case .uvIndexClearSky: return "UV Index (Clear Sky)"
        case .ammonia: return "Ammonia (NH₃)"
        case .carbonDioxide: return "Carbon Dioxide (CO₂)"
        case .methane: return "Methane (CH₄)"
        case .europeanAqi: return "European Air Quality Index"
        case .usAqi: return "US Air Quality Index"
        case .alderPollen: return "Alder Pollen"
        case .birchPollen: return "Birch Pollen"
        case .grassPollen: return "Grass Pollen"
        case .mugwortPollen: return "Mugwort Pollen"
        case .olivePollen: return "Olive Pollen"
        case .ragweedPollen: return "Ragweed Pollen"
        }
    }
    
    var explanation: String {
        switch self {
        case .temperature2m: return "Air temperature at 2 meters above ground level"
        case .apparentTemperature: return "Perceived temperature combining wind chill, humidity, and solar radiation"
        case .temperature80m: return "Air temperature at 80 meters, useful for wind turbine operations"
        case .temperature120m: return "Air temperature at 120 meters above ground"
        case .temperature180m: return "Air temperature at 180 meters above ground"
        case .relativeHumidity2m: return "Percentage of moisture in the air relative to saturation"
        case .dewPoint2m: return "Temperature at which air becomes saturated and dew forms"
        case .vapourPressureDeficit: return "Difference between moisture in air and moisture at saturation, important for plant health"
        case .windSpeed10m: return "Wind speed at standard 10-meter measurement height"
        case .windSpeed80m: return "Wind speed at 80 meters, relevant for wind energy"
        case .windSpeed120m: return "Wind speed at 120 meters above ground"
        case .windSpeed180m: return "Wind speed at 180 meters above ground"
        case .windDirection10m: return "Direction wind is blowing from at 10 meters, in degrees"
        case .windDirection80m: return "Wind direction at 80 meters above ground"
        case .windDirection120m: return "Wind direction at 120 meters above ground"
        case .windDirection180m: return "Wind direction at 180 meters above ground"
        case .windGusts10m: return "Maximum wind gust speed in the preceding hour at 10 meters"
        case .precipitation: return "Total precipitation including rain, showers, and snow in the preceding hour"
        case .rain: return "Rainfall from large-scale weather systems in the preceding hour"
        case .showers: return "Convective precipitation from localized showers in the preceding hour"
        case .snowfall: return "Snowfall amount in the preceding hour"
        case .snowDepth: return "Current snow depth on the ground"
        case .freezingLevelHeight: return "Altitude where temperature reaches 0°C"
        case .pressureMsl: return "Atmospheric pressure adjusted to sea level"
        case .surfacePressure: return "Atmospheric pressure at the actual ground surface"
        case .cloudCover: return "Total cloud cover as a percentage of sky"
        case .cloudCoverLow: return "Low-level clouds and fog up to 3 km altitude"
        case .cloudCoverMid: return "Mid-level clouds between 3 and 8 km altitude"
        case .cloudCoverHigh: return "High-level clouds above 8 km altitude"
        case .visibility: return "Maximum viewing distance through the atmosphere"
        case .weatherCode: return "WMO weather interpretation code describing current conditions"
        case .isDay: return "Whether the current time is during daylight hours"
        case .uvIndex: return "Ultraviolet radiation index indicating sunburn risk"
        case .shortwaveRadiation: return "Total incoming solar radiation on a horizontal surface"
        case .directRadiation: return "Solar radiation arriving directly from the sun on a horizontal plane"
        case .directNormalIrradiance: return "Solar radiation measured perpendicular to the sun's rays"
        case .diffuseRadiation: return "Solar radiation scattered by the atmosphere"
        case .sunshineDuration: return "Duration of direct sunlight in the preceding hour"
        case .soilTemperature0cm: return "Temperature at the soil surface"
        case .soilTemperature6cm: return "Soil temperature at 6 cm depth"
        case .soilTemperature18cm: return "Soil temperature at 18 cm depth"
        case .soilTemperature54cm: return "Soil temperature at 54 cm depth"
        case .soilMoisture0to1cm: return "Volumetric water content in the top 1 cm of soil"
        case .soilMoisture1to3cm: return "Volumetric water content at 1 to 3 cm depth"
        case .soilMoisture3to9cm: return "Volumetric water content at 3 to 9 cm depth"
        case .soilMoisture9to27cm: return "Volumetric water content at 9 to 27 cm depth"
        case .soilMoisture27to81cm: return "Volumetric water content at 27 to 81 cm depth"
        case .cape: return "Convective Available Potential Energy, indicating thunderstorm potential"
        case .evapotranspiration: return "Water evaporated from soil and transpired by plants in the preceding hour"
        case .et0FaoEvapotranspiration: return "Reference evapotranspiration assuming unlimited soil water"
        case .waveHeight: return "Significant mean wave height from all wave sources"
        case .waveDirection: return "Direction waves are coming from (0° = north, 90° = east)"
        case .wavePeriod: return "Time interval between successive wave crests"
        case .wavePeakPeriod: return "Peak period showing dominant wave frequency"
        case .windWaveHeight: return "Significant wave height from local wind-generated waves"
        case .windWaveDirection: return "Direction of wind-generated waves"
        case .windWavePeriod: return "Period of wind-generated waves"
        case .windWavePeakPeriod: return "Peak period of wind-generated waves"
        case .swellWaveHeight: return "Significant height of swell waves from distant weather systems"
        case .swellWaveDirection: return "Direction of primary swell waves"
        case .swellWavePeriod: return "Period of primary swell waves"
        case .swellWavePeakPeriod: return "Peak period of primary swell waves"
        case .secondarySwellWaveHeight: return "Height of secondary swell component"
        case .secondarySwellWaveDirection: return "Direction of secondary swell"
        case .secondarySwellWavePeriod: return "Period of secondary swell waves"
        case .tertiarySwellWaveHeight: return "Height of tertiary swell component"
        case .tertiarySwellWaveDirection: return "Direction of tertiary swell"
        case .tertiarySwellWavePeriod: return "Period of tertiary swell waves"
        case .oceanCurrentVelocity: return "Speed of ocean current including tides and waves"
        case .oceanCurrentDirection: return "Direction the ocean current is flowing toward"
        case .seaSurfaceTemperature: return "Water temperature at the ocean surface"
        case .seaLevelHeightMsl: return "Sea level height accounting for tides and atmospheric pressure"
        case .pm10: return "Particulate matter with diameter less than 10 micrometers"
        case .pm25: return "Fine particulate matter with diameter less than 2.5 micrometers"
        case .carbonMonoxide: return "Toxic gas from incomplete combustion"
        case .nitrogenDioxide: return "Pollutant from vehicle emissions and industrial processes"
        case .sulphurDioxide: return "Gas from burning fossil fuels, especially coal"
        case .ozone: return "Ground-level ozone, a major air pollutant"
        case .aerosolOpticalDepth: return "Measure of atmospheric haze and particle density"
        case .dust: return "Saharan dust particles in the atmosphere"
        case .uvIndexAirQuality: return "UV radiation index considering cloud cover"
        case .uvIndexClearSky: return "UV index assuming clear sky conditions"
        case .ammonia: return "Gas from agricultural activities and industrial processes"
        case .carbonDioxide: return "Primary greenhouse gas from burning fossil fuels"
        case .methane: return "Potent greenhouse gas from agriculture and natural sources"
        case .europeanAqi: return "European Air Quality Index (0-100+, higher is worse)"
        case .usAqi: return "US Air Quality Index (0-500, higher is worse)"
        case .alderPollen: return "Pollen concentration from alder trees"
        case .birchPollen: return "Pollen concentration from birch trees"
        case .grassPollen: return "Pollen concentration from grass species"
        case .mugwortPollen: return "Pollen concentration from mugwort plants"
        case .olivePollen: return "Pollen concentration from olive trees"
        case .ragweedPollen: return "Pollen concentration from ragweed plants"
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
    
    /// Parameters grouped by category
    static func parameters(for category: MyDataCategory) -> [MyDataParameter] {
        allCases.filter { $0.category == category }
    }
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
            return String(format: "%.2f m", value)
            
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
            return "Code \(Int(value))"
            
        case .boolean:
            return value == 1 ? "Day" : "Night"
            
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
