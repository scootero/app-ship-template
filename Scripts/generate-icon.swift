#!/usr/bin/env swift
// =============================================================================
// generate-icon.swift — draw the app icon from code.             [opt] PHASE 4
// =============================================================================
// WHY: the icon becomes code you can tweak (colors, glyph) instead of a PNG you
// have to re-export from a design tool. Blip also draws its DMG background,
// favicon and social image this way, all from one palette.
//
// Usage (macOS, from repo root):
//   swift Scripts/generate-icon.swift            # letter = first letter of DISPLAY_NAME
//   swift Scripts/generate-icon.swift F          # custom letter/glyph
//
// Writes:
//   iOS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//   Mac/Resources/Assets.xcassets/AppIcon.appiconset/icon-{16..1024}.png
//   docs/assets/icon-512.png   (website + favicon)
//
// SKIP THIS if you have a designed icon: just drop your 1024×1024 PNG in as
// icon-1024.png (iOS) and delete this script.
// =============================================================================

import AppKit

// --- TODO(phase-4): brand palette -------------------------------------------
// FitUp-style example: late-night arcade — navy → purple, neon cyan glyph.
let backgroundTop    = NSColor(srgbRed: 0.05, green: 0.07, blue: 0.20, alpha: 1)
let backgroundBottom = NSColor(srgbRed: 0.22, green: 0.05, blue: 0.35, alpha: 1)
let glyphColor       = NSColor(srgbRed: 0.00, green: 0.90, blue: 1.00, alpha: 1)
// -----------------------------------------------------------------------------

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)

/// Read DISPLAY_NAME out of ship.config for the default letter.
func displayName() -> String {
    let cfg = (try? String(contentsOf: root.appendingPathComponent("ship.config"), encoding: .utf8)) ?? ""
    for line in cfg.split(separator: "\n") where line.hasPrefix("DISPLAY_NAME=") {
        return line.dropFirst("DISPLAY_NAME=".count).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    return "App"
}
let glyph = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : String(displayName().prefix(1))

/// Render one square PNG at `px` pixels.
/// `rounded`: Mac icons draw their own rounded square with margin; iOS icons
/// must be full-bleed squares (iOS applies its own mask).
func render(px: Int, rounded: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = rounded ? NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
                       : NSRect(x: 0, y: 0, width: s, height: s)
    let path = rounded ? NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
                       : NSBezierPath(rect: rect)
    NSGradient(starting: backgroundTop, ending: backgroundBottom)!.draw(in: path, angle: -90)

    let font = NSFont.systemFont(ofSize: rect.height * 0.55, weight: .heavy)
    let text = NSAttributedString(string: glyph, attributes: [.font: font, .foregroundColor: glyphColor])
    let size = text.size()
    text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ relPath: String) {
    let url = root.appendingPathComponent(relPath)
    guard fm.fileExists(atPath: url.deletingLastPathComponent().path) else { return } // platform removed
    try! data.write(to: url)
    print("  wrote \(relPath)")
}

write(render(px: 1024, rounded: false), "iOS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
for px in [16, 32, 64, 128, 256, 512, 1024] {
    write(render(px: px, rounded: true), "Mac/Resources/Assets.xcassets/AppIcon.appiconset/icon-\(px).png")
}
try? fm.createDirectory(at: root.appendingPathComponent("docs/assets"), withIntermediateDirectories: true)
write(render(px: 512, rounded: true), "docs/assets/icon-512.png")
print("✓ Icons generated with glyph '\(glyph)'")
