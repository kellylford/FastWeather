//
//  RadarDescriptionService.swift
//  Fast Weather
//
//  Fetches a NWS RIDGE base-reflectivity radar image for the nearest NEXRAD
//  station and produces a plain-text AI description of what the radar shows.
//
//  This is the app-side implementation of the QuickRadar experiment: it brings
//  the AI image-description track into WeatherFast so a blind user can hear
//  what the radar picture looks like — the spatial picture, storm structure,
//  warning polygons, and precipitation intensity — in plain language.
//
//  Two description backends:
//    1. Foundation Models (iOS 27+): Custom-prompted multimodal description via
//       RadarFoundationModelsService — the model sees the radar image and the
//       QuickRadar prompt together. Gated behind FeatureFlags.
//    2. Fallback: the radar image is presented with a detailed accessibility
//       label so VoiceOver's built-in image recognition can describe it.
//
//  The radar image is fetched from NWS RIDGE (public domain), same as QuickRadar.
//  US coverage only (NEXRAD network).
//

import Foundation
import UIKit

/// Describes a weather radar image in plain text for accessibility.
///
/// This service downloads the nearest NEXRAD station's base-reflectivity image,
/// then either uses Foundation Models (when the flag is on) for a custom-
/// prompted on-device description, or falls back to an image-only accessibility
/// label.
class RadarDescriptionService {
    static let shared = RadarDescriptionService()
    private init() {}

    // MARK: - Types

    /// Result of a radar description request.
    enum DescriptionResult {
        case success(description: String, image: UIImage, stationId: String, stationName: String)
        case noCoverage
        case error(String)
    }

    // MARK: - Public

    /// Fetch and describe the radar image for a location.
    ///
    /// When `FeatureFlags.foundationModelsRadarEnabled` is on, this routes to
    /// `RadarFoundationModelsService` for a custom-prompted on-device multimodal
    /// description (iOS 27+ with Apple Intelligence). Otherwise it uses the
    /// image-only fallback — the radar image is shown with an accessibility
    /// label so VoiceOver's built-in image recognition can describe it.
    func describeRadar(for city: City) async -> DescriptionResult {
        // Route to the Foundation Models path when the flag is on.
        if RadarFoundationModelsService.shared.isAvailable {
            let result = await RadarFoundationModelsService.shared.describeRadar(for: city)
            return bridgeFoundationModelsResult(result)
        }

        // 1. US coverage check
        guard RadarTileService.coversRadar(country: city.country) else {
            return .noCoverage
        }

        // 2. Find nearest NEXRAD station
        guard let station = await findNearestNexradStation(lat: city.latitude,
                                                           lon: city.longitude) else {
            return .error("Could not find a nearby NEXRAD radar station.")
        }

        // 3. Download the radar image
        guard let image = await downloadRadarImage(stationId: station.id) else {
            return .error("Could not download the radar image for station \(station.id).")
        }

        // 4. Describe the image — image-only fallback.
        // The radar image is shown with an accessibility label. VoiceOver's
        // built-in image recognition can describe it natively on iOS 27+.
        // For a custom-prompted AI description, enable Foundation Models in
        // Developer Settings.
        let description = describeFromImageOnly(image: image)

        return .success(description: description, image: image,
                        stationId: station.id, stationName: station.name)
    }

    /// Bridge a FoundationModelsRadarResult to the legacy DescriptionResult.
    /// The structured/movement results are flattened to a text description so
    /// the existing UI (RadarMapSheet, WeatherAroundMeView) works unchanged.
    /// Callers that want the structured analysis can call
    /// RadarFoundationModelsService directly.
    private func bridgeFoundationModelsResult(
        _ result: FoundationModelsRadarResult
    ) -> DescriptionResult {
        switch result {
        case .text(let description, let image, let stationId, let stationName):
            return .success(description: description, image: image,
                            stationId: stationId, stationName: stationName)
        case .structured(let analysis, let image, let stationId, let stationName):
            return .success(description: analysis.description, image: image,
                            stationId: stationId, stationName: stationName)
        case .movement(let analysis, _, let lastFrame, let stationId, let stationName):
            // For the legacy bridge, use the last frame as the display image.
            return .success(description: analysis.description, image: lastFrame,
                            stationId: stationId, stationName: stationName)
        case .noCoverage:
            return .noCoverage
        case .unavailable(let msg):
            // Fall back to the Vision path if Foundation Models isn't available
            // at runtime even though the flag is on.
            debugLog("ℹ️ Foundation Models unavailable: \(msg) — falling back to Vision.")
            return .error(msg)
        case .error(let msg):
            return .error(msg)
        }
    }

