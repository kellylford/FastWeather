//
//  AlertDetailView.swift
//  Fast Weather
//
//  Detailed view for severe weather alerts
//

import SwiftUI

struct AlertDetailView: View {
    let alert: WeatherAlert
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Severity indicator
                    HStack(spacing: 12) {
                        Image(systemName: alert.severity.iconName)
                            .font(.largeTitle)
                            .foregroundColor(alert.severity.color)
                            .accessibilityHidden(true)
                        
                        Text(alert.severity.rawValue.uppercased())
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("\(alert.severity.rawValue) severity")
                    }
                    
                    // Event and headline
                    VStack(alignment: .leading, spacing: 8) {
                        Text(alert.event)
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(alert.headline)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(alert.description)
                            .font(.body)
                    }
                    
                    // Instructions (if available)
                    if let instruction = alert.instruction, !instruction.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Safety Instructions")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(instruction)
                                .font(.body)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Affected areas
                    if let areas = alert.areaDesc, !areas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Affected Areas")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(areas)
                                .font(.body)
                        }
                    }
                    
                    // Time validity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Valid Period")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("From: \(formatFullDate(alert.onset))")
                        Text("Until: \(formatFullDate(alert.expires))")
                    }
                    
                    // Link to official source
                    Link(destination: URL(string: "https://www.weather.gov")!) {
                        Label("View on Weather.gov", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityHint("Opens Safari to view official National Weather Service alert information")
                }
            .padding()
        }
        .navigationTitle("Weather Alert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityHint("Dismisses weather alert")
            }
        }
        } // End NavigationStack
    } // End body
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
