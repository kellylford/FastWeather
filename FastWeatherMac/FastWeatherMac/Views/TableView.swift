//
//  TableView.swift
//  FastWeatherMac
//
//  Table view mode for city list with sortable columns
//

import SwiftUI

struct TableView: View {
    let cities: [City]
    @Binding var selectedCity: City?
    @State private var sortOrder = [KeyPathComparator(\City.name)]
    
    var body: some View {
        Table(cities, selection: $selectedCity, sortOrder: $sortOrder) {
            TableColumn("City", value: \.name) { city in
                Text(city.name)
                    .accessibilityLabel(city.displayName)
            }
            
            TableColumn("State/Country") { city in
                Text(city.state ?? city.country ?? "Unknown")
                    .foregroundColor(.secondary)
            }
            
            TableColumn("Location") { city in
                Text(String(format: "%.4f, %.4f", city.latitude, city.longitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityLabel("Cities table")
        .accessibilityHint("\(cities.count) cities. Use arrow keys to navigate, Return to select.")
    }
}