    // MARK: - NEXRAD Station Lookup

    private struct RadarStation {
        let id: String
        let name: String
        let lat: Double
        let lon: Double
        let distanceKm: Double
    }

    /// Public bridge for RadarFoundationModelsService.
    func findNearestStation(lat: Double, lon: Double) async -> RadarStationInfo? {
        guard let s = await findNearestNexradStation(lat: lat, lon: lon) else { return nil }
        return RadarStationInfo(id: s.id, name: s.name, lat: s.lat, lon: s.lon,
                                distanceKm: s.distanceKm)
    }

    /// Public bridge for RadarFoundationModelsService.
    func downloadImage(stationId: String) async -> UIImage? {
        await downloadRadarImage(stationId: stationId)
    }

    /// Download the NWS RIDGE animated loop GIF and extract the first and last
    /// frames as UIImages. Used by the two-frame movement detection feature.
    /// Returns nil if the loop can't be downloaded or has fewer than 2 frames.
    func downloadLoopFrames(stationId: String) async -> [UIImage]? {
        let sid = stationId.uppercased()
        let candidates = [
            "https://radar.weather.gov/ridge/standard/\(sid)_loop.gif",
            "https://radar.weather.gov/ridge/standard/\(sid.lowercased())_loop.gif",
        ]

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.setValue("WeatherFast/1.5 (weatherfast.online)",
                            forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count > 1000 else { continue }

            // Extract frames from the animated GIF.
            return extractGIFFrames(data: data)
        }
        return nil
    }

    /// Extract the first and last frames from an animated GIF as UIImages.
    private func extractGIFFrames(data: Data) -> [UIImage]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let count = CGImageSourceGetCount(source)
        guard count >= 2 else { return nil }

        var frames: [UIImage] = []
        // First and last frames only — the QuickRadar experiment showed these
        // are ~1 hour apart and sufficient for movement inference.
        let indices = [0, count - 1]
        for i in indices {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            frames.append(UIImage(cgImage: cgImage))
        }
        return frames.count >= 2 ? frames : nil
    }

    private func findNearestNexradStation(lat: Double, lon: Double) async -> RadarStation? {
        let url = URL(string: "https://api.weather.gov/radar/stations")!
        var request = URLRequest(url: url)
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.setValue("WeatherFast/1.5 (weatherfast.online)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return nil
        }

        var best: RadarStation?
        var bestDist: Double = .infinity

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let coords = geometry["coordinates"] as? [Double],
                  coords.count >= 2 else { continue }
            guard let props = feature["properties"] as? [String: Any],
                  let sid = props["id"] as? String else { continue }

            // Only NEXRAD WSR-88D stations (K-prefixed) have RIDGE images.
            guard sid.uppercased().hasPrefix("K") else { continue }

            let stLat = coords[1]
            let stLon = coords[0]
            let dist = haversineKm(lat1: lat, lon1: lon, lat2: stLat, lon2: stLon)

            if dist < bestDist {
                bestDist = dist
                let name = props["name"] as? String ?? "Unknown"
                best = RadarStation(id: sid.uppercased(), name: name,
                                    lat: stLat, lon: stLon, distanceKm: dist)
            }
        }

        return best
    }

    // MARK: - Radar Image Download

    private func downloadRadarImage(stationId: String) async -> UIImage? {
        let sid = stationId.uppercased()
        let candidates = [
            "https://radar.weather.gov/ridge/standard/\(sid)_0.gif",
            "https://radar.weather.gov/ridge/standard/\(sid.lowercased())_0.gif",
        ]

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.setValue("WeatherFast/1.5 (weatherfast.online)",
                            forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count > 1000 else { continue }
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: - Fallback: Image-Only Description

    /// When no on-device AI is available, return a prompt-style description
    /// that tells the user what the image is and how to get more info.
    private func describeFromImageOnly(image: UIImage) -> String {
        // The image itself will be shown with this label; VoiceOver on iOS 27+
        // can describe it natively. For a custom-prompted AI description,
        // enable Foundation Models in Developer Settings.
        return "Weather radar image. VoiceOver can describe this image for you. " +
               "The radar shows precipitation intensity around your location, " +
               "with green indicating light precipitation, yellow moderate, " +
               "and red heavy precipitation. For a detailed AI description, " +
               "enable Foundation Models Radar in Developer Settings."
    }

    // MARK: - Geo Math

    private func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        return 2 * R * asin(sqrt(a))
    }
}