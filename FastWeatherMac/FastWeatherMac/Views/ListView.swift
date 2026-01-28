//
//  ListView.swift
//  FastWeatherMac
//
//  Compact list view mode for city list
//

import SwiftUI

struct ListView: View {
    let cities: [City]
    @Binding var selectedCity: City?
    
    var body: some View {
        List(cities, selection: $selectedCity) { city in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name)
                        .font(.headline)
                    Text(city.state ?? city.country ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(city.displayName)
            .accessibilityAddTraits(.isButton)
        }
        .accessibilityLabel("Cities list")
        .accessibilityHint("\(cities.count) cities. Use arrow keys to navigate.")
    }
}
