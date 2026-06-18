//
//  StormApproachService.swift
//  Fast Weather
//
//  Accessible "radar replacement": answers the questions a sighted user gets
//  from glancing at an animated radar map — is precipitation approaching, from
//  which direction, how intense, and how soon will it reach me — using plain
//  text that works for VoiceOver and sighted users alike.
//
//  How it works (see docs/NOWCASTING_AND_SHORT_TERM_FORECAST_PROPOSAL.md):
//   • Samples Open-Meteo precipitation at a RING of points around the user in a
//     single multi-coordinate API call (the real precipitation field, not a
//     single point labelled with 8 fake directions).
//   • Derives the direction precipitation is currently located (B1).
//   • Estimates storm-field MOTION by tracking the precipitation-weighted
//     centroid across two forecast frames (B2) — grounded in the precipitation
//     data itself, not inferred from surface wind direction.
//   • Computes arrival time at the user's location from their own forecast.
//   • Classifies impact on nearby saved cities (Part C).
//
//  Unlike RadarService (which is about the timeline AT a point), this service is
//  about the SPATIAL picture AROUND a point. It always uses Open-Meteo because
//  Open-Meteo exposes a gridded forecast queryable at arbitrary coordinates;
//  WeatherKit does not expose surrounding-grid precipitation.
//

import Foundation
import CoreLocation

// MARK: - Model

/// Precipitation intensity bucket derived from a mm/hour rate.
enum PrecipIntensity: Int, Comparable {
    case none = 0
    case light = 1
    case moderate = 2
    case heavy = 3
    case veryHeavy = 4

    static func < (lhs: PrecipIntensity, rhs: PrecipIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Classify a rate in millimetres per hour.
    init(mmPerHour mm: Double) {
        switch mm {
        case ..<0.1:  self = .none
        case ..<2.5:  self = .light
        case ..<10:   self = .moderate
        case ..<50:   self = .heavy
        default:      self = .veryHeavy
        }
    }

    /// Plain adjective for use mid-sentence ("light rain", "heavy rain").
    var adjective: String {
        switch self {
        case .none:      return "no"
        case .light:     return "light"
        case .moderate:  return "moderate"
        case .heavy:     return "heavy"
        case .veryHeavy: return "very heavy"
        }
    }

    /// Standalone label ("Light").
    var label: String {
        switch self {
        case .none:      return "None"
        case .light:     return "Light"
        case .moderate:  return "Moderate"
        case .heavy:     return "Heavy"
        case .veryHeavy: return "Very heavy"
        }
    }
}

/// Estimated motion of the precipitation field as a whole.
struct StormMotion: Equatable {
    /// Compass bearing the field is moving TOWARD (degrees, 0 = North, 90 = East).
    let towardBearing: Double
    /// Speed in kilometres per hour.
    let speedKmh: Double
}

/// Impact classification for a nearby saved city ("your places").
struct CityImpact: Identifiable, Equatable {
    enum Trend: Equatable {
        case rainingNow
        case arriving          // precipitation onset in this city's own forecast
        case trackingToward    // storm field motion points at this city
        case clear
    }
    let id = UUID()
    let cityName: String
    let trend: Trend
    let arrivalMinutes: Int?
    let intensity: PrecipIntensity

    static func == (lhs: CityImpact, rhs: CityImpact) -> Bool {
        lhs.cityName == rhs.cityName && lhs.trend == rhs.trend &&
        lhs.arrivalMinutes == rhs.arrivalMinutes && lhs.intensity == rhs.intensity
    }
}

/// Impact classification for a nearby bundled town (the "radar-like" named layer).
/// Carries distance and bearing so the narration can place it ("12 mi west").
struct PlaceImpact: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let trend: CityImpact.Trend
    let arrivalMinutes: Int?
    let intensity: PrecipIntensity
    let distanceKm: Double
    let bearing: Double

