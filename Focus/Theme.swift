import SwiftUI

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
            (r, g, b) = (126, 108, 242) // fallback indigo
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
