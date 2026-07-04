#!/usr/bin/env swift
// fm_describe.swift — Foundation Models radar description runner
//
// Reads every image in a run's images/ folder, runs it through the on-device
// Foundation Models using the prompt in prompt.txt, and writes descriptions to
// the run's fm/ folder. Also updates each data/*.json with an "fm_description" key.
//
// Usage (called automatically by run_archive.sh):
//   swift -sdk /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.sdk \
//     fm_describe.swift /path/to/run_dir
//
// prompt.txt must live in the same directory as this script (the RadarData folder).
// Edit prompt.txt to change what the model is asked — {CITY} is replaced at runtime.

import AppKit
import Foundation
import CoreGraphics
import ImageIO
import FoundationModels

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Prompt loading
// ─────────────────────────────────────────────────────────────────────────────

let BUILTIN_PROMPT = """
You are describing a NWS NEXRAD base-reflectivity radar image for a blind user in {CITY}.

LOCATING {CITY}: This image is centered on a radar station, NOT on {CITY}. {CITY} is labeled on the map and covers a large area containing many cities and counties.

Describe where precipitation actually IS using the named cities, counties, and geographic features visible on the map. Then state clearly whether {CITY} itself is under precipitation or is clear. Do NOT assume precipitation elsewhere on the map is near {CITY}.

WHAT IS NOT PRECIPITATION: Blue/teal filled areas = water bodies. White/gray = no precipitation. Red/brown lines = county borders. Top legend strip = reference labels, NOT active warnings.

PRECIPITATION: light green = drizzle, green = light rain, yellow = moderate, orange = heavy, red = very heavy, pink = extreme.

ACTIVE WARNINGS: thick colored polygon outlines drawn over the map geography (NOT the top legend boxes).

In 2–3 sentences: (1) Where is precipitation? Name specific cities, counties, or regions. (2) Is {CITY} clear or under precipitation? (3) Any active warning polygons on the map?
"""

func loadPrompt(scriptDir: URL, cityName: String) -> String {
    let promptFile = scriptDir.appendingPathComponent("prompt.txt")
    if let template = try? String(contentsOf: promptFile, encoding: .utf8) {
        return template.replacingOccurrences(of: "{CITY}", with: cityName)
    }
    print("  [prompt.txt not found at \(promptFile.path) — using built-in]")
    return BUILTIN_PROMPT.replacingOccurrences(of: "{CITY}", with: cityName)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Image loading
// ─────────────────────────────────────────────────────────────────────────────

func loadCGImage(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return image
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Image annotation
// ─────────────────────────────────────────────────────────────────────────────

// Projects city center to pixel coordinates. NEXRAD standard covers ~248km radius.
// Returns nil when station coords are zero (unknown station).
func projectCityToPixel(cityLat: Double, cityLon: Double,
                        stationLat: Double, stationLon: Double,
                        imageWidth: Int, imageHeight: Int) -> CGPoint? {
    guard stationLat != 0 || stationLon != 0 else { return nil }
    let rangeKm = 248.0
    let latRad  = stationLat * .pi / 180
    let kmEast  = (cityLon - stationLon) * cos(latRad) * 111.0
    let kmNorth = (cityLat - stationLat) * 111.0
    let halfW   = Double(imageWidth)  / 2.0
    let halfH   = Double(imageHeight) / 2.0
    let px = halfW + kmEast  * (halfW / rangeKm)
    let py = halfH - kmNorth * (halfH / rangeKm)
    return CGPoint(x: px, y: py)
}

func annotateImage(_ source: CGImage, at point: CGPoint) -> CGImage? {
    let w = source.width
    let h = source.height
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0),
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    NSImage(cgImage: source, size: NSSize(width: w, height: h))
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h))

    let dotX = point.x
    let dotY = CGFloat(h) - point.y
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: dotX - 13, y: dotY - 13, width: 26, height: 26)).fill()
    NSColor(red: 0.9, green: 0.05, blue: 0.05, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: dotX - 9, y: dotY - 9, width: 18, height: 18)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage
}

func savePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - JSON read/write helpers
// ─────────────────────────────────────────────────────────────────────────────

func readJSON(_ url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return obj
}

func writeJSON(_ dict: [String: Any], to url: URL) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
    try? data.write(to: url)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main
// ─────────────────────────────────────────────────────────────────────────────