    static func == (lhs: PlaceImpact, rhs: PlaceImpact) -> Bool {
        lhs.name == rhs.name && lhs.trend == rhs.trend &&
        lhs.arrivalMinutes == rhs.arrivalMinutes && lhs.intensity == rhs.intensity
    }
}

/// The spatial precipitation picture around a location.
struct StormApproach {
    enum Situation {
        case rainingHere            // precipitation at the user's location now
        case approaching            // precipitation will reach the user within the horizon
        case nearbyNotApproaching   // precipitation in the area but not heading to the user
        case clear                  // nothing within range now or within the horizon
    }

    let situation: Situation
    /// Direction precipitation is currently located, relative to the user (degrees, 0 = N). Nil if none nearby.
    let fromBearing: Double?
    /// Distance to the nearest active precipitation (km). Nil if none nearby.
    let nearestDistanceKm: Double?
    /// Intensity of the nearest active precipitation.
    let nearestIntensity: PrecipIntensity
    /// Intensity at the user's location right now (meaningful when `.rainingHere`).
    let hereIntensity: PrecipIntensity
    /// Estimated field motion. Nil when it can't be reliably determined (e.g. stationary or too sparse).
    let motion: StormMotion?
    /// Minutes until precipitation reaches the user. Nil when raining now or not approaching.
    let arrivalMinutes: Int?
    /// Impact on nearby saved cities ("your places"), nearest first.
    let cityImpacts: [CityImpact]
    /// Impact on nearby bundled towns (the named radar-like layer), nearest first.
    let placeImpacts: [PlaceImpact]
    /// Radius (km) of the outermost sampling ring — the area this summary covers.
    let ringRadiusKm: Double
}

// MARK: - Service

final class StormApproachService {
    static let shared = StormApproachService()
    private init() {}

    // Sampling geometry. Two rings give a coarse but real precipitation field
    // around the user while keeping the request small (8 bearings × 2 radii + centre).
    private let bearings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
    private let radiiKm: [Double] = [30, 60]

    private let activeThresholdMm = 0.1   // 15-minute precipitation sum considered "active"
    private let horizonSteps = 8          // 8 × 15 min = 2-hour look-ahead
    private let maxCityKm = 250.0         // only classify saved cities within this range
    private let maxCities = 5
    private let placeRadiusKm = 80.0      // bundled towns within ~50 mi
    private let maxPlaces = 12            // candidates sampled (only active/arriving are narrated)

    // Bundled city list, loaded once and cached for the app's lifetime. Used to
    // name nearby towns the storm is over / heading for, without reverse geocoding.
    private var bundledPlacesCache: [CityLocation]?
    private let bundledLoadLock = NSLock()

