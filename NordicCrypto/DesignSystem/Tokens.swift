import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// "Nordlys" design tokens: polar-night surfaces, aurora accents, editorial serif.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A color that follows the light/dark appearance.
    static func dynamic(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        #if os(tvOS)
        return Color(hex: dark, opacity: darkOpacity)
        #elseif canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark, opacity: darkOpacity))
                : UIColor(Color(hex: light, opacity: lightOpacity))
        })
        #else
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(Color(hex: dark, opacity: darkOpacity))
                : NSColor(Color(hex: light, opacity: lightOpacity))
        })
        #endif
    }
}

enum NL {
    // Core palette
    static let bg = Color.dynamic(light: 0xF5F6FA, dark: 0x070B14)
    static let bgAuroraTop = Color.dynamic(light: 0xEEF1F8, dark: 0x0B1424)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x0F1522)
    static let surfaceRaised = Color.dynamic(light: 0xFFFFFF, dark: 0x172033)
    static let hairline = Color.dynamic(light: 0x0B1220, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.08)
    static let textPrimary = Color.dynamic(light: 0x0B1220, dark: 0xF2F5FA)
    static let textSecondary = Color.dynamic(light: 0x4A5568, dark: 0xA3ADC2)
    static let textTertiary = Color.dynamic(light: 0x6B7385, dark: 0x7A859C)
    static let accent = Color.dynamic(light: 0x0E8F63, dark: 0x3DDC97)
    static let accent2 = Color.dynamic(light: 0x5B4BD6, dark: 0x8B7CF6)
    static let warning = Color.dynamic(light: 0x9A5B00, dark: 0xFFB547)
    static let danger = Color.dynamic(light: 0xC42B3B, dark: 0xFF5D6C)

    /// One distinct aurora hue per country (flag colors collide).
    static func country(_ code: String?) -> Color {
        switch code {
        case "NO": .dynamic(light: 0xC8323F, dark: 0xF2545B)
        case "SE": .dynamic(light: 0x9C6F00, dark: 0xF2C14E)
        case "DK": .dynamic(light: 0xC23A6A, dark: 0xFF7AA2)
        case "FI": .dynamic(light: 0x1F63D1, dark: 0x4D9DFF)
        case "IS": .dynamic(light: 0x0B827A, dark: 0x3FD3C6)
        default: textTertiary
        }
    }

    /// Second gradient stop that pairs with a country's hue.
    static func countryPartner(_ code: String?) -> Color {
        switch code {
        case "NO": Color(hex: 0x8B7CF6)
        case "SE": Color(hex: 0x3D7BFF)
        case "DK": Color(hex: 0xFFB547)
        case "FI": Color(hex: 0x3DDC97)
        case "IS": Color(hex: 0x7FA7FF)
        default: Color(hex: 0x5B6CFF)
        }
    }

    static func topic(_ topic: String?) -> Color {
        switch topic?.lowercased() {
        case "regulation", "mica", "policy", "licence", "tax": Color(hex: 0x8B7CF6)
        case "crime", "aml", "fraud", "sanctions": Color(hex: 0xFF7A45)
        case "business", "funds", "markets", "adoption", "mining", "bitcoin": Color(hex: 0x3DDC97)
        case "stablecoins", "payments", "cbdc", "banking", "tokenisation", "defi": Color(hex: 0x2EC4E6)
        default: Color(hex: 0x5B6CFF)
        }
    }
}

/// Per-platform type scale. iOS and visionOS use text styles so Dynamic Type works.
enum NLFont {
    static var display: Font {
        #if os(tvOS)
        .system(size: 60, weight: .bold, design: .serif)
        #elseif os(macOS)
        .system(size: 36, weight: .bold, design: .serif)
        #elseif os(visionOS)
        .system(.extraLargeTitle, design: .serif, weight: .bold)
        #else
        .system(.largeTitle, design: .serif, weight: .bold)
        #endif
    }

    static var title: Font {
        #if os(tvOS)
        .system(size: 36, weight: .semibold, design: .serif)
        #elseif os(macOS)
        .system(size: 21, weight: .semibold, design: .serif)
        #elseif os(visionOS)
        .system(.title2, design: .serif, weight: .semibold)
        #else
        .system(.title3, design: .serif, weight: .semibold)
        #endif
    }

    static var row: Font {
        #if os(tvOS)
        .system(size: 30, weight: .semibold, design: .serif)
        #elseif os(macOS)
        .system(size: 16, weight: .semibold, design: .serif)
        #else
        .system(.headline, design: .serif, weight: .semibold)
        #endif
    }

    static var section: Font {
        #if os(tvOS)
        .system(size: 32, weight: .semibold)
        #elseif os(macOS)
        .system(size: 20, weight: .bold)
        #else
        .system(.title2, weight: .bold)
        #endif
    }

    static var body: Font {
        #if os(tvOS)
        .system(size: 29)
        #elseif os(macOS)
        .system(size: 14)
        #else
        .body
        #endif
    }

    static var kicker: Font {
        #if os(tvOS)
        .system(size: 23, weight: .semibold)
        #elseif os(macOS)
        .system(size: 12, weight: .semibold)
        #else
        .subheadline.weight(.semibold)
        #endif
    }

    static var caption: Font {
        #if os(tvOS)
        .system(size: 21)
        #elseif os(macOS)
        .system(size: 11)
        #else
        .caption
        #endif
    }

    static var dateDay: Font {
        #if os(tvOS)
        .system(size: 46, weight: .bold, design: .rounded)
        #elseif os(visionOS)
        .system(size: 34, weight: .bold, design: .rounded)
        #else
        .system(size: 26, weight: .bold, design: .rounded)
        #endif
    }

    static var reader: Font {
        #if os(tvOS)
        .system(size: 34, design: .serif)
        #elseif os(macOS)
        .system(size: 18, design: .serif)
        #elseif os(visionOS)
        .system(.title3, design: .serif)
        #else
        .system(.body, design: .serif)
        #endif
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum NLMetrics {
    #if os(tvOS)
    static let margin: CGFloat = 80
    static let gutter: CGFloat = 40
    static let cardPadding: CGFloat = 32
    static let cardRadius: CGFloat = 28
    static let rowRadius: CGFloat = 20
    #elseif os(visionOS)
    static let margin: CGFloat = 32
    static let gutter: CGFloat = 24
    static let cardPadding: CGFloat = 24
    static let cardRadius: CGFloat = 28
    static let rowRadius: CGFloat = 18
    #elseif os(macOS)
    static let margin: CGFloat = 28
    static let gutter: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let rowRadius: CGFloat = 14
    #else
    static let margin: CGFloat = 16
    static let gutter: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let rowRadius: CGFloat = 16
    #endif
}
