//
//  RadarMapView.swift
//  Fast Weather
//
//  A free, public-domain radar map drawn as a MapKit tile overlay (NWS NEXRAD
//  via Iowa Environmental Mesonet — see RadarTileService). For a blind user this
//  is an actual radar IMAGE that VoiceOver image recognition / on-device AI
//  (iOS image descriptions) can describe in a couple of seconds — and it serves
//  as a ground-truth check on Storm Approach's text narration.
//
//  Gated by FeatureFlags.weatherRadarMapEnabled and presented from Weather Around Me.
//  Coverage is US (NEXRAD) only; elsewhere the overlay is empty and a note says so.
//

import SwiftUI
import MapKit

/// Wraps an MKMapView with a NEXRAD radar tile overlay, centred on a coordinate.
struct RadarTileMapView: UIViewRepresentable {
    let centerLat: Double
    let centerLon: Double
    let cityName: String
    var spanDegrees: Double = 2.5

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        map.setRegion(
            MKCoordinateRegion(center: center,
                               span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)),
            animated: false
        )
        let pin = MKPointAnnotation()
        pin.coordinate = center
        pin.title = cityName
        map.addAnnotation(pin)
        context.coordinator.addRadarOverlay(to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        func addRadarOverlay(to map: MKMapView) {
            let tile = MKTileOverlay(urlTemplate: RadarTileService.nexradURLTemplate)
            tile.canReplaceMapContent = false
            tile.minimumZ = 1
            tile.maximumZ = RadarTileService.maximumZoom
            map.addOverlay(tile, level: .aboveLabels)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = 0.7
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

/// Full-screen radar map with attribution, AI description, and accessibility guidance.
struct RadarMapSheet: View {
    let city: City

    private var covered: Bool { RadarTileService.coversRadar(country: city.country) }

    // AI description state
    @State private var radarDescription: String?
    @State private var radarImage: UIImage?
    @State private var radarStationId: String?
    @State private var radarStationName: String?
    @State private var isDescribing = false
    @State private var describeError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RadarTileMapView(centerLat: city.latitude, centerLon: city.longitude,
                                 cityName: city.name)
                    .frame(height: 350)
                    .accessibilityElement()
                    .accessibilityLabel(mapAccessibilityLabel)

                VStack(spacing: 12) {
                    if !covered {
                        Text("Radar coverage is U.S. only — no radar is shown for this location.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Describe Radar button
                    if covered {
                        describeRadarButton
                    }

                    // AI description display
                    if let description = radarDescription {
                        radarDescriptionCard(description)
                    }

                    // Radar image (shown when AI has described it, for VoiceOver image recognition)
                    if let image = radarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .accessibilityLabel("NWS radar image from station \(radarStationId ?? "?"). \(description)")
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(RadarTileService.attribution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
            }
        }
        .navigationTitle("Radar Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Describe Radar Button

    private var describeRadarButton: some View {
        Button(action: {
            Task { await fetchRadarDescription() }
        }) {
            HStack {
                if isDescribing {
                    ProgressView()
                    Text("Describing radar…")
                } else {
                    Image(systemName: "text.viewfinder")
                    Text(radarDescription == nil ? "Describe Radar" : "Refresh Description")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDescribing)
        .accessibilityLabel(radarDescription == nil ? "Describe radar image" : "Refresh radar description")
        .accessibilityHint("Downloads the nearest NEXRAD radar image and describes it in text for screen readers.")
    }

    // MARK: - Description Card

    private func radarDescriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cloud.rain.fill")
                Text("Radar Description")
                    .font(.headline)
                Spacer()
            }
            if let sid = radarStationId, let name = radarStationName {
                Text("Station \(sid) — \(name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radar description. \(description)")
    }

    // MARK: - Fetch

    private func fetchRadarDescription() async {
        isDescribing = true
        describeError = nil

        let result = await RadarDescriptionService.shared.describeRadar(for: city)

        await MainActor.run {
            isDescribing = false
            switch result {
            case .success(let description, let image, let stationId, let stationName):
                radarDescription = description
                radarImage = image
                radarStationId = stationId
                radarStationName = stationName
            case .noCoverage:
                describeError = "Radar coverage is U.S. only."
            case .error(let msg):
                describeError = msg
            }
        }
    }

    private var mapAccessibilityLabel: String {
        if covered {
            let base = "Weather radar map centered on \(city.name). "
            if let desc = radarDescription {
                return base + "AI description available: \(desc)"
            }
            return base + "Tap Describe Radar to get a text description of the radar image."
        } else {
            return "Map centered on \(city.name). Radar coverage is United States only, so no radar is shown here."
        }
    }
}
