//
//  AlertBrowserView.swift
//  Fast Weather
//
//  Browse active government weather alerts independent of any saved city.
//  Top level is by service/country; each region opens a scannable "national
//  digest" that collapses duplicate products by event type.
//

import SwiftUI

// MARK: - Region picker (top level)

/// Lists the alerting authorities. Pushed from the Browse tab. Uses the
/// parent BrowseCitiesView navigation stack via the shared navPath binding.
struct AlertRegionsView: View {
    @Binding var navPath: [BrowseDestination]

    var body: some View {
        List {
            Section(header: Text("North America")) {
                ForEach(AlertRegion.northAmerica) { region in
                    regionButton(region)
                }
            }

            Section(header: Text("Europe"),
                    footer: Text("MeteoAlarm aggregates the national weather services of its member countries.")) {
                Button {
                    navPath.append(.alertMeteoAlarmCountries)
                } label: {
                    Label("Europe (MeteoAlarm)", systemImage: "globe.europe.africa.fill")
                        .foregroundColor(.primary)
                }
                .accessibilityHint("Double tap to choose a European country")
            }
        }
        .navigationTitle("Browse Alerts")
    }

    private func regionButton(_ region: AlertRegion) -> some View {
        Button {
            navPath.append(.alertDigest(region))
        } label: {
            Label(region.displayName, systemImage: region.systemImage)
                .foregroundColor(.primary)
        }
        .accessibilityHint("Double tap to view active alerts for \(region.displayName)")
    }
}

// MARK: - MeteoAlarm country list

struct AlertMeteoAlarmCountriesView: View {
    @Binding var navPath: [BrowseDestination]
    @State private var searchText = ""

    private var filtered: [AlertRegion] {
        searchText.isEmpty ? AlertRegion.meteoAlarmCountries :
            AlertRegion.meteoAlarmCountries.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        List {
            ForEach(filtered) { region in
                Button {
                    navPath.append(.alertDigest(region))
                } label: {
                    Text(region.displayName).foregroundColor(.primary)
                }
                .accessibilityHint("Double tap to view active alerts for \(region.displayName)")
            }
        }
        .navigationTitle("Europe")
        .searchable(text: $searchText, prompt: "Search countries")
    }
}

// MARK: - National digest

struct NationalAlertDigestView: View {
    let region: AlertRegion

    @StateObject private var service = AlertBrowserService()
    @State private var state: AlertBrowserService.LoadState = .idle
    @State private var selectedAlert: WeatherAlert?

    var body: some View {
        List {
            switch state {
            case .idle, .loading:
                loadingRow
            case .failed(let message):
                failureRow(message)
            case .loaded(let alerts):
                loadedContent(alerts)
            }
        }
        .navigationTitle(region.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: region.id) { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
    }

    // MARK: States

    private var loadingRow: some View {
        HStack {
            ProgressView()
            Text("Loading active alerts…")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading active alerts")
    }

    private func failureRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Couldn't load alerts")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Try Again") { Task { await load() } }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Reloads active alerts for \(region.displayName)")
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func loadedContent(_ alerts: [WeatherAlert]) -> some View {
        // No filtering: show every active alert, grouped by severity.
        let groups = service.digest(from: alerts, filter: .all)
        if groups.isEmpty {
            Section {
                Text("No active alerts right now.")
                    .foregroundColor(.secondary)
            }
        } else {
            ForEach(groupsBySeverity(groups), id: \.0) { severity, sevGroups in
                let sevCount = sevGroups.reduce(0) { $0 + $1.count }
                Section(header: severityHeader(severity, count: sevCount)) {
                    ForEach(sevGroups) { group in
                        groupRow(group)
                    }
                }
            }
        }
    }

    /// Severity section header carrying its total count, e.g. "Extreme (3)".
    /// VoiceOver reads "Extreme, 3 alerts" as a heading.
    private func severityHeader(_ severity: AlertSeverity, count: Int) -> some View {
        HStack {
            Text(severity.rawValue)
            Spacer()
            Text("\(count)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(severity.rawValue), \(count) alert\(count == 1 ? "" : "s")")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Group row

    private func groupRow(_ group: AlertDigestGroup) -> some View {
        NavigationLink {
            AlertGroupDetailView(group: group)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: group.severity.iconName)
                    .foregroundColor(group.severity.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.event)
                        .font(.body)
                    if let expires = group.soonestExpires {
                        Text("Until \(shortTime(expires))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 8)
                // Prominent per-category count (the "number on the button").
                Text("\(group.count)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundColor(group.severity.color)
                    .accessibilityLabel(areaCountPhrase(group))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.event), \(areaCountPhrase(group)).\(expiryPhrase(group))")
        .accessibilityHint("Double tap to view affected areas")
    }

    private func areaCountPhrase(_ group: AlertDigestGroup) -> String {
        group.count == 1 ? "1 area" : "\(group.count) areas"
    }

    private func expiryPhrase(_ group: AlertDigestGroup) -> String {
        guard let expires = group.soonestExpires else { return "" }
        return " Soonest expires \(shortTime(expires))."
    }

    // MARK: Helpers

    private func groupsBySeverity(_ groups: [AlertDigestGroup]) -> [(AlertSeverity, [AlertDigestGroup])] {
        AlertSeverity.allCases.compactMap { sev in
            let matching = groups.filter { $0.severity == sev }
            return matching.isEmpty ? nil : (sev, matching)
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func load() async {
        state = .loading
        do {
            let alerts = try await service.fetchAlerts(for: region, landOnly: false)
            state = .loaded(alerts)
        } catch is CancellationError {
            // Superseded by a newer load; leave state alone.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Group detail (affected areas within one event type)

struct AlertGroupDetailView: View {
    let group: AlertDigestGroup
    @State private var selectedAlert: WeatherAlert?

    var body: some View {
        List {
            Section(header: Text("\(group.count) active")) {
                ForEach(group.alerts) { alert in
                    Button {
                        selectedAlert = alert
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.areaDesc ?? group.event)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if !alert.headline.isEmpty {
                                    Text(alert.headline)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(alert.areaDesc ?? group.event)
                    .accessibilityHint("Double tap to view full alert details")
                }
            }
        }
        .navigationTitle(group.event)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
    }
}