    /// Fetch and analyse the precipitation field around `city`.
    /// - Parameter nearbySavedCities: saved cities to classify for impact (Part C);
    ///   the current city and far-away cities are filtered out internally.
    func fetchStormApproach(for city: City,
                            nearbySavedCities: [City] = []) async throws -> StormApproach {
        // 1. Build the sample layout: centre + ring points.
        var samples: [SamplePoint] = [SamplePoint(lat: city.latitude, lon: city.longitude,
                                                   bearing: 0, distanceKm: 0)]
        for radius in radiiKm {
            for bearing in bearings {
                let (lat, lon) = GeoMath.destination(lat: city.latitude, lon: city.longitude,
                                                     bearingDeg: bearing, distanceKm: radius)
                samples.append(SamplePoint(lat: lat, lon: lon, bearing: bearing, distanceKm: radius))
            }
        }

        // 2. Nearby saved cities (exclude the current one and anything far away).
        let cityPoints: [CityPoint] = nearbySavedCities.compactMap { saved in
            let d = GeoMath.haversineKm(city.latitude, city.longitude, saved.latitude, saved.longitude)
            guard d > 1.0, d <= maxCityKm else { return nil }   // >1km excludes the same location
            return CityPoint(city: saved, distanceKm: d,
                             bearing: GeoMath.bearingDeg(city.latitude, city.longitude,
                                                         saved.latitude, saved.longitude))
        }
        .sorted { $0.distanceKm < $1.distanceKm }
        .prefix(maxCities)
        .map { $0 }

        // 3. Nearby bundled towns (named radar-like layer), excluding saved ones to avoid duplication.
        let placePoints = nearbyPlaces(around: city, excluding: nearbySavedCities)

        // 4. One multi-coordinate request for every point (same timestamp everywhere).
        let coords = samples.map { ($0.lat, $0.lon) }
                   + cityPoints.map { ($0.city.latitude, $0.city.longitude) }
                   + placePoints.map { ($0.city.latitude, $0.city.longitude) }
        let forecasts = try await fetchForecasts(coords: coords)
        guard forecasts.count == coords.count else {
            debugLog("⚠️ StormApproach: expected \(coords.count) forecasts, got \(forecasts.count)")
            throw RadarError.invalidData
        }

        let sampleEnd = samples.count
        let cityEnd = sampleEnd + cityPoints.count
        let sampleForecasts = Array(forecasts[0..<sampleEnd])
        let cityForecasts = Array(forecasts[sampleEnd..<cityEnd])
        let placeForecasts = Array(forecasts[cityEnd..<forecasts.count])

        return analyse(city: city,
                       samples: samples, sampleForecasts: sampleForecasts,
                       cityPoints: cityPoints, cityForecasts: cityForecasts,
                       placePoints: placePoints, placeForecasts: placeForecasts)
    }

    // MARK: - Nearby bundled towns

