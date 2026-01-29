// Agentboard/Styles/Theme.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    static let bgPrimary = Color(hex: "#0a0a0a")
    static let bgElevated = Color(hex: "#141414")
    static let bgControl = Color(hex: "#1a1a1a")
    static let border = Color(hex: "#3f3f46")

    static let accent = Color(hex: "#22d3ee")
    static let accentWarning = Color(hex: "#fbbf24")
    static let accentDanger = Color(hex: "#ef4444")
    static let accentSuccess = Color(hex: "#22c55e")

    static let textPrimary = Color(hex: "#e4e4e7")
    static let textMuted = Color(hex: "#71717a")
}

enum Fonts {
    static func jetBrainsMono(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }

    static func jetBrainsMonoBold(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Bold", size: size)
    }

    static func dmMono(_ size: CGFloat) -> Font {
        .custom("DMMono-Regular", size: size)
    }

    static func dmMonoMedium(_ size: CGFloat) -> Font {
        .custom("DMMono-Medium", size: size)
    }

    static func spaceMono(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Regular", size: size)
    }

    static func spaceMonoBold(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Bold", size: size)
    }
}
