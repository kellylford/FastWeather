//
//  MoonCalculator.swift
//  Fast Weather
//
//  Pure Swift moon phase and rise/set calculations.
//  Uses simplified Jean Meeus algorithms — no external dependencies required.
//  Accuracy: phase/illumination ±1%, rise/set ±15 minutes.
//

import Foundation

struct MoonCalculator {

    // MARK: - Constants

    private static let synodicPeriod: Double = 29.530588853  // days

    // MARK: - Public API

    /// Moon phase as a fraction 0.0–1.0.
    /// 0.0 = new moon, 0.25 = first quarter, 0.5 = full moon, 0.75 = last quarter.
    static func phase(for date: Date) -> Double {
        let jd = julianDay(from: date)
        let T = (jd - 2451545.0) / 36525.0

        // Fundamental arguments (degrees)
        let L  = mod360(218.3164477 + 481267.88123421 * T)   // Moon's mean longitude
        let M  = toRad(mod360(134.9633964 + 477198.8675055 * T))  // Moon's mean anomaly
        let F  = toRad(mod360(93.2720950  + 483202.0175233 * T))  // Argument of latitude
        let D  = toRad(mod360(297.8501921 + 445267.1114034 * T))  // Mean elongation
        let Ms = toRad(mod360(357.5291092 + 35999.0502909  * T))  // Sun's mean anomaly

        // Moon's true ecliptic longitude (simplified perturbation terms, ~0.5° accuracy)
        let moonLon = mod360(L
            + 6.2888 * sin(M)
            + 1.2740 * sin(2*D - M)
            + 0.6583 * sin(2*D)
            + 0.2136 * sin(2*M)
            - 0.1851 * sin(Ms)
            - 0.1143 * sin(2*F)
            + 0.0588 * sin(2*D - 2*M)
            + 0.0572 * sin(2*D - Ms - M)
            + 0.0533 * sin(2*D + M)
        )

        // Sun's true ecliptic longitude (simplified, ~1° accuracy)
        let sunLon = mod360(280.46646 + 36000.76983 * T
            + 1.9146 * sin(Ms)
            + 0.0200 * sin(2*Ms))

        // Phase angle = Moon's elongation from the Sun
        var elongation = moonLon - sunLon
        if elongation < 0 { elongation += 360.0 }
        return elongation / 360.0
    }

    /// Illuminated fraction of the Moon's disk, 0–100%.
    static func illumination(for date: Date) -> Double {
        let p = phase(for: date)
        return (1.0 - cos(2.0 * .pi * p)) / 2.0 * 100.0
    }

    /// Human-readable phase name (e.g. "Waxing Gibbous").
    static func phaseName(for date: Date) -> String {
        let p = phase(for: date)
        switch p {
        case 0.000..<0.017:   return "New Moon"
        case 0.017..<0.233:   return "Waxing Crescent"
        case 0.233..<0.267:   return "First Quarter"
        case 0.267..<0.483:   return "Waxing Gibbous"
        case 0.483..<0.517:   return "Full Moon"
        case 0.517..<0.733:   return "Waning Gibbous"
        case 0.733..<0.767:   return "Last Quarter"
        default:              return "Waning Crescent"
        }
    }

    /// SF Symbol name for the current moon phase (requires iOS 16+; FastWeather requires iOS 17+).
    static func phaseSymbol(for date: Date) -> String {
        let p = phase(for: date)
        switch p {
        case 0.000..<0.063:   return "moon.phase.new"
        case 0.063..<0.188:   return "moon.phase.waxing.crescent"
        case 0.188..<0.313:   return "moon.phase.first.quarter"
        case 0.313..<0.438:   return "moon.phase.waxing.gibbous"
        case 0.438..<0.563:   return "moon.phase.full"
        case 0.563..<0.688:   return "moon.phase.waning.gibbous"
        case 0.688..<0.813:   return "moon.phase.last.quarter"
        default:              return "moon.phase.waning.crescent"
        }
    }