    /// All bundled cities, loaded once and cached.
    private func bundledPlaces() -> [CityLocation] {
        bundledLoadLock.lock()
        defer { bundledLoadLock.unlock() }
        if let cached = bundledPlacesCache { return cached }
        var all: [CityLocation] = []
        for resource in ["us-cities-cached", "international-cities-cached"] {
            if let url = Bundle.main.url(forResource: resource, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: [CityLocation]].self, from: data) {
                for arr in decoded.values { all.append(contentsOf: arr) }
            }
        }
        bundledPlacesCache = all
        debugLog("📍 StormApproach loaded \(all.count) bundled places")
        return all
    }

    /// Nearest bundled towns within `placeRadiusKm`, excluding the centre and any saved cities.
    private func nearbyPlaces(around city: City, excluding saved: [City]) -> [CityPoint] {
        let latWindow = placeRadiusKm / 111.0
        let lonWindow = placeRadiusKm / (111.0 * max(0.2, cos(city.latitude * .pi / 180)))
        let savedKeys = Set(saved.map { coordKey($0.latitude, $0.longitude) })

        var result: [CityPoint] = []
        for place in bundledPlaces() {
            guard abs(place.latitude - city.latitude) <= latWindow,
                  abs(place.longitude - city.longitude) <= lonWindow else { continue }
            let d = GeoMath.haversineKm(city.latitude, city.longitude, place.latitude, place.longitude)
            guard d > 1.0, d <= placeRadiusKm else { continue }
            guard !savedKeys.contains(coordKey(place.latitude, place.longitude)) else { continue }
            let bearing = GeoMath.bearingDeg(city.latitude, city.longitude, place.latitude, place.longitude)
            result.append(CityPoint(city: place.toCity(), distanceKm: d, bearing: bearing))
        }
        return Array(result.sorted { $0.distanceKm < $1.distanceKm }.prefix(maxPlaces))
    }

    private func coordKey(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.2f,%.2f", lat, lon)
    }

    // MARK: - Analysis

    private func analyse(city: City,
                         samples: [SamplePoint], sampleForecasts: [PointForecast],
                         cityPoints: [CityPoint], cityForecasts: [PointForecast],
                         placePoints: [CityPoint], placeForecasts: [PointForecast]) -> StormApproach {
        let nowEpoch = Date().timeIntervalSince1970

        // Per-sample series starting at "now" (index 0 == current 15-min step).
        let series: [[Double]] = sampleForecasts.map { extractSeries(from: $0, nowEpoch: nowEpoch) }

        // --- Centre (index 0): are we wet now, and when does it arrive? ---
        let centreSeries = series.first ?? []
        let hereMm = (centreSeries.first ?? 0)
        let hereIntensity = PrecipIntensity(mmPerHour: hereMm * 4)
        let rainingHere = hereMm >= activeThresholdMm

        var arrivalMinutes: Int? = nil
        if !rainingHere {
            for step in 1...horizonSteps where step < centreSeries.count {
                if centreSeries[step] >= activeThresholdMm {
                    arrivalMinutes = step * 15
                    break
                }
            }
        }

        // --- B1: where is the nearest active precipitation right now? ---
        var nearest: (distanceKm: Double, bearing: Double, mm: Double)? = nil
        for (i, sample) in samples.enumerated() where i > 0 {
            let mm = series[i].first ?? 0
            guard mm >= activeThresholdMm else { continue }
            if nearest == nil || sample.distanceKm < nearest!.distanceKm ||
                (sample.distanceKm == nearest!.distanceKm && mm > nearest!.mm) {
                nearest = (sample.distanceKm, sample.bearing, mm)
            }
        }

        // --- B2: estimate field motion by tracking the precipitation-weighted centroid. ---
        let motion = estimateMotion(samples: samples, series: series)

        // --- Situation classification ---
        let situation: StormApproach.Situation
        if rainingHere {
            situation = .rainingHere
        } else if arrivalMinutes != nil {
            situation = .approaching
        } else if nearest != nil {
            situation = .nearbyNotApproaching
        } else {
            situation = .clear
        }

        // --- Part C: saved-city impacts ("your places") ---
        let impacts: [CityImpact] = zip(cityPoints, cityForecasts).map { point, forecast in
            classifyCity(point: point, forecast: forecast, motion: motion, nowEpoch: nowEpoch)
        }

        // --- Nearby bundled towns (named radar-like layer) ---
        let placeImpacts: [PlaceImpact] = zip(placePoints, placeForecasts).map { point, forecast in
            classifyPlace(point: point, forecast: forecast, motion: motion, nowEpoch: nowEpoch)
        }

        return StormApproach(
            situation: situation,
            fromBearing: nearest?.bearing,
            nearestDistanceKm: nearest?.distanceKm,
            nearestIntensity: nearest.map { PrecipIntensity(mmPerHour: $0.mm * 4) } ?? .none,
            hereIntensity: hereIntensity,
            motion: motion,
            arrivalMinutes: arrivalMinutes,
            cityImpacts: impacts,
            placeImpacts: placeImpacts,
            ringRadiusKm: radiiKm.max() ?? 60
        )
    }

    private func classifyPlace(point: CityPoint, forecast: PointForecast,
                               motion: StormMotion?, nowEpoch: TimeInterval) -> PlaceImpact {
        let serie = extractSeries(from: forecast, nowEpoch: nowEpoch)
        let nowMm = serie.first ?? 0
        if nowMm >= activeThresholdMm {
            return PlaceImpact(name: point.city.name, trend: .rainingNow, arrivalMinutes: nil,
                               intensity: PrecipIntensity(mmPerHour: nowMm * 4),
                               distanceKm: point.distanceKm, bearing: point.bearing)
        }
        for step in 1...horizonSteps where step < serie.count {
            if serie[step] >= activeThresholdMm {
                return PlaceImpact(name: point.city.name, trend: .arriving, arrivalMinutes: step * 15,
                                   intensity: PrecipIntensity(mmPerHour: serie[step] * 4),
                                   distanceKm: point.distanceKm, bearing: point.bearing)
            }
        }
        return PlaceImpact(name: point.city.name, trend: .clear, arrivalMinutes: nil,
                           intensity: .none, distanceKm: point.distanceKm, bearing: point.bearing)
    }

    /// Centroid-tracking motion estimate. Compares the precipitation-weighted
    /// centre of mass at two forecast frames 30 minutes apart; the displacement
    /// vector is the field's motion. Returns nil when there isn't enough
    /// precipitation mass, or the result is implausible.
    private func estimateMotion(samples: [SamplePoint], series: [[Double]]) -> StormMotion? {
        // Local east/north offsets (km) for each sample relative to the centre.
        let offsets: [(e: Double, n: Double)] = samples.map { s in
            let r = s.bearing * .pi / 180
            return (e: s.distanceKm * sin(r), n: s.distanceKm * cos(r))
        }

        func centroid(atStep step: Int) -> (e: Double, n: Double)? {
            var sumW = 0.0, sumE = 0.0, sumN = 0.0
            for (i, serie) in series.enumerated() {
                guard step < serie.count else { continue }
                let w = serie[step]
                guard w >= activeThresholdMm else { continue }
                sumW += w
                sumE += w * offsets[i].e
                sumN += w * offsets[i].n
            }
            guard sumW > activeThresholdMm else { return nil }
            return (sumE / sumW, sumN / sumW)
        }

        // Two frames 30 minutes apart (steps 0 and 2) for a steadier vector.
        let step0 = 0, step1 = 2
        guard let c0 = centroid(atStep: step0), let c1 = centroid(atStep: step1) else { return nil }

        let dtHours = Double(step1 - step0) * 0.25   // 0.5 h
        let vE = (c1.e - c0.e) / dtHours
        let vN = (c1.n - c0.n) / dtHours
        let speed = (vE * vE + vN * vN).squareRoot()

        // Reject noise (essentially stationary) and implausible speeds.
        guard speed >= 3, speed <= 130 else { return nil }

        let towardBearing = GeoMath.normalizeDegrees(atan2(vE, vN) * 180 / .pi)
        return StormMotion(towardBearing: towardBearing, speedKmh: speed)
    }

    private func classifyCity(point: CityPoint, forecast: PointForecast,
                              motion: StormMotion?, nowEpoch: TimeInterval) -> CityImpact {
        let serie = extractSeries(from: forecast, nowEpoch: nowEpoch)
        let nowMm = serie.first ?? 0
        if nowMm >= activeThresholdMm {
            return CityImpact(cityName: point.city.name, trend: .rainingNow,
                              arrivalMinutes: nil, intensity: PrecipIntensity(mmPerHour: nowMm * 4))
        }
        // Onset within the horizon (the city's own forecast).
        for step in 1...horizonSteps where step < serie.count {
            if serie[step] >= activeThresholdMm {
                return CityImpact(cityName: point.city.name, trend: .arriving,
                                  arrivalMinutes: step * 15,
                                  intensity: PrecipIntensity(mmPerHour: serie[step] * 4))
            }
        }
        // No onset in its forecast — is the field as a whole tracking toward it?
        if let motion = motion {
            let diff = GeoMath.angularDifference(motion.towardBearing, point.bearing)
            if diff < 60 {
                return CityImpact(cityName: point.city.name, trend: .trackingToward,
                                  arrivalMinutes: nil, intensity: .none)
            }
        }
        return CityImpact(cityName: point.city.name, trend: .clear,
                          arrivalMinutes: nil, intensity: .none)
    }

    /// Extract a precipitation series (mm per 15 min) starting at the current step.
    private func extractSeries(from forecast: PointForecast, nowEpoch: TimeInterval) -> [Double] {
        guard let times = forecast.minutely15?.time,
              let precip = forecast.minutely15?.precipitation,
              !times.isEmpty else { return [] }
        let nowIndex = times.firstIndex(where: { Double($0) >= nowEpoch }) ?? 0
        let slice = precip[nowIndex...]
        return slice.map { $0 ?? 0 }
    }

    // MARK: - Networking

    private func fetchForecasts(coords: [(Double, Double)]) async throws -> [PointForecast] {
        let baseURL = Secrets.openMeteoAPIKey != nil
            ? "https://customer-api.open-meteo.com/v1/forecast"
            : "https://api.open-meteo.com/v1/forecast"

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: coords.map { String($0.0) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: coords.map { String($0.1) }.joined(separator: ",")),
            URLQueryItem(name: "minutely_15", value: "precipitation"),
            URLQueryItem(name: "current", value: "precipitation"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "GMT"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        if let key = Secrets.openMeteoAPIKey, !key.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: key))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("FastWeather/1.5 (weatherfast.online)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RadarError.networkError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Open-Meteo returns a JSON array when multiple coordinates are requested,
        // and a single object when only one is. We always request several, so the
        // array path is expected; fall back to single-object decode defensively.
        if let array = try? decoder.decode([PointForecast].self, from: data) {
            return array
        }
        let single = try decoder.decode(PointForecast.self, from: data)
        return [single]
    }
}

