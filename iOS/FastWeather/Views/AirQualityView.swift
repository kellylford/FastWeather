//
//  AirQualityView.swift
//  Fast Weather
//
//  The Air Quality detail section. Observation-first and alert-aware:
//    - When an official air quality alert is active, it banners the top.
//    - The headline is the observed monitor reading (AirNow) when available;
//      the modeled estimate is never the headline in the US.
//    - The category WORD and health guidance carry the meaning; the color band
//      is decorative and hidden from VoiceOver.
//
//  A failure to fetch shows a distinct "couldn't check" state — never a
//  misleading "Good", mirroring the safety pattern in WeatherAlertsSection.
//

import SwiftUI

struct AirQualitySection: View {
    let city: City
    /// Reuses CityDetailView's alert sheet so the alert banner can open full details.
    @Binding var selectedAlert: WeatherAlert?

    @EnvironmentObject var weatherService: WeatherService
    @State private var data: AirQualityReport?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var hasLoaded = false

    var body: some View {
        GroupBox(label: Label("Air Quality", systemImage: "aqi.medium")) {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView("Checking air quality...")
                        .frame(minHeight: 60)
                        .padding()
                } else if loadFailed {
                    VStack(spacing: 8) {
                        Text("Couldn't check air quality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Try Again") {
                            Task { await load() }
                        }
                        .accessibilityHint("Retries checking the air quality")
                    }
                    .frame(minHeight: 60)
                    .padding()
                } else if let data {
                    content(data)
                }
            }
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .task(id: city.id) {
            guard !hasLoaded else { return }
            await load()
        }
    }

    @ViewBuilder
    private func content(_ data: AirQualityReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Number first (the headline), then the alert detail below it.
            headline(data)
            if let alert = data.activeAlert {
                alertBanner(alert, tint: data.headlineCategory.alertTint)
            }
            Divider()
            pollutantList(data.pollutants)
        }
    }

    // MARK: - Active alert banner (dominates when present)

    private func alertBanner(_ alert: WeatherAlert, tint: Color) -> some View {
        // An active air quality alert always reads as a warning: use a fixed warning
        // icon and the AQI-derived tint, not NWS's severity (which tags these
        // "Unknown" → gray and visually underplays a serious advisory).
        Button(action: { selectedAlert = alert }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(tint)
                        .accessibilityHidden(true)
                    Text(alert.event)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                Text(alert.headline)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active air quality alert. \(alert.event). \(alert.headline)")
        .accessibilityHint("Double tap to read the full alert and safety guidance")
    }

    // MARK: - Headline (number + word + health)

    private func headline(_ data: AirQualityReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(data.headlineAQI)")
                    .font(.system(size: 40, weight: .semibold))
                    .accessibilityHidden(true)
                Text(data.headlineCategory.word)
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(data.headlineCategory.color.opacity(0.18))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    .accessibilityHidden(true)
                Spacer()
                Text(data.isObserved ? "observed · AirNow" : "modeled estimate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            Text(data.headlineCategory.healthGuidance)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            // Reporting-area label: AirNow readings are area-wide (metro), not
            // point-precise — every location in the area shares one number. Show
            // the area so the granularity is honest. Only meaningful when observed.
            if data.isObserved {
                Text("\(data.reportingArea) · area-wide reading")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // One VoiceOver element carrying the full meaning; color/number are hidden above.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            data.accessibilityHeadline
            + (data.isObserved
               ? " Reporting area, \(data.reportingArea), an area-wide reading. Source, observed from AirNow monitors."
               : " Source, modeled estimate.")
        )
    }

    // MARK: - Pollutant breakdown

    private func pollutantList(_ pollutants: [AQIPollutant]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pollutant details")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ForEach(pollutants) { p in
                HStack {
                    Text(p.displayName + (p.isDominant ? " (main pollutant)" : ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("AQI \(p.aqi), \(p.category.word)")
                        .font(.subheadline)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(p.displayName)\(p.isDominant ? ", main pollutant" : ""). "
                    + "Index \(p.aqi), \(p.category.word)."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            // Reuse the app's existing (cached) NWS alert fetch to stay alert-aware.
            // A failure to fetch alerts must not block the card — treat as "no alert".
            let alerts = (try? await weatherService.fetchNWSAlerts(for: city)) ?? []
            let airAlert = AirQualityService.airQualityAlert(in: alerts)
            data = try await AirQualityService.shared.fetchAirQuality(for: city, activeAlert: airAlert)
            isLoading = false
            hasLoaded = true
        } catch {
            isLoading = false
            loadFailed = true
            hasLoaded = true
        }
    }
}
