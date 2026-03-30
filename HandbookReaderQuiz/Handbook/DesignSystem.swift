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

// MARK: - Reading Theme (user-selectable page appearance)
enum ReadingThemeStyle: String, CaseIterable, Identifiable {
    case classic  // Original warm parchment
    case paper    // Pure white, clean
    case sepia    // Deep warm sepia
    case night    // Dark mode

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

// MARK: - Reading Theme Environment
struct ReadingTheme {
    var style: ReadingThemeStyle = .classic
    var fontSizeAdjustment: CGFloat = 0  // -2 to +4 offset applied to body text sizes
}

struct ReadingThemeKey: EnvironmentKey {
    static let defaultValue = ReadingTheme()
}

extension EnvironmentValues {
    var readingTheme: ReadingTheme {
        get { self[ReadingThemeKey.self] }
        set { self[ReadingThemeKey.self] = newValue }
    }
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