@available(macOS 27.0, *)
func run(runDirPath: String, scriptDir: URL) async {
    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
        print("❌ Foundation Models not available on this Mac.")
        return
    }

    let runDir       = URL(fileURLWithPath: runDirPath)
    let imagesDir    = runDir.appendingPathComponent("images")
    let dataDir      = runDir.appendingPathComponent("data")
    let fmDir        = runDir.appendingPathComponent("fm")
    let annotatedDir = runDir.appendingPathComponent("annotated")

    for dir in [fmDir, annotatedDir] {
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        catch { print("Could not create \(dir.lastPathComponent)/ directory: \(error)"); return }
    }

    guard let imageFiles = try? FileManager.default.contentsOfDirectory(
        at: imagesDir, includingPropertiesForKeys: nil
    ).filter({ ["png", "gif"].contains($0.pathExtension.lowercased()) })
     .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
        print("No images found in \(imagesDir.path)"); return
    }

    print("Foundation Models available — processing \(imageFiles.count) image(s) in \(runDir.lastPathComponent)")
    print()

    let annotationNote = "A small red dot on the map marks the city's exact location. Use it as the ground truth — the dot overrides any city label text on the map."

    for (i, imageURL) in imageFiles.enumerated() {
        let base       = imageURL.deletingPathExtension().lastPathComponent
        let jsonURL    = dataDir.appendingPathComponent("\(base).json")
        let fmOutURL   = fmDir.appendingPathComponent("\(base).txt")
        let annPNGURL  = annotatedDir.appendingPathComponent("\(base)_annotated.png")

        // Skip if already fully done (both unannotated and annotated)
        var meta = readJSON(jsonURL)
        let alreadyDone = FileManager.default.fileExists(atPath: fmOutURL.path)
                       && (meta?["fm_description_annotated"] != nil)
        if alreadyDone {
            print("[\(i+1)/\(imageFiles.count)] \(base) — already described, skipping")
            continue
        }

        let cityName    = (meta?["city"]        as? String) ?? base
        let cityLat     = (meta?["city_lat"]    as? Double) ?? 0
        let cityLon     = (meta?["city_lon"]    as? Double) ?? 0
        let stationLat  = (meta?["station_lat"] as? Double) ?? 0
        let stationLon  = (meta?["station_lon"] as? Double) ?? 0

        print("[\(i+1)/\(imageFiles.count)] \(cityName)...")

        guard let cgImage = loadCGImage(at: imageURL) else {
            print("  Could not load image"); continue
        }

        // Build annotated version if we have coordinates
        let dot = projectCityToPixel(cityLat: cityLat, cityLon: cityLon,
                                     stationLat: stationLat, stationLon: stationLon,
                                     imageWidth: cgImage.width, imageHeight: cgImage.height)
        let annotatedImage: CGImage? = dot.flatMap { annotateImage(cgImage, at: $0) }
        if let ann = annotatedImage { savePNG(ann, to: annPNGURL) }

        let basePrompt = loadPrompt(scriptDir: scriptDir, cityName: cityName)
        let annotatedPrompt = basePrompt + "\n\n" + annotationNote

        // Unannotated FM
        var description = ""
        if !FileManager.default.fileExists(atPath: fmOutURL.path) {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond {
                    basePrompt
                    Attachment(cgImage)
                }
                description = response.content
                try description.write(to: fmOutURL, atomically: true, encoding: .utf8)
                print("  no-annotation: \(description.prefix(100).replacingOccurrences(of: "\n", with: " "))")
            } catch {
                print("  FM error (unannotated): \(error)")
            }
        } else {
            description = (try? String(contentsOf: fmOutURL, encoding: .utf8)) ?? ""
        }

        // Annotated FM
        var annotatedDescription = ""
        if let ann = annotatedImage {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond {
                    annotatedPrompt
                    Attachment(ann)
                }
                annotatedDescription = response.content
                print("  annotated:     \(annotatedDescription.prefix(100).replacingOccurrences(of: "\n", with: " "))")
            } catch {
                print("  FM error (annotated): \(error)")
            }
        } else {
            print("  annotation skipped — no station coordinates in JSON")
        }

        // Update JSON
        if meta != nil {
            if !description.isEmpty        { meta!["fm_description"]           = description }
            if !annotatedDescription.isEmpty { meta!["fm_description_annotated"] = annotatedDescription }
            if annotatedImage != nil       { meta!["annotated_file"]           = "annotated/\(base)_annotated.png" }
            writeJSON(meta!, to: jsonURL)
        }
    }

    print()
    print("Done. Results written to \(fmDir.path)")
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Entry point
// ─────────────────────────────────────────────────────────────────────────────

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift fm_describe.swift <run_dir>")
    print("  run_dir: path to a run folder, e.g. RadarData/runs/20260624_102006")
    exit(1)
}

// Locate script directory (prompt.txt lives here)
// In swift script mode, args[0] is often the path to the swift binary.
// Use the known RadarData location as a reliable fallback.
let scriptPath = args[0]
let scriptDir: URL
if scriptPath.hasSuffix(".swift") {
    scriptDir = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
} else {
    // Fallback: prompt.txt is two levels above the run dir (RadarData/runs/TIMESTAMP/)
    scriptDir = URL(fileURLWithPath: args[1])
        .standardizedFileURL
        .deletingLastPathComponent()   // runs/
        .deletingLastPathComponent()   // RadarData/
}

Task {
    if #available(macOS 27.0, *) {
        await run(runDirPath: args[1], scriptDir: scriptDir)
    } else {
        print("Requires macOS 27+")
    }
    exit(0)
}

RunLoop.main.run()
