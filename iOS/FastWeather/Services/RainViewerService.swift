//
//  RainViewerService.swift
//  Fast Weather
//
//  Fetches the latest free RainViewer radar frame and builds an MKTileOverlay
//  URL template. RainViewer's public weather-maps endpoint is free for
//  reasonable use; attribution ("RainViewer") is shown wherever tiles appear.
//
//  Used by the radar map (gated by FeatureFlags.weatherRadarMapEnabled), which
//  presents a real radar image VoiceOver image recognition / on-device AI can
//  describe — and which doubles as a ground-truth check on Storm Approach's text.
//

import Foundation

struct RainViewerFrame {
    /// MKTileOverlay URL template with {z}/{x}/{y} placeholders.
    let urlTemplate: String
    /// Human-readable observation time of the frame.
    let observedAtText: String
}

final class RainViewerService {
    static let shared = RainViewerService()
    private init() {}

    /// Fetches the most recent observed radar frame. Returns nil on any failure.
    func latestRadarFrame() async -> RainViewerFrame? {
        guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let maps = try? JSONDecoder().decode(RainViewerMaps.self, from: data)
        else { return nil }

        // Prefer the latest observed past frame; fall back to the first nowcast frame.
        guard let frame = maps.radar?.past?.last ?? maps.radar?.nowcast?.first else { return nil }

        // {host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png
        // color 6 = NEXRAD (the familiar green/yellow/red US radar palette), size 256.
        let template = "\(maps.host)\(frame.path)/256/{z}/{x}/{y}/6/1_1.png"

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let observed = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(frame.time)))

        return RainViewerFrame(urlTemplate: template, observedAtText: observed)
    }
}

// MARK: - API Response

private struct RainViewerMaps: Codable {
    let host: String
    let radar: RadarFrames?

    struct RadarFrames: Codable {
        let past: [Frame]?
        let nowcast: [Frame]?
    }
    struct Frame: Codable {
        let time: Int
        let path: String
    }
}
