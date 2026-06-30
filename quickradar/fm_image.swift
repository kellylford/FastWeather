// fm_image.swift — generic Apple Foundation Models image describer.
//
// Usage:
//   swift fm_image.swift <promptFile> <image1> [image2 ...]
//
// Prints the model's description to stdout. Prompt is read from a file to avoid
// shell-escaping problems. One or more images may be attached (e.g. two radar
// frames for movement). Requires macOS 26/27 with Apple Intelligence enabled.
//
// This is the image-type-agnostic sibling of test_prompt.swift (which is radar
// specific). The Python lab orchestrator calls this once per weather image with
// a prompt tailored to that image type.

import AppKit
import Foundation
import CoreGraphics
import ImageIO
import FoundationModels

func loadCGImage(_ path: String) -> CGImage? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return image
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(2)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fail("usage: fm_image.swift <promptFile> <image1> [image2 ...]") }

let promptPath = args[0]
guard let prompt = try? String(contentsOfFile: promptPath, encoding: .utf8) else {
    fail("could not read prompt file: \(promptPath)")
}

let imagePaths = Array(args.dropFirst())
var images: [CGImage] = []
for p in imagePaths {
    guard let img = loadCGImage(p) else { fail("could not load image: \(p)") }
    images.append(img)
}

// Check model availability up front for a clean error.
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    break
case .unavailable(let reason):
    fail("Foundation Models unavailable: \(reason)")
@unknown default:
    fail("Foundation Models unavailable: unknown")
}

let sem = DispatchSemaphore(value: 0)
var output = ""

Task {
    do {
        let session = LanguageModelSession()
        // The prompt result builder does not support loops over attachments,
        // so attach explicitly. One image is the common case; two supports
        // before/after frame comparison (movement).
        let response: LanguageModelSession.Response<String>
        if images.count >= 2 {
            response = try await session.respond {
                prompt
                Attachment(images[0])
                Attachment(images[1])
            }
        } else {
            response = try await session.respond {
                prompt
                Attachment(images[0])
            }
        }
        output = response.content
    } catch {
        output = "ERROR: \(error)"
    }
    sem.signal()
}

sem.wait()
print(output)