// MARK: - Sampling Types

private struct SamplePoint {
    let lat: Double
    let lon: Double
    let bearing: Double      // relative to centre (centre itself = 0)
    let distanceKm: Double   // 0 for the centre
}

private struct CityPoint {
    let city: City
    let distanceKm: Double
    let bearing: Double      // bearing from centre to this city
}

// MARK: - API Response

private struct PointForecast: Codable {
    let latitude: Double
    let longitude: Double
    let current: PointCurrent?
    let minutely15: PointMinutely?
}

private struct PointCurrent: Codable {
    let time: Int
    let precipitation: Double?
}

private struct PointMinutely: Codable {
    let time: [Int]
    let precipitation: [Double?]
}

// MARK: - Geo Math

enum GeoMath {
    static let earthRadiusKm = 6371.0

    /// Great-circle distance between two coordinates, in kilometres.
    static func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        return earthRadiusKm * 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    }

    /// Destination coordinate given a start, a compass bearing (degrees), and a distance (km).
    static func destination(lat: Double, lon: Double, bearingDeg: Double, distanceKm: Double) -> (Double, Double) {
        let angular = distanceKm / earthRadiusKm
        let theta = bearingDeg * .pi / 180
        let lat1 = lat * .pi / 180
        let lon1 = lon * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(angular) * cos(lat1),
                                cos(angular) - sin(lat1) * sin(lat2))
        return (lat2 * 180 / .pi, lon2 * 180 / .pi)
    }

    /// Initial compass bearing (degrees, 0 = N) from one coordinate to another.
    static func bearingDeg(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let y = sin(dLon) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLon)
        return normalizeDegrees(atan2(y, x) * 180 / .pi)
    }

    /// Normalise an angle to [0, 360).
    static func normalizeDegrees(_ deg: Double) -> Double {
        let m = deg.truncatingRemainder(dividingBy: 360)
        return m < 0 ? m + 360 : m
    }

    /// Smallest absolute difference between two bearings, in [0, 180].
    static func angularDifference(_ a: Double, _ b: Double) -> Double {
        let diff = abs(normalizeDegrees(a) - normalizeDegrees(b)).truncatingRemainder(dividingBy: 360)
        return diff > 180 ? 360 - diff : diff
    }

    /// 8-point compass name for a bearing. Capitalised ("Southwest").
    static func cardinalName(_ bearingDeg: Double) -> String {
        let names = ["North", "Northeast", "East", "Southeast",
                     "South", "Southwest", "West", "Northwest"]
        let index = Int((normalizeDegrees(bearingDeg) / 45).rounded()) % 8
        return names[index]
    }
}

