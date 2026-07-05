//
//  AlertBrowserService.swift
//  Fast Weather
//
//  Browse active government weather alerts independent of any saved city.
//  Aggregates multiple national alerting authorities into the shared
//  WeatherAlert model so the existing AlertDetailView can render them.
//
//  Sources:
//    - United States: NWS  (api.weather.gov/alerts/active)  — CAP GeoJSON
//    - Canada:        ECCC (api.weather.gc.ca weather-alerts) — OGC API features
//    - Europe:        MeteoAlarm per-country CAP feeds
//
//  All three expose the Common Alerting Protocol fields (event / severity /
//  urgency / area / expires), which map cleanly onto WeatherAlert.
//

import Foundation

// MARK: - Region model

/// A top-level entry in the alert browser: one national alerting authority
/// (or a single MeteoAlarm country). Hashable so it can ride in the Browse
/// navigation stack's BrowseDestination enum.
struct AlertRegion: Hashable, Identifiable {
    enum Provider: Hashable {
        case nws                      // United States
        case eccc                     // Canada
        case meteoAlarm(slug: String) // Europe, per-country ("italy", "germany", …)
    }

    let id: String
    let displayName: String
    let systemImage: String
    let provider: Provider

    /// Only NWS distinguishes land vs. marine cleanly enough to offer the toggle.
    var supportsLandMarineFilter: Bool {
        if case .nws = provider { return true }
        return false
    }

    // North America — direct entries.
    static let unitedStates = AlertRegion(id: "us-nws", displayName: "United States",
                                          systemImage: "flag.fill", provider: .nws)
    static let canada = AlertRegion(id: "ca-eccc", displayName: "Canada",
                                    systemImage: "leaf.fill", provider: .eccc)

    static let northAmerica: [AlertRegion] = [.unitedStates, .canada]

    /// MeteoAlarm member countries we surface. Slug is the English name the
    /// feeds API expects: feeds.meteoalarm.org/api/v1/warnings/feeds-<slug>
    static let meteoAlarmCountries: [AlertRegion] = [
        ("Austria", "austria"), ("Belgium", "belgium"),
        ("Bosnia and Herzegovina", "bosnia-herzegovina"), ("Bulgaria", "bulgaria"),
        ("Croatia", "croatia"), ("Cyprus", "cyprus"), ("Czechia", "czechia"),
        ("Denmark", "denmark"), ("Estonia", "estonia"), ("Finland", "finland"),
        ("France", "france"), ("Germany", "germany"), ("Greece", "greece"),
        ("Hungary", "hungary"), ("Iceland", "iceland"), ("Ireland", "ireland"),
        ("Israel", "israel"), ("Italy", "italy"), ("Latvia", "latvia"),
        ("Lithuania", "lithuania"), ("Luxembourg", "luxembourg"), ("Malta", "malta"),
        ("Moldova", "moldova"), ("Montenegro", "montenegro"),
        ("Netherlands", "netherlands"), ("Norway", "norway"), ("Poland", "poland"),
        ("Portugal", "portugal"), ("Romania", "romania"), ("Serbia", "serbia"),
        ("Slovakia", "slovakia"), ("Slovenia", "slovenia"), ("Spain", "spain"),
        ("Sweden", "sweden"), ("Switzerland", "switzerland"),
        ("United Kingdom", "united-kingdom")
    ].map { name, slug in
        AlertRegion(id: "ma-\(slug)", displayName: name,
                    systemImage: "globe.europe.africa.fill", provider: .meteoAlarm(slug: slug))
    }
}

// MARK: - Severity filter

/// Exclusive severity filter: each level shows ONLY that severity. Only `all`
/// is inclusive (every alert, including Minor Small Craft Advisories and
/// Unknown-severity Air Quality). Picking "Moderate" shows moderate alerts only.
enum SeverityFilter: String, CaseIterable, Identifiable {
    case extremeOnly = "Extreme"
    case severe = "Severe"
    case moderate = "Moderate"
    case all = "All"

    var id: String { rawValue }

    func includes(_ severity: AlertSeverity) -> Bool {
        switch self {
        case .extremeOnly: return severity == .extreme
        case .severe:      return severity == .severe
        case .moderate:    return severity == .moderate
        case .all:         return true
        }
    }
}

