import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Adaptive Color Palette
extension Color {
    static var hbBackground: Color { AppAppearance.current.style.background }
    static var hbSurface: Color { AppAppearance.current.style.surface }
    static var hbSurface2: Color { AppAppearance.current.style.surface2 }
    static var hbBorder: Color { AppAppearance.current.style.border }
    static var hbTextPrimary: Color { AppAppearance.current.style.textPrimary }
    static var hbTextSecondary: Color { AppAppearance.current.style.textSecondary }
    static var hbTextMuted: Color { AppAppearance.current.style.textMuted }

    // Default (Chapter 1 / global) accent
    static let hbAccent        = Color(hex: "#1B4F72")
    static let hbAccentLight   = Color(hex: "#D6E8F5")

    // Union flag palette
    static let unionNavy       = Color(hex: "#012169")
    static let unionRed        = Color(hex: "#C8102E")
    static let unionWhite      = Color(hex: "#FFFFFF")

    // Per-chapter accents
    static let ch1Accent       = Color(hex: "#1B4F72")
    static let ch1AccentLight  = Color(hex: "#D6E8F5")

    static let ch2Accent       = Color(hex: "#1A5276")
    static let ch2AccentLight  = Color(hex: "#D4E6F1")

    static let ch3Accent       = Color(hex: "#6E2C00")
    static let ch3AccentLight  = Color(hex: "#F5E6DA")

    static let ch4Accent       = Color(hex: "#145A32")
    static let ch4AccentLight  = Color(hex: "#D5F5E3")

    static let ch5Accent       = Color(hex: "#512E5F")
    static let ch5AccentLight  = Color(hex: "#EAD9F5")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    init(lightHex: String, darkHex: String) {
        #if canImport(UIKit)
        let light = UIColor(Color(hex: lightHex))
        let dark = UIColor(Color(hex: darkHex))
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
        #else
        self.init(hex: lightHex)
        #endif
    }
}

// MARK: - Radius
enum HBRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let pill: CGFloat = 20
}

extension Font {
    static let studyPrompt = Font.system(.title, design: .serif, weight: .medium)
}

// MARK: - Reading Theme (user-selectable page appearance)
enum ReadingThemeStyle: String, CaseIterable, Identifiable {
    case classic  // Original warm parchment
    case paper    // Pure white, clean
    case sepia    // Deep warm sepia
    case night    // Dark mode

    static let storageKey = "readingThemeStyle"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return "Classic"
        case .paper:   return "Paper"
        case .sepia:   return "Sepia"
        case .night:   return "Night"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "book"
        case .paper:   return "doc.text"
        case .sepia:   return "sun.max"
        case .night:   return "moon"
        }
    }

    var background: Color {
        switch self {
        case .classic: return Color(hex: "#F7F5F0")
        case .paper:   return Color(hex: "#FFFFFF")
        case .sepia:   return Color(hex: "#F5EDDC")
        case .night:   return Color(hex: "#1C1C1E")
        }
    }

    var surface: Color {
        switch self {
        case .classic: return Color(hex: "#FFFFFF")
        case .paper:   return Color(hex: "#F8F8F8")
        case .sepia:   return Color(hex: "#FBF5EB")
        case .night:   return Color(hex: "#2C2C2E")
        }
    }

    var surface2: Color {
        switch self {
        case .classic: return Color(hex: "#F0EDE6")
        case .paper:   return Color(hex: "#F0F0F0")
        case .sepia:   return Color(hex: "#EDE4D3")
        case .night:   return Color(hex: "#3A3A3C")
        }
    }

    var border: Color {
        switch self {
        case .classic: return Color(hex: "#E2DDD4")
        case .paper:   return Color(hex: "#E0E0E0")
        case .sepia:   return Color(hex: "#D9CEBC")
        case .night:   return Color(hex: "#48484A")
        }
    }

    var textPrimary: Color {
        switch self {
        case .classic: return Color(hex: "#1A1814")
        case .paper:   return Color(hex: "#111111")
        case .sepia:   return Color(hex: "#3B2F1E")
        case .night:   return Color(hex: "#E5E5E7")
        }
    }

    var textSecondary: Color {
        switch self {
        case .classic: return Color(hex: "#3D3830")
        case .paper:   return Color(hex: "#333333")
        case .sepia:   return Color(hex: "#5C4B35")
        case .night:   return Color(hex: "#AEAEB2")
        }
    }

    var textMuted: Color {
        switch self {
        case .classic: return Color(hex: "#8C8478")
        case .paper:   return Color(hex: "#888888")
        case .sepia:   return Color(hex: "#9A8B76")
        case .night:   return Color(hex: "#636366")
        }
    }

    /// Preview swatch color used in the theme picker
    var swatchColor: Color {
        switch self {
        case .classic: return Color(hex: "#F7F5F0")
        case .paper:   return Color(hex: "#FFFFFF")
        case .sepia:   return Color(hex: "#F5EDDC")
        case .night:   return Color(hex: "#1C1C1E")
        }
    }

    /// Swatch border for visibility
    var swatchBorder: Color {
        switch self {
        case .classic: return Color(hex: "#D5D0C8")
        case .paper:   return Color(hex: "#CCCCCC")
        case .sepia:   return Color(hex: "#CBBEA8")
        case .night:   return Color(hex: "#555555")
        }
    }
}

