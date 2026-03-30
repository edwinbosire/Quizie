import SwiftUI

// MARK: - Color Palette (matches CSS variables exactly)
extension Color {
    static let hbBackground    = Color(hex: "#F7F5F0")
    static let hbSurface       = Color(hex: "#FFFFFF")
    static let hbSurface2      = Color(hex: "#F0EDE6")
    static let hbBorder        = Color(hex: "#E2DDD4")
    static let hbTextPrimary   = Color(hex: "#1A1814")
    static let hbTextSecondary = Color(hex: "#3D3830")
    static let hbTextMuted     = Color(hex: "#8C8478")

    // Default (Chapter 1 / global) accent
    static let hbAccent        = Color(hex: "#1B4F72")
    static let hbAccentLight   = Color(hex: "#D6E8F5")

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
}

// MARK: - Typography
struct HBFont {
    /// Lora serif - used for headings
    static func lora(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Lora-SemiBold", size: size)
    }
    static func loraRegular(_ size: CGFloat) -> Font {
        .custom("Lora-Regular", size: size)
    }
    static func loraItalic(_ size: CGFloat) -> Font {
        .custom("Lora-Italic", size: size)
    }

    /// Source Sans 3 - used for body text
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .semibold, .bold: return .custom("SourceSans3-SemiBold", size: size)
        case .medium:          return .custom("SourceSans3-Medium", size: size)
        default:               return .custom("SourceSans3-Regular", size: size)
        }
    }
}

// MARK: - Spacing & Radius
enum HBSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum HBRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let pill: CGFloat = 20
}

// MARK: - Chapter Theme
struct ChapterTheme {
    let accent: Color
    let accentLight: Color
    let checkBorderColor: Color

    static let themes: [ChapterTheme] = [
        ChapterTheme(accent: .ch1Accent, accentLight: .ch1AccentLight, checkBorderColor: Color(hex: "#B8D9EF")),
        ChapterTheme(accent: .ch2Accent, accentLight: .ch2AccentLight, checkBorderColor: Color(hex: "#A9D0E8")),
        ChapterTheme(accent: .ch3Accent, accentLight: .ch3AccentLight, checkBorderColor: Color(hex: "#E0B89A")),
        ChapterTheme(accent: .ch4Accent, accentLight: .ch4AccentLight, checkBorderColor: Color(hex: "#A9DFBF")),
        ChapterTheme(accent: .ch5Accent, accentLight: .ch5AccentLight, checkBorderColor: Color(hex: "#C9A8E0")),
    ]

    static func forChapter(_ index: Int) -> ChapterTheme {
        themes[min(index, themes.count - 1)]
    }
}