// MARK: - Hazard type filter

/// A hazard family, derived from the event name, so alerts can be filtered by
/// what kind of weather they're about (independent of severity). "Storms"
/// gathers tornado / thunderstorm / severe-weather products that NWS otherwise
/// scatters across Extreme (Tornado Warning), Severe (Svr Thunderstorm) and
/// Moderate (watches).
enum HazardType: String, CaseIterable, Identifiable {
    case storms = "Storms"
    case tropical = "Tropical"
    case flood = "Flooding"
    case heat = "Heat"
    case winter = "Winter"
    case wind = "Wind"
    case fire = "Fire"
    case fog = "Fog"
    case marine = "Marine & Coastal"
    case airQuality = "Air Quality"
    case other = "Other"

    var id: String { rawValue }

    /// Classify an event name into exactly one family (first match wins).
    static func classify(_ event: String) -> HazardType {
        let e = event.lowercased()
        func any(_ needles: [String]) -> Bool { needles.contains { e.contains($0) } }

        if any(["hurricane", "tropical", "typhoon", "storm surge"]) { return .tropical }
        if any(["tornado", "thunderstorm", "severe weather", "special weather statement"]) { return .storms }
        if any(["flood", "hydrologic", "seiche"]) { return .flood }
        if any(["winter", "snow", "blizzard", "ice storm", "freez", "frost", "wind chill", "sleet", "cold", "avalanche"]) { return .winter }
        if any(["fire", "red flag"]) { return .fire }
        if any(["air quality", "air stagnation", "ozone", "dust", "ashfall", "smoke"]) { return .airQuality }
        if any(["heat"]) { return .heat }
        if any(["fog"]) { return .fog }
        if any(["wind", "gale"]) { return .wind }
        if any(["marine", "small craft", "seas", "surf", "rip current", "beach", "coastal", "tsunami", "low water", "ashore"]) { return .marine }
        return .other
    }
}

// MARK: - Digest grouping

/// One collapsed row in the national digest: all active alerts that share an
/// event type + severity (e.g. every "Flood Warning"), so 29 county-level
/// products read as a single scannable line.
struct AlertDigestGroup: Identifiable {
    let id: String
    let event: String
    let severity: AlertSeverity
    let alerts: [WeatherAlert]

    var count: Int { alerts.count }
    var soonestExpires: Date? { alerts.map(\.expires).min() }
}

// MARK: - Service

@MainActor
final class AlertBrowserService: ObservableObject {

    enum LoadState {
        case idle
        case loading
        case loaded([WeatherAlert])
        case failed(String)
    }

    private let session: URLSession
    private let userAgent = "WeatherFast/1.0 iOS (weatherfast.online)"

    // Short-lived per-region count cache so re-opening the country list (or
    // navigating back and forth) doesn't refetch every feed. Courtesy to the
    // free MeteoAlarm service; these feeds cost nothing and no API key.
    private var countCache: [String: (count: Int, at: Date)] = [:]
    private let countTTL: TimeInterval = 300  // 5 minutes

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Number of active alerts for a region, cached for `countTTL`.
    /// Returns nil if the fetch fails (so the UI can stay quiet rather than
    /// showing a misleading zero).
    func alertCount(for region: AlertRegion) async -> Int? {
        if let hit = countCache[region.id], Date().timeIntervalSince(hit.at) < countTTL {
            return hit.count
        }
        do {
            let count = try await fetchAlerts(for: region, landOnly: false).count
            countCache[region.id] = (count, Date())
            return count
        } catch {
            return nil
        }
    }

    // MARK: Fetch

    /// Fetch all currently active alerts for a region, normalized to WeatherAlert.
    /// `landOnly` applies to NWS only (drops Small Craft Advisories & marine noise).
    func fetchAlerts(for region: AlertRegion, landOnly: Bool = true) async throws -> [WeatherAlert] {
        switch region.provider {
        case .nws:
            return try await fetchNWS(landOnly: landOnly)
        case .eccc:
            return try await fetchECCC()
        case .meteoAlarm(let slug):
            return try await fetchMeteoAlarm(slug: slug)
        }
    }

