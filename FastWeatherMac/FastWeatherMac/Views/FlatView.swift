//
//  FlatView.swift
//  FastWeatherMac
//
//  Card-based grid view mode for city list
//

import SwiftUI

struct FlatView: View {
    let cities: [City]
    @Binding var selectedCity: City?
    
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(cities) { city in
                    CityCard(city: city, isSelected: selectedCity?.id == city.id)
                        .onTapGesture {
                            selectedCity = city
                        }
                }
            }
            .padding()
        }
        .accessibilityLabel("Cities grid")
        .accessibilityHint("\(cities.count) cities in grid layout. Click a card to select.")
    }
}

struct CityCard: View {
    let city: City
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(city.state ?? city.country ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(city.displayName)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