// MARK: - Narration

extension StormApproach {

    /// One concise, plain-language headline for the storm-approach card.
    /// Works equally for VoiceOver and sighted readers; unit-aware.
    func headline(distanceUnit: DistanceUnit, speedUnit: WindSpeedUnit) -> String {
        switch situation {
        case .rainingHere:
            var s = "\(capFirst(hereIntensity.adjective)) precipitation at your location now."
            if let motion = motion {
                s += " The band is moving \(GeoMath.cardinalName(motion.towardBearing).lowercased())" +
                     " at about \(formatSpeed(motion.speedKmh, speedUnit))."
            }
            return s

        case .approaching:
            let dir = fromBearing.map { GeoMath.cardinalName($0).lowercased() } ?? "nearby"
            var s = "\(capFirst(nearestIntensity.adjective)) precipitation to the \(dir)"
            if let d = nearestDistanceKm { s += ", about \(formatDistance(d, distanceUnit)) away" }
            if let a = arrivalMinutes { s += ", reaching you in \(minutesPhrase(a))" }
            s += "."
            if let motion = motion {
                s += " Moving \(GeoMath.cardinalName(motion.towardBearing).lowercased())" +
                     " at about \(formatSpeed(motion.speedKmh, speedUnit))."
            }
            return s

        case .nearbyNotApproaching:
            let dir = fromBearing.map { GeoMath.cardinalName($0).lowercased() } ?? "nearby"
            var s = "\(capFirst(nearestIntensity.adjective)) precipitation to the \(dir)"
            if let d = nearestDistanceKm { s += ", about \(formatDistance(d, distanceUnit)) away" }
            s += ", but it is not heading your way right now."
            return s

        case .clear:
            return "No precipitation within \(formatDistance(ringRadiusKm, distanceUnit)) of you," +
                   " now or in the next 2 hours."
        }
    }