    /// Collapse a flat alert list into severity-sorted, event-collapsed groups,
    /// filtered to the given severity floor.
    func digest(from alerts: [WeatherAlert], filter: SeverityFilter) -> [AlertDigestGroup] {
        let kept = alerts.filter { filter.includes($0.severity) }
        let grouped = Dictionary(grouping: kept) { alert in
            "\(alert.severity.rawValue)|\(alert.event)"
        }
        return grouped.map { key, group in
            AlertDigestGroup(
                id: key,
                event: group[0].event,
                severity: group[0].severity,
                alerts: group.sorted { ($0.expires) < ($1.expires) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.severity.sortOrder != rhs.severity.sortOrder {
                return lhs.severity.sortOrder < rhs.severity.sortOrder   // extreme first
            }
            if lhs.count != rhs.count { return lhs.count > rhs.count }    // biggest first
            return lhs.event < rhs.event
        }
    }

    /// Severity histogram across the whole loaded set (for the summary header).
    func severityCounts(_ alerts: [WeatherAlert]) -> [(AlertSeverity, Int)] {
        AlertSeverity.allCases.compactMap { sev in
            let n = alerts.filter { $0.severity == sev }.count
            return n > 0 ? (sev, n) : nil
        }
    }

    // MARK: Networking helper

    private func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 25)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func fetchData(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: request(url))
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            AppLogger.network.error("Alert browser fetch \(url.absoluteString, privacy: .public) → HTTP \(http.statusCode)")
            throw URLError(.badServerResponse)
        }
        return data
    }

    // Shared ISO8601 parser (allocated once per call; fractional + plain).
    private static func parseISO(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// Give a real severity to products NWS tags "Unknown". Air Quality Alerts
    /// carry Unknown severity but are advisory-grade, so we surface them as
    /// Moderate rather than stranding them in an "Unknown" bucket.
    private static func normalizedSeverity(_ raw: AlertSeverity, event: String) -> AlertSeverity {
        guard raw == .unknown else { return raw }
        let e = event.lowercased()
        if e.contains("air quality") { return .moderate }
        return raw
    }

    // MARK: NWS (United States)

    private func fetchNWS(landOnly: Bool) async throws -> [WeatherAlert] {
        // Note: /alerts/active returns all active alerts and does NOT accept a
        // "limit" query parameter — sending one yields HTTP 400.
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")!
        var items = [URLQueryItem(name: "status", value: "actual")]
        if landOnly { items.append(URLQueryItem(name: "region_type", value: "land")) }
        components.queryItems = items

        let data = try await fetchData(components.url!)
        let decoded = try JSONDecoder().decode(NWSAlertsResponse.self, from: data)

        return decoded.features.compactMap { feature -> WeatherAlert? in
            let p = feature.properties
            let expires = Self.parseISO(p.ends) ?? Self.parseISO(p.expires)
            guard let expires else { return nil }
            let onset = Self.parseISO(p.onset) ?? Date()
            let rawSeverity = AlertSeverity(rawValue: p.severity ?? "Unknown") ?? .unknown
            return WeatherAlert(
                id: p.id,
                event: p.event,
                severity: Self.normalizedSeverity(rawSeverity, event: p.event),
                headline: p.headline,
                description: p.description,
                instruction: p.instruction,
                onset: onset,
                expires: expires,
                areaDesc: p.areaDesc,
                source: .nws,
                detailsURL: nil
            )
        }
    }

    // MARK: ECCC (Canada)

    private func fetchECCC() async throws -> [WeatherAlert] {
        let url = URL(string: "https://api.weather.gc.ca/collections/weather-alerts/items?f=json&limit=500")!
        let data = try await fetchData(url)
        let decoded = try JSONDecoder().decode(ECCCAlertsResponse.self, from: data)

        return decoded.features.compactMap { feature -> WeatherAlert? in
            let p = feature.properties
            guard let expires = Self.parseISO(p.expiration_datetime) else { return nil }
            let onset = Self.parseISO(p.publication_datetime) ?? Date()
            let area = [p.feature_name_en, p.province].compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            let event = p.alert_name_en?.capitalizedFirst ?? "Weather Alert"
            return WeatherAlert(
                id: p.id,
                event: event,
                severity: Self.severityForECCC(type: p.alert_type, colour: p.risk_colour_en),
                headline: [p.alert_short_name_en, p.status_en].compactMap { $0 }.joined(separator: " · "),
                description: p.alert_text_en ?? "",
                instruction: nil,
                onset: onset,
                expires: expires,
                areaDesc: area.isEmpty ? nil : area,
                source: .eccc,
                detailsURL: "https://weather.gc.ca/warnings/index_e.html"
            )
        }
    }

    private static func severityForECCC(type: String?, colour: String?) -> AlertSeverity {
        // ECCC risk colours map to hazard level; fall back to the alert type.
        switch colour?.lowercased() {
        case "red": return .extreme
        case "orange": return .severe
        case "yellow": return .moderate
        case "grey", "gray", "green": return .minor
        default: break
        }
        switch type?.lowercased() {
        case "warning": return .severe
        case "watch": return .moderate
        case "advisory", "statement": return .minor
        default: return .unknown
        }
    }

    /// Some MeteoAlarm members (notably Austria) supply glued English event
    /// names like "Heatwarning" / "Thunderstormwarning" — the German compound
    /// translated without a space. Insert the missing space before "warning".
    private static func tidyEventName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "([a-z])([Ww]arning)",
                                 with: "$1 $2",
                                 options: .regularExpression)
    }

    // MARK: MeteoAlarm (Europe)

    private func fetchMeteoAlarm(slug: String) async throws -> [WeatherAlert] {
        let url = URL(string: "https://feeds.meteoalarm.org/api/v1/warnings/feeds-\(slug)")!
        let data = try await fetchData(url)
        let decoded = try JSONDecoder().decode(MeteoAlarmResponse.self, from: data)

        var alerts: [WeatherAlert] = []
        for (index, warning) in decoded.warnings.enumerated() {
            // Prefer the English CAP <info>; else the first available language.
            let infos = warning.alert.info
            guard let info = infos.first(where: { ($0.language ?? "").lowercased().hasPrefix("en") }) ?? infos.first
            else { continue }
            guard let expires = Self.parseISO(info.expires) else { continue }
            let onset = Self.parseISO(info.onset) ?? Self.parseISO(info.effective) ?? Date()
            let severity = AlertSeverity(rawValue: (info.severity ?? "Unknown").capitalizedFirst) ?? .unknown
            let area = info.area?.compactMap { $0.areaDesc }.joined(separator: ", ")
            alerts.append(WeatherAlert(
                id: warning.alert.identifier ?? "meteoalarm-\(slug)-\(index)",
                event: Self.tidyEventName(info.event ?? info.headline ?? "Weather Warning"),
                severity: severity,
                headline: info.headline ?? "",
                description: info.description ?? "",
                instruction: info.instruction,
                onset: onset,
                expires: expires,
                areaDesc: (area?.isEmpty ?? true) ? nil : area,
                source: .meteoalarm,
                detailsURL: info.web
            ))
        }
        return alerts
    }
}

