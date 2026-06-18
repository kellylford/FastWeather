//
//  RadarMapView.swift
//  Fast Weather
//
//  A free RainViewer radar map drawn as a MapKit tile overlay. For a blind user
//  this is an actual radar IMAGE that VoiceOver image recognition / on-device AI
//  (iOS image descriptions) can describe in a couple of seconds — and it serves
//  as a ground-truth check on Storm Approach's text narration.
//
//  Gated by FeatureFlags.weatherRadarMapEnabled and presented from Weather Around Me.
//

import SwiftUI
import MapKit

/// Wraps an MKMapView with a RainViewer radar tile overlay, centred on a coordinate.
struct RadarTileMapView: UIViewRepresentable {
    let centerLat: Double
    let centerLon: Double
    let cityName: String
    let tileTemplate: String?
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
        context.coordinator.apply(template: tileTemplate, to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.apply(template: tileTemplate, to: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var overlay: MKTileOverlay?
        private var currentTemplate: String?

        func apply(template: String?, to map: MKMapView) {
            guard template != currentTemplate else { return }
            currentTemplate = template
            if let existing = overlay {
                map.removeOverlay(existing)
                overlay = nil
            }
            guard let template = template else { return }
            let tile = MKTileOverlay(urlTemplate: template)
            tile.canReplaceMapContent = false
            map.addOverlay(tile, level: .aboveLabels)
            overlay = tile
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

/// Full-screen radar map with RainViewer attribution and accessibility guidance.
struct RadarMapSheet: View {
    let city: City
    @State private var frame: RainViewerFrame?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading radar…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading radar map")
            } else if failed {
                errorView
            } else {
                RadarTileMapView(centerLat: city.latitude, centerLon: city.longitude,
                                 cityName: city.name, tileTemplate: frame?.urlTemplate)
                    .accessibilityElement()
                    .accessibilityLabel("Weather radar map centered on \(city.name). "
                        + "Use VoiceOver image recognition or on-device AI to describe the radar returns around your location.")

                VStack(spacing: 4) {
                    if let observed = frame?.observedAtText {
                        Text("Radar observed at \(observed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Radar imagery © RainViewer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Radar Map")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            Text("Radar Unavailable")
                .font(.title3).fontWeight(.semibold)
            Text("Couldn't load the radar map right now.")
                .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button(action: { Task { await load() } }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .padding().background(Color.accentColor).foregroundColor(.white).cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radar unavailable. Couldn't load the radar map right now. Tap Try Again to reload.")
    }

    private func load() async {
        isLoading = true
        failed = false
        let result = await RainViewerService.shared.latestRadarFrame()
        await MainActor.run {
            self.frame = result
            self.failed = (result == nil)
            self.isLoading = false
        }
    }
}