    /// Lines for nearby bundled towns the storm is over or heading for (named
    /// radar-like layer). Only towns with active or arriving precipitation are
    /// listed — dry towns are omitted to keep it concise. Nearest first.
    func placeLines(distanceUnit: DistanceUnit) -> [String] {
        placeImpacts
            .filter { $0.trend == .rainingNow || $0.trend == .arriving }
            .prefix(5)
            .map { impact in
                let dir = GeoMath.cardinalName(impact.bearing).lowercased()
                let dist = formatDistance(impact.distanceKm, distanceUnit)
                switch impact.trend {
                case .rainingNow:
                    let lead = impact.intensity >= .moderate
                        ? "\(capFirst(impact.intensity.adjective)) precipitation"
                        : "Precipitation"
                    return "\(lead) over \(impact.name), \(dist) \(dir)."
                case .arriving:
                    let when = impact.arrivalMinutes.map { minutesPhrase($0) } ?? "soon"
                    return "Reaching \(impact.name) in \(when), \(dist) \(dir)."
                default:
                    return ""
                }
            }
            .filter { !$0.isEmpty }
    }

    /// One line per nearby saved city (Part C). Empty when there are none.
    func cityLines() -> [String] {
        cityImpacts.map { impact in
            switch impact.trend {
            case .rainingNow:
                return "Precipitation now at \(impact.cityName)."
            case .arriving:
                let when = impact.arrivalMinutes.map { minutesPhrase($0) } ?? "soon"
                return "Precipitation reaching \(impact.cityName) in \(when)."
            case .trackingToward:
                return "Storm tracking toward \(impact.cityName)."
            case .clear:
                return "Clear at \(impact.cityName)."
            }
        }
    }

    // MARK: Formatting helpers

    private func capFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    private func formatDistance(_ km: Double, _ unit: DistanceUnit) -> String {
        unit.format(unit.convert(km).rounded())
    }

    private func formatSpeed(_ kmh: Double, _ unit: WindSpeedUnit) -> String {
        "\(Int(unit.convert(kmh).rounded())) \(unit.rawValue)"
    }

    private func minutesPhrase(_ m: Int) -> String {
        if m <= 0 { return "now" }
        if m < 60 { return "about \(m) minutes" }
        let h = m / 60, mm = m % 60
        let hStr = "\(h) hour\(h == 1 ? "" : "s")"
        return mm == 0 ? "about \(hStr)" : "about \(hStr) \(mm) minutes"
    }
}