    /// Moonrise and moonset times for the given date and observer location.
    /// Returns UTC Date values (caller is responsible for timezone display).
    /// Returns nil if the moon is circumpolar or never rises for that date/location.
    static func riseAndSet(
        for date: Date,
        latitude: Double,
        longitude: Double
    ) -> (rise: Date?, set: Date?) {

        // Work in UTC calendar
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let startOfDayUTC = utcCal.startOfDay(for: date)
        let jd0 = julianDay(from: startOfDayUTC)

        // Moon equatorial position evaluated at noon UTC for the date
        let pos = geocentricEquatorial(jd: jd0 + 0.5)

        // Greenwich Mean Sidereal Time at 0h UT (degrees)
        let gmst0 = siderealTime(jd: jd0)

        let phi = toRad(latitude)
        let dec = toRad(pos.dec)

        // Standard altitude for Moon rising/setting:
        // horizontal parallax (≈57′) × 0.7275 − refraction (34′) ≈ +0.125° above geometric horizon
        let h0 = toRad(0.125)

        let cosH = (sin(h0) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))

        // Guard against circumpolar or never-rises case
        guard cosH >= -1.0 && cosH <= 1.0 else {
            return (nil, nil)
        }

        let H0 = toDeg(acos(cosH))  // semi-diurnal arc in degrees

        // Approximate transit as fraction of day (0..1)
        var transit = (pos.ra - longitude - gmst0) / 360.0
        transit = transit - floor(transit)

        // Rise and set as fractions of day
        var mRise = transit - H0 / 360.0
        var mSet  = transit + H0 / 360.0
        mRise = mRise - floor(mRise)
        mSet  = mSet  - floor(mSet)

        let rise = startOfDayUTC.addingTimeInterval(mRise * 86400.0)
        let set  = startOfDayUTC.addingTimeInterval(mSet  * 86400.0)

        return (rise, set)
    }

    // MARK: - Internal Helpers

    private struct EquatorialCoords {
        let ra:  Double   // right ascension (degrees, 0–360)
        let dec: Double   // declination (degrees)
    }

    /// Moon's apparent geocentric equatorial coordinates (RA, Dec) in degrees.
    private static func geocentricEquatorial(jd: Double) -> EquatorialCoords {
        let T = (jd - 2451545.0) / 36525.0

        let L  = mod360(218.3164477 + 481267.88123421 * T)
        let M  = toRad(mod360(134.9633964 + 477198.8675055 * T))
        let F  = toRad(mod360(93.2720950  + 483202.0175233 * T))
        let D  = toRad(mod360(297.8501921 + 445267.1114034 * T))
        let Ms = toRad(mod360(357.5291092 + 35999.0502909  * T))

        // Ecliptic longitude (degrees)
        let lon = mod360(L
            + 6.2888 * sin(M)
            + 1.2740 * sin(2*D - M)
            + 0.6583 * sin(2*D)
            + 0.2136 * sin(2*M)
            - 0.1851 * sin(Ms)
            - 0.1143 * sin(2*F)
            + 0.0588 * sin(2*D - 2*M)
            + 0.0572 * sin(2*D - Ms - M)
            + 0.0533 * sin(2*D + M)
        )

        // Ecliptic latitude (degrees)
        let lat = 5.1281 * sin(F)
                + 0.2806 * sin(M + F)
                + 0.2777 * sin(M - F)
                + 0.1732 * sin(2*D - F)

        // Obliquity of ecliptic (degrees)
        let eps = toRad(23.4393 - 0.01300 * T)

        let lonRad = toRad(lon)
        let latRad = toRad(lat)

        let ra  = mod360(toDeg(atan2(
            sin(lonRad) * cos(eps) - tan(latRad) * sin(eps),
            cos(lonRad)
        )))
        let dec = toDeg(asin(
            sin(latRad) * cos(eps) + cos(latRad) * sin(eps) * sin(lonRad)
        ))

        return EquatorialCoords(ra: ra, dec: dec)
    }

    /// Greenwich Mean Sidereal Time at 0h UT for the given Julian Day (degrees).
    private static func siderealTime(jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        let theta = 280.46061837
            + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * T * T
            - T * T * T / 38710000.0
        return mod360(theta)
    }

    /// Julian Day Number from a Date.
    private static func julianDay(from date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    private static func toRad(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private static func toDeg(_ radians: Double) -> Double { radians * 180.0 / .pi }
    private static func mod360(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }
}
