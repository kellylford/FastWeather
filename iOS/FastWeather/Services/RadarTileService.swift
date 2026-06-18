//
//  RadarTileService.swift
//  Fast Weather
//
//  Public-domain US radar tiles for the radar map. Uses NOAA/NWS NEXRAD base
//  reflectivity (N0Q composite) served as web-mercator XYZ tiles by the Iowa
//  Environmental Mesonet (IEM). This is free with no commercial-use restriction
//  (unlike RainViewer's personal/educational-only public API), at the cost of
//  US (CONUS) coverage only.
//
//  No index fetch is needed — the tile template is static and IEM keeps the
//  composite current (~5-minute cache). MapKit fetches the tiles directly.
//

import Foundation

enum RadarTileService {
    /// NWS NEXRAD base reflectivity composite, web-mercator XYZ tiles via IEM.
    /// {z}/{x}/{y} are filled in by MKTileOverlay.
    static let nexradURLTemplate =
        "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png"

    /// IEM serves these tiles well beyond radar's native resolution; cap to keep
    /// requests sane (higher zooms simply upscale).
    static let maximumZoom = 12

    /// Attribution string shown wherever the tiles appear.
    static let attribution = "Radar: NWS NEXRAD via Iowa Environmental Mesonet"

    /// Whether NEXRAD radar covers this location. NEXRAD is a US network, so this
    /// is a coarse country check; outside the US the overlay is simply empty.
    static func coversRadar(country: String) -> Bool {
        country == "United States" || country == "USA"
    }
}
