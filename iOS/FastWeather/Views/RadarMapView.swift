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

/// Full-screen radar map with attribution, AI description, and accessibility guidance.
struct RadarMapSheet: View {
    let city: City

    private var covered: Bool { RadarTileService.coversRadar(country: city.country) }

    // AI description state
    @State private var radarDescription: String?
    @State private var radarImage: UIImage?
    @State private var radarStationId: String?
    @State private var radarStationName: String?
    @State private var isDescribing = false
    @State private var describeError: String?
    // Structured analysis (iOS 26+ Foundation Models with structured output)
    @State private var radarAnalysis: RadarAnalysis?
    // Two-frame movement state
    @State private var movementFirstFrame: UIImage?
    @State private var movementLastFrame: UIImage?
    @State private var isMovementAnalysis = false
    // Custom prompt editor state
    @State private var showPromptEditor = false
    @State private var customPromptText = ""
    @State private var isUsingCustomPrompt = false
    // Logging state
    @State private var isLogging = false
    @State private var loggedAt: Date? = nil
    // VoiceOver image-description capture (pasted by the user for comparison)
    @State private var voiceoverDesc1 = ""
    @State private var voiceoverDesc2 = ""
    @ObservedObject private var featureFlags = FeatureFlags.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RadarTileMapView(centerLat: city.latitude, centerLon: city.longitude,
                                 cityName: city.name)
                    .frame(height: 350)
                    .accessibilityElement()
                    .accessibilityLabel(mapAccessibilityLabel)

