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
    @StateObject private var service = AlertBrowserService()
    @State private var counts: [String: Int] = [:]
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
                    HStack {
                        Text(region.displayName).foregroundColor(.primary)
                        Spacer()
                        if let count = counts[region.id] {
                            Text("\(count)")
                                .foregroundColor(count == 0 ? .secondary : .primary)
                                .font(count == 0 ? .body : .body.weight(.semibold))
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: region))
                .accessibilityHint("Double tap to view active alerts for \(region.displayName)")
            }
        }
        .navigationTitle("Europe")
        .searchable(text: $searchText, prompt: "Search countries")
        .task { await loadCounts() }
        .refreshable { await loadCounts() }
    }

    private func accessibilityLabel(for region: AlertRegion) -> String {
        guard let count = counts[region.id] else { return region.displayName }
        if count == 0 { return "\(region.displayName), no active alerts" }
        return "\(region.displayName), \(count) alert\(count == 1 ? "" : "s")"
    }

    /// Fetch every country's active-alert count. URLSession caps connections
    /// per host (~6), so these ~36 requests queue politely; the service also
    /// caches results for 5 minutes.
    private func loadCounts() async {
        await withTaskGroup(of: (String, Int?).self) { group in
            for region in AlertRegion.meteoAlarmCountries {
                group.addTask { (region.id, await service.alertCount(for: region)) }
            }
            for await (id, count) in group {
                if let count { counts[id] = count }
            }
        }
    }
}

// MARK: - National digest

struct NationalAlertDigestView: View {
    let region: AlertRegion

    @StateObject private var service = AlertBrowserService()
    @State private var state: AlertBrowserService.LoadState = .idle
    // Exclusive severity buttons: each shows only that severity. Default is All
    // so nothing is hidden on open; the buttons narrow to a single severity.
    @State private var severityFilter: SeverityFilter = .all
    // Optional hazard-type filter (nil = all types), e.g. "Storms" gathers
    // tornado/thunderstorm products that span several severities.
    @State private var hazardType: HazardType?

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
        // Classify each alert's hazard family exactly once per render; the tuple
        // list is reused for the filter controls, the scope, and the type menu
        // (classify lowercases + substring-scans, so recomputing it is wasteful).
        let classified = alerts.map { (alert: $0, hazard: HazardType.classify($0.event)) }

        Section {
            filterControls(classified)
        }

        let scoped = classified.filter { hazardType == nil || $0.hazard == hazardType }.map(\.alert)
        let groups = service.digest(from: scoped, filter: severityFilter)
        if groups.isEmpty {
            Section {
                Text(alerts.isEmpty
                     ? "No active alerts right now."
                     : "No alerts match this filter. Try All severities or All types.")
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

    // MARK: Filters

    /// Exclusive severity segments + a hazard-type menu. Severity segment counts
    /// reflect the current hazard scope. VoiceOver reads each segment as
    /// "Extreme, 3 alerts" (it appends the position, "1 of 4").
    private func filterControls(_ classified: [(alert: WeatherAlert, hazard: HazardType)]) -> some View {
        // Severity counts respect the hazard filter so they match what's shown.
        let scoped = classified.filter { hazardType == nil || $0.hazard == hazardType }
        // Only offer hazard families that are actually present right now.
        let presentFamilies = HazardType.allCases.filter { fam in
            classified.contains { $0.hazard == fam }
        }
        return Group {
            Picker("Minimum severity", selection: $severityFilter) {
                ForEach(SeverityFilter.allCases) { filter in
                    let n = scoped.filter { filter.includes($0.alert.severity) }.count
                    Text(filter.rawValue)
                        .tag(filter)
                        .accessibilityLabel("\(filter.rawValue), \(n) alert\(n == 1 ? "" : "s")")
                }
            }
            .pickerStyle(.segmented)

            Picker("Type", selection: $hazardType) {
                Text("All types").tag(HazardType?.none)
                ForEach(presentFamilies) { fam in
                    let n = classified.filter { $0.hazard == fam }.count
                    Text("\(fam.rawValue) (\(n))").tag(HazardType?.some(fam))
                }
            }
            .pickerStyle(.menu)
            .accessibilityHint("Filters alerts by hazard type, such as Storms, Heat, or Flooding")
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

    // Cached once — DateFormatter construction is expensive and shortTime runs
    // per group row on every render.
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private func shortTime(_ date: Date) -> String {
        Self.shortTimeFormatter.string(from: date)
    }

    private func load() async {
        state = .loading
        do {
            let alerts = try await service.fetchAlerts(for: region)
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
