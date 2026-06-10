import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SDIT Brand

/// San Diego Institute of Technology brand tokens, shared across the Tools suite
/// (Focus · Shade · Disko). Mirrors the palette and iOS spec on sandiegotech.org/brand.
enum Brand {
    static let paper    = Color(hex: "FCFBF8")  // warm off-white background
    static let ink      = Color(hex: "101C2C")  // near-black text / deep tile
    static let marine   = Color(hex: "234E70")  // primary interactive accent
    static let gold     = Color(hex: "A8842C")  // labels, eyebrows, emphasis
    static let goldLt   = Color(hex: "C0A24A")
    static let muted    = Color(hex: "5A6472")  // secondary text / metadata
    static let hairline = Color(hex: "D9D4C8")  // borders / dividers

    /// On-brand activity accent palette — calm, timeless, derived from the brand.
    static let activityPalette = ["234E70", "A8842C", "3E6E8E", "5A6472",
                                  "2E5A3E", "8C5A2B", "101C2C", "6E5A8E"]
}

// MARK: - Adaptive semantic tokens

extension Color {
    /// Adaptive paper: warm off-white in light, deep navy in dark.
    static let sditPaper    = Color(light: Color(hex: "FCFBF8"), dark: Color(hex: "101C2C"))
    /// Adaptive ink: deep navy in light, warm white (92%) in dark.
    static let sditInk      = Color(light: Color(hex: "101C2C"), dark: Color(hex: "F0EFE8").opacity(0.92))
    /// Adaptive muted: cool gray in light, warm white (50%) in dark.
    static let sditMuted    = Color(light: Color(hex: "5A6472"), dark: Color(hex: "F0EFE8").opacity(0.50))
    /// Adaptive marine: accent blue, lightens in dark mode for legibility.
    static let sditMarine   = Color(light: Color(hex: "234E70"), dark: Color(hex: "4A8AB5"))
    /// Adaptive gold: antique gold in light, slightly brighter in dark.
    static let sditGold     = Color(light: Color(hex: "A8842C"), dark: Color(hex: "C4A24E"))
    /// Adaptive hairline: warm rule in light, dim warm white in dark.
    static let sditHairline = Color(light: Color(hex: "D9D4C8"), dark: Color(hex: "FCFBF8").opacity(0.12))
    /// Secondary surface: paper in light, charcoal-mid in dark.
    static let sditSurface  = Color(light: Color(hex: "FCFBF8"), dark: Color(hex: "16243A"))

    /// Creates an adaptive Color that switches between light and dark variants.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #elseif canImport(AppKit)
        self = Color(NSColor(name: nil) { app in
            app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}

// MARK: - Font tokens

extension Font {
    /// EB Garamond — display headings, large titles, italic emphasis.
    static func sditDisplay(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "EBGaramond-Italic" : "EBGaramond-Medium", size: size)
    }

    /// IBM Plex Sans — body text, UI labels, running prose.
    static func sditBody(_ size: CGFloat = 16) -> Font {
        .custom("IBMPlexSans-Regular", size: size)
    }

    /// IBM Plex Mono — ALL-CAPS eyebrows, metadata, numeric readouts, status labels.
    static func sditMono(_ size: CGFloat = 12) -> Font {
        .custom("IBMPlexMono-Regular", size: size)
    }
}

// MARK: - Color from hex

extension Color {
    /// Create a Color from a hex string like "7E6CF2" or "#7E6CF2".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (4 bits each)
            (r, g, b) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: // RGB (8 bits each)
            (r, g, b) = (value >> 16, value >> 8 & 0xFF, value & 0xFF)
        default:
            (r, g, b) = (168, 144, 111) // fallback warm sand-clay
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Formatting helpers

enum Format {
    /// "5:12:30" (H:MM:SS) for the big countdown, or "12:30" when under an hour.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// "3h 12m" compact, for totals.
    static func hm(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    /// Decimal hours, e.g. "3.2".
    static func hours(_ seconds: TimeInterval, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", seconds / 3600)
    }

    /// A whole number of hours when round ("8"), otherwise one decimal ("8.5"). Input is hours.
    static func niceHours(_ hours: Double) -> String {
        hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
    }
}

// MARK: - Platform-specific view glue

extension View {
    @ViewBuilder
    func focusInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func focusMediumSheet() -> some View {
        #if os(iOS)
        presentationDetents([.medium])
        #else
        self
        #endif
    }

    @ViewBuilder
    func focusImpactFeedback(trigger: Int) -> some View {
        #if os(iOS)
        sensoryFeedback(.impact, trigger: trigger)
        #else
        self
        #endif
    }

    @ViewBuilder
    func focusSuccessFeedback(trigger: Int) -> some View {
        #if os(iOS)
        sensoryFeedback(.success, trigger: trigger)
        #else
        self
        #endif
    }
}