// MARK: - ECCC decoding

private struct ECCCAlertsResponse: Codable {
    let features: [ECCCFeature]
}

private struct ECCCFeature: Codable {
    let properties: ECCCProperties
}

private struct ECCCProperties: Codable {
    let id: String
    let alert_type: String?
    let alert_name_en: String?
    let alert_short_name_en: String?
    let publication_datetime: String?
    let expiration_datetime: String?
    let alert_text_en: String?
    let risk_colour_en: String?
    let feature_name_en: String?
    let province: String?
    let status_en: String?
}

// MARK: - MeteoAlarm decoding

private struct MeteoAlarmResponse: Codable {
    let warnings: [MeteoAlarmWarning]
}

private struct MeteoAlarmWarning: Codable {
    let alert: MeteoAlarmAlert
}

private struct MeteoAlarmAlert: Codable {
    let identifier: String?
    let info: [MeteoAlarmInfo]
}

private struct MeteoAlarmInfo: Codable {
    let language: String?
    let event: String?
    let headline: String?
    let description: String?
    let instruction: String?
    let severity: String?
    let onset: String?
    let effective: String?
    let expires: String?
    let web: String?
    let area: [MeteoAlarmArea]?
}

private struct MeteoAlarmArea: Codable {
    let areaDesc: String?
}

// MARK: - Small helper

private extension String {
    /// "air quality warning" → "Air quality warning" (leaves the rest as-is,
    /// preserving screen-reader-friendly raw casing).
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
