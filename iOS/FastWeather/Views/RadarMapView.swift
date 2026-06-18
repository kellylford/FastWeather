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

/// Full-screen radar map with attribution and accessibility guidance.
struct RadarMapSheet: View {
    let city: City

    private var covered: Bool { RadarTileService.coversRadar(country: city.country) }

    var body: some View {
        VStack(spacing: 0) {
            RadarTileMapView(centerLat: city.latitude, centerLon: city.longitude,
                             cityName: city.name)
                .accessibilityElement()
                .accessibilityLabel(mapAccessibilityLabel)

            VStack(spacing: 4) {
                if !covered {
                    Text("Radar coverage is U.S. only — no radar is shown for this location.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text(RadarTileService.attribution)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Radar Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapAccessibilityLabel: String {
        if covered {
            return "Weather radar map centered on \(city.name). "
                + "Use VoiceOver image recognition or on-device AI to describe the radar returns around your location."
        } else {
            return "Map centered on \(city.name). Radar coverage is United States only, so no radar is shown here."
        }
    }
}