                VStack(spacing: 12) {
                    if !covered {
                        Text("Radar coverage is U.S. only — no radar is shown for this location.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Prompt mode picker — mirrors Developer Settings, visible for quick testing
                    if covered, RadarFoundationModelsService.shared.isAvailable {
                        Picker("Mode", selection: $featureFlags.radarDescriptionDetailLevel) {
                            Text("Interpret").tag("interpret")
                            Text("Describe").tag("describe")
                            Text("Combined").tag("combined")
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Radar prompt mode")
                        .accessibilityHint("Interpret: plain language impact for someone in this city. Describe: objective technical description including color bands, storm structure, and warning polygons. Combined: both.")
                    }

                    // Describe Radar button
                    if covered {
                        describeRadarButton
                    }

                    // Prompt editor — lets you view and customize the prompt
                    if covered, RadarFoundationModelsService.shared.isAvailable {
                        promptEditorSection
                    }

                    // Error display — shows what went wrong if the radar
                    // description or download failed.
                    if let err = describeError {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Radar Error")
                                    .font(.headline)
                            }
                            Text(err)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Radar error. \(err)")
                    }

                    // AI description display
                    if let description = radarDescription {
                        radarDescriptionCard(description)
                    }

                    // Structured analysis fields (iOS 26+ with structured output)
                    if let analysis = radarAnalysis {
                        radarAnalysisCard(analysis)
                    }

                    // Two-frame movement images
                    if isMovementAnalysis, let first = movementFirstFrame, let last = movementLastFrame {
                        movementFramesCard(first: first, last: last)
                    }

                    // Radar image — explicitly marked as an image accessibility element
                    // so VoiceOver stops here and iOS 27's expanded image description
                    // can be triggered on it. Label is intentionally brief.
                    // Hidden in movement mode: there the standalone image is the SAME
                    // pixels as the "Later frame" in the movement card, so showing it
                    // again would give VoiceOver a redundant third image with no
                    // matching paste box. The two movement frames cover that case.
                    if let image = radarImage, !isMovementAnalysis {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("NWS radar image")
                            .accessibilityAddTraits(.isImage)
                    }

                    // Log section — paste VoiceOver descriptions, then log everything
                    // with NWS ground truth. Placed after the images so VoiceOver can
                    // describe each image, then the user pastes the text just below it.
                    if radarDescription != nil {
                        logSection
                    }

                    Text(RadarTileService.attribution)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Radar Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Describe Radar Button

    private var describeRadarButton: some View {
        Button(action: {
            Task { await fetchRadarDescription() }
        }) {
            HStack {
                if isDescribing {
                    ProgressView()
                    Text(isMovementAnalysis ? "Analyzing movement…" : "Describing radar…")
                } else {
                    Image(systemName: isMovementAnalysis ? "arrow.triangle.2.circlepath" : "text.viewfinder")
                    Text(radarDescription == nil
                         ? (isMovementAnalysis ? "Analyze Movement" : "Describe Radar")
                         : (isMovementAnalysis ? "Refresh Movement" : "Refresh Description"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDescribing)
        .accessibilityLabel(radarDescription == nil
                            ? (isMovementAnalysis ? "Analyze radar movement" : "Describe radar image")
                            : (isMovementAnalysis ? "Refresh radar movement analysis" : "Refresh radar description"))
        .accessibilityHint(isMovementAnalysis
                           ? "Downloads two radar frames and compares them to infer storm movement."
                           : "Downloads the nearest NEXRAD radar image and describes it in text for screen readers.")
    }

    // MARK: - Description Card

    private func radarDescriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cloud.rain.fill")
                Text("Radar Description")
                    .font(.headline)
                Spacer()
            }
            if let sid = radarStationId, let name = radarStationName {
                Text("Station \(sid) — \(name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radar description. \(description)")
    }

    // MARK: - Fetch

    private func fetchRadarDescription(customPrompt: String? = nil) async {
        isDescribing = true
        describeError = nil
        // New images are coming — clear stale VoiceOver paste text and log status.
        voiceoverDesc1 = ""
        voiceoverDesc2 = ""
        loggedAt = nil
        let fmAvailable = RadarFoundationModelsService.shared.isAvailable
        // Movement is skipped when using a custom prompt
        isMovementAnalysis = customPrompt == nil && FeatureFlags.shared.radarTwoFrameMovementEnabled && fmAvailable
        isUsingCustomPrompt = customPrompt != nil
        debugLog("📡 Radar describe button tapped. Foundation Models available: \(fmAvailable), movement: \(isMovementAnalysis), customPrompt: \(customPrompt != nil)")

        if fmAvailable {
            let result = await RadarFoundationModelsService.shared.describeRadar(for: city, customPrompt: customPrompt)
            debugLog("📡 Foundation Models result: \(result)")
            await MainActor.run {
                isDescribing = false
                applyFoundationModelsResult(result)
            }
        } else {
            debugLog("📡 Falling back to legacy RadarDescriptionService")
            let result = await RadarDescriptionService.shared.describeRadar(for: city)
            debugLog("📡 Legacy result: \(result)")
            await MainActor.run {
                isDescribing = false
                applyLegacyResult(result)
            }
        }
    }

    private func applyLegacyResult(_ result: RadarDescriptionService.DescriptionResult) {
        switch result {
        case .success(let description, let image, let stationId, let stationName):
            radarDescription = description
            radarImage = image
            radarStationId = stationId
            radarStationName = stationName
            radarAnalysis = nil
            movementFirstFrame = nil
            movementLastFrame = nil
        case .noCoverage:
            describeError = "Radar coverage is U.S. only."
        case .error(let msg):
            describeError = msg
        }
    }

    private func applyFoundationModelsResult(_ result: FoundationModelsRadarResult) {
        switch result {
        case .text(let description, let image, let stationId, let stationName):
            radarDescription = description
            radarImage = image
            radarStationId = stationId
            radarStationName = stationName
            radarAnalysis = nil
            movementFirstFrame = nil
            movementLastFrame = nil
        case .structured(let analysis, let image, let stationId, let stationName):
            radarDescription = analysis.description
            radarImage = image
            radarStationId = stationId
            radarStationName = stationName
            radarAnalysis = analysis
            movementFirstFrame = nil
            movementLastFrame = nil
        case .movement(let analysis, let firstFrame, let lastFrame, let stationId, let stationName):
            radarDescription = analysis.description
            radarImage = lastFrame
            radarStationId = stationId
            radarStationName = stationName
            radarAnalysis = analysis
            movementFirstFrame = firstFrame
            movementLastFrame = lastFrame
        case .noCoverage:
            describeError = "Radar coverage is U.S. only."
        case .unavailable(let msg):
            // Fall back to the legacy Vision path.
            Task {
                let legacy = await RadarDescriptionService.shared.describeRadar(for: city)
                await MainActor.run { applyLegacyResult(legacy) }
            }
            describeError = msg
        case .error(let msg):
            describeError = msg
        }
    }

    // MARK: - Structured Analysis Card

    private func radarAnalysisCard(_ analysis: RadarAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                Text("Radar Analysis")
                    .font(.headline)
                Spacer()
            }
            HStack {
                Label(analysis.hasPrecipitation ? "Precipitation visible" : "No precipitation",
                      systemImage: analysis.hasPrecipitation ? "cloud.rain.fill" : "sun.max.fill")
                Spacer()
                if analysis.hasWarnings {
                    Label("Warnings visible", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.subheadline)
            if analysis.intensity.lowercased() != "none" && analysis.intensity.lowercased() != "unknown" {
                Text("Intensity: \(analysis.intensity)")
                    .font(.subheadline)
            }
            if let dir = analysis.direction, !dir.isEmpty {
                Text("Direction: \(dir)")
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Radar analysis. \(analysis.hasPrecipitation ? "Precipitation visible." : "No precipitation.") Intensity \(analysis.intensity). \(analysis.direction.map { "Direction \($0)." } ?? "") \(analysis.hasWarnings ? "Warnings visible." : "") \(analysis.description)")
    }

    // MARK: - Movement Frames Card

    private func movementFramesCard(first: UIImage, last: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .accessibilityHidden(true)
                Text("Movement Analysis")
                    .font(.headline)
                Spacer()
            }
            Text("Two radar frames compared to infer storm movement.")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                VStack {
                    Image(uiImage: first)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Earlier radar frame")
                        .accessibilityAddTraits(.isImage)
                    Text("Earlier")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                VStack {
                    Image(uiImage: last)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Later radar frame")
                        .accessibilityAddTraits(.isImage)
                    Text("Later")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Prompt Editor

    private var promptEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                if customPromptText.isEmpty {
                    customPromptText = RadarFoundationModelsService.shared.currentDefaultPrompt(for: city.name)
                }
                showPromptEditor.toggle()
            }) {
                HStack {
                    Image(systemName: "text.alignleft")
                    Text(showPromptEditor ? "Hide Prompt Editor" : "Customize Prompt")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showPromptEditor ? 90 : 0))
                }
                .foregroundColor(.accentColor)
            }
            .accessibilityLabel(showPromptEditor ? "Hide prompt editor" : "Customize prompt")
            .accessibilityHint("Shows the current AI prompt and lets you edit it to experiment with different descriptions.")

            if showPromptEditor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $customPromptText)
                        .frame(minHeight: 120)
                        .font(.body.monospaced())
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .accessibilityLabel("Prompt editor")
                        .accessibilityHint("Edit the prompt that tells the AI how to describe the radar image. Then tap Describe with Custom Prompt.")

                    HStack(spacing: 12) {
                        Button(action: {
                            customPromptText = RadarFoundationModelsService.shared.currentDefaultPrompt(for: city.name)
                        }) {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .accessibilityLabel("Reset prompt to default")
                        .accessibilityHint("Restores the built-in prompt for the current detail level.")

                        Spacer()

                        Button(action: {
                            Task { await fetchRadarDescription(customPrompt: customPromptText) }
                        }) {
                            Label("Describe with Custom Prompt", systemImage: "wand.and.stars")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(customPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDescribing)
                        .accessibilityLabel("Describe radar with custom prompt")
                        .accessibilityHint("Sends the edited prompt with the radar image to the AI model.")
                    }

                    if isUsingCustomPrompt {
                        Text("Using custom prompt")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Log Section (VoiceOver capture + log button)

    /// Labels for the two VoiceOver paste fields, adapting to whether the
    /// two-frame movement images or the single radar image are on screen.
    private var voiceoverFieldLabel1: String {
        isMovementAnalysis ? "Earlier frame" : "Radar image"
    }
    private var voiceoverFieldLabel2: String {
        isMovementAnalysis ? "Later frame" : "Radar map (top of screen)"
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .accessibilityHidden(true)
                Text("Log for Comparison")
                    .font(.headline)
                Spacer()
            }

            Text("Optional: VoiceOver an image above, then paste its description here. Leave blank to log just the AI result.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // VoiceOver paste field 1
            VStack(alignment: .leading, spacing: 4) {
                Text("VoiceOver: \(voiceoverFieldLabel1)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $voiceoverDesc1)
                    .frame(minHeight: 60)
                    .padding(6)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .accessibilityLabel("VoiceOver description for \(voiceoverFieldLabel1)")
                    .accessibilityHint("Paste the VoiceOver image description for the \(voiceoverFieldLabel1) here.")
            }

            // VoiceOver paste field 2
            VStack(alignment: .leading, spacing: 4) {
                Text("VoiceOver: \(voiceoverFieldLabel2)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                TextEditor(text: $voiceoverDesc2)
                    .frame(minHeight: 60)
                    .padding(6)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .accessibilityLabel("VoiceOver description for \(voiceoverFieldLabel2)")
                    .accessibilityHint("Paste the VoiceOver image description for the \(voiceoverFieldLabel2) here. Optional.")
            }

            logResultButton
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var logResultButton: some View {
        Button(action: {
            guard let desc = radarDescription,
                  let sid = radarStationId,
                  let sname = radarStationName else { return }
            isLogging = true
            let mode = FeatureFlags.shared.radarDescriptionDetailLevel
            let analysis = radarAnalysis
            let vo1 = voiceoverDesc1.trimmingCharacters(in: .whitespacesAndNewlines)
            let vo2 = voiceoverDesc2.trimmingCharacters(in: .whitespacesAndNewlines)
            let img = radarImage
            let first = movementFirstFrame
            let last = movementLastFrame
            let moving = isMovementAnalysis
            Task {
                await RadarAILogger.shared.log(
                    city: city,
                    stationId: sid,
                    stationName: sname,
                    promptMode: mode,
                    aiDescription: desc,
                    analysis: analysis,
                    radarImage: moving ? nil : img,
                    firstFrame: moving ? first : nil,
                    lastFrame: moving ? last : nil,
                    voiceoverDesc1: vo1.isEmpty ? nil : vo1,
                    voiceoverLabel1: vo1.isEmpty ? nil : voiceoverFieldLabel1,
                    voiceoverDesc2: vo2.isEmpty ? nil : vo2,
                    voiceoverLabel2: vo2.isEmpty ? nil : voiceoverFieldLabel2
                )
                await MainActor.run {
                    isLogging = false
                    loggedAt = Date()
                }
            }
        }) {
            HStack(spacing: 6) {
                if isLogging {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Fetching NWS ground truth…")
                } else if let t = loggedAt {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Logged at \(t.formatted(date: .omitted, time: .shortened))")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Log Again")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "square.and.arrow.down")
                    Text("Log Result with NWS Ground Truth")
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .disabled(isLogging)
        .accessibilityLabel(loggedAt != nil
            ? "Re-log radar result with NWS ground truth"
            : "Log radar result with NWS ground truth")
        .accessibilityHint("Saves the AI description, any pasted VoiceOver descriptions, and current NWS conditions and active alerts to radar_ai_log.jsonl in the app Documents folder. Visible in Files app under On My iPhone, Weather Fast.")
    }

    private var mapAccessibilityLabel: String {
        if covered {
            return "Weather radar map, \(city.name)"
        } else {
            return "Weather radar map, \(city.name). No radar shown — coverage is United States only."
        }
    }
}