// MARK: - Reader Presentation
enum ReaderTextSize: String, CaseIterable, Identifiable {
    case small
    case standard
    case large

    static let storageKey = "readingTextSize"
    static let legacyStorageKey = "readingFontSizeAdjustment"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Standard"
        case .large: return "Large"
        }
    }

    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.90
        case .standard: return 1.00
        case .large: return 1.15
        }
    }

    static func loadAndMigrate(defaults: UserDefaults = .standard) -> ReaderTextSize {
        if let rawValue = defaults.string(forKey: storageKey),
           let storedValue = ReaderTextSize(rawValue: rawValue) {
            defaults.removeObject(forKey: legacyStorageKey)
            return storedValue
        }

        guard defaults.object(forKey: legacyStorageKey) != nil else {
            return .standard
        }

        let legacyAdjustment = defaults.double(forKey: legacyStorageKey)
        let migratedValue: ReaderTextSize
        if legacyAdjustment < 0 {
            migratedValue = .small
        } else if legacyAdjustment > 0 {
            migratedValue = .large
        } else {
            migratedValue = .standard
        }

        defaults.set(migratedValue.rawValue, forKey: storageKey)
        defaults.removeObject(forKey: legacyStorageKey)
        return migratedValue
    }
}

// MARK: - App Appearance
struct AppAppearance: Equatable {
    var style: ReadingThemeStyle
    var textSize: ReaderTextSize

    static var current: AppAppearance {
        let defaults = UserDefaults.standard
        return AppAppearance(
            style: ReadingThemeStyle(
                rawValue: defaults.string(forKey: ReadingThemeStyle.storageKey) ?? ""
            ) ?? .classic,
            textSize: ReaderTextSize(
                rawValue: defaults.string(forKey: ReaderTextSize.storageKey) ?? ""
            ) ?? .standard
        )
    }
}

private struct AppAppearanceKey: EnvironmentKey {
    static let defaultValue = AppAppearance.current
}

extension EnvironmentValues {
    var appAppearance: AppAppearance {
        get { self[AppAppearanceKey.self] }
        set { self[AppAppearanceKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appAppearance) private var appearance
    let font: Font

    func body(content: Content) -> some View {
        content.font(font.scaled(by: appearance.textSize.scaleFactor))
    }
}

extension View {
    /// Applies the app text-size preference in addition to the user's Dynamic Type setting.
    func appFont(_ font: Font) -> some View {
        modifier(AppFontModifier(font: font))
    }
}

struct ReadingTheme {
    var style: ReadingThemeStyle = .classic
    var textSize: ReaderTextSize = .standard

    func scaledFont(_ font: Font) -> Font {
        font.scaled(by: textSize.scaleFactor)
    }
}

struct ReaderPresentation {
    let readingTheme: ReadingTheme
    let searchHighlight: String?
}

// MARK: - Chapter Theme
struct ChapterTheme {
    let accent: Color
    let accentLight: Color
    let checkBorderColor: Color

    static let themes: [ChapterTheme] = [
        ChapterTheme(accent: .unionNavy, accentLight: .unionWhite, checkBorderColor: .unionNavy),
        ChapterTheme(accent: .unionRed, accentLight: .unionWhite, checkBorderColor: .unionRed),
        ChapterTheme(accent: .unionNavy, accentLight: .unionWhite, checkBorderColor: .unionNavy),
        ChapterTheme(accent: .unionRed, accentLight: .unionWhite, checkBorderColor: .unionRed),
        ChapterTheme(accent: .unionNavy, accentLight: .unionWhite, checkBorderColor: .unionNavy),
    ]

    static func forChapter(_ index: Int) -> ChapterTheme {
        themes[min(index, themes.count - 1)]
    }
}
