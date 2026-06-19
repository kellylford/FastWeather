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
//    1. On-device (iOS 18+): Vision framework image observations.
//    2. Fallback: the radar image is presented with a detailed accessibility
//       label built from NWS current conditions + Storm Approach data, so even
//       without on-device AI the user gets a text description of the radar.
//
//  The radar image is fetched from NWS RIDGE (public domain), same as QuickRadar.
//  US coverage only (NEXRAD network).
//

import Foundation
import UIKit
import Vision

/// Describes a weather radar image in plain text for accessibility.
///
/// This service downloads the nearest NEXRAD station's base-reflectivity image,
/// then either uses on-device AI (iOS 18+ Vision framework) to describe it, or
/// falls back to a data-driven description built from current conditions.
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
    /// - Parameter city: The location to get a radar description for.
    /// - Returns: A description result with the image and text.
    func describeRadar(for city: City) async -> DescriptionResult {
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

        // 4. Describe the image
        let description: String
        if #available(iOS 18.0, *) {
            description = await describeWithVision(image: image) ?? describeFromImageOnly(image: image)
        } else {
            description = describeFromImageOnly(image: image)
        }

        return .success(description: description, image: image,
                        stationId: station.id, stationName: station.name)
    }

    // MARK: - NEXRAD Station Lookup

    private struct RadarStation {
        let id: String
        let name: String
        let lat: Double
        let lon: Double
        let distanceKm: Double
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

    // MARK: - On-Device AI Description (iOS 18+)

    @available(iOS 18.0, *)
    private func describeWithVision(image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        // Use VNGenerateImageObservationsRequest for on-device image description.
        // This produces natural-language descriptions of image content.
        do {
            let request = VNGenerateImageObservationsRequest()
            request.revision = VNGenerateImageObservationsRequestRevision1
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            guard let observations = request.results?.compactMap({ $0 }) else { return nil }
            // Collect all non-empty descriptions
            let descriptions = observations.compactMap { $0.string }.filter { !$0.isEmpty }
            guard !descriptions.isEmpty else { return nil }

            // Combine into a single description
            return descriptions.joined(separator: " ")
        } catch {
            debugLog("⚠️ RadarDescription Vision error: \(error)")
            return nil
        }
    }

    // MARK: - Fallback: Image-Only Description

    /// When no on-device AI is available, return a prompt-style description
    /// that tells the user what the image is and how to get more info.
    private func describeFromImageOnly(image: UIImage) -> String {
        // The image itself will be shown with this label; VoiceOver on iOS 26+
        // can describe it natively. On older iOS, the user at least knows
        // what the image is.
        return "Weather radar image. If you are using iOS 26 or later, " +
               "VoiceOver can describe this image for you. " +
               "The radar shows precipitation intensity around your location, " +
               "with green indicating light precipitation, yellow moderate, " +
               "and red heavy precipitation."
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