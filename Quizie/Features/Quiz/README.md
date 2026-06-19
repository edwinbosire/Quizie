# Life in the UK Handbook & Practice Test — SwiftUI App

A mobile-first SwiftUI implementation of the Life in the UK handbook, matching the HTML design exactly.

---

## Project Structure

```
HandbookApp/
├── HandbookApp.swift              # App entry point
├── DesignSystem.swift             # Colors, fonts, spacing tokens
├── Models/
│   └── HandbookData.swift         # All content + data models
├── Components/
│   └── Components.swift           # Reusable UI components
└── Views/
    ├── HomeView.swift              # Home screen (chapter list)
    └── ChapterView.swift          # Chapter detail + section tabs
```

---

## Design System

All design tokens match the original CSS variables:

| CSS Variable         | Swift                    | Value        |
|----------------------|--------------------------|--------------|
| `--bg`               | `Color.hbBackground`     | `#F7F5F0`    |
| `--surface`          | `Color.hbSurface`        | `#FFFFFF`    |
| `--surface-2`        | `Color.hbSurface2`       | `#F0EDE6`    |
| `--border`           | `Color.hbBorder`         | `#E2DDD4`    |
| `--text-primary`     | `Color.hbTextPrimary`    | `#1A1814`    |
| `--text-secondary`   | `Color.hbTextSecondary`  | `#3D3830`    |
| `--text-muted`       | `Color.hbTextMuted`      | `#8C8478`    |
| `--accent`           | `Color.hbAccent`         | `#1B4F72`    |
| `--accent-light`     | `Color.hbAccentLight`    | `#D6E8F5`    |

### Chapter Accent Colours

| Chapter | Accent     | Light      |
|---------|------------|------------|
| 1       | `#1B4F72`  | `#D6E8F5`  |
| 2       | `#1A5276`  | `#D4E6F1`  |
| 3       | `#6E2C00`  | `#F5E6DA`  |
| 4       | `#145A32`  | `#D5F5E3`  |
| 5       | `#512E5F`  | `#EAD9F5`  |

---

## Fonts Required

The app uses **Lora** (serif, for headings) and **Source Sans 3** (sans-serif, for body).

### Option A: Download and add font files to Xcode

1. Download from Google Fonts:
   - [Lora](https://fonts.google.com/specimen/Lora) — download `Lora-Regular.ttf`, `Lora-SemiBold.ttf`, `Lora-Italic.ttf`
   - [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3) — download `SourceSans3-Regular.ttf`, `SourceSans3-Medium.ttf`, `SourceSans3-SemiBold.ttf`

2. Drag the `.ttf` files into your Xcode project (ensure "Add to target" is checked)

3. Add entries to `Info.plist`:
```xml
<key>UIAppFonts</key>
<array>
    <string>Lora-Regular.ttf</string>
    <string>Lora-SemiBold.ttf</string>
    <string>Lora-Italic.ttf</string>
    <string>SourceSans3-Regular.ttf</string>
    <string>SourceSans3-Medium.ttf</string>
    <string>SourceSans3-SemiBold.ttf</string>
</array>
```

### Option B: Use system fallbacks (no setup required)

In `DesignSystem.swift`, update `HBFont` to use system fonts while preserving the weight/size system:

```swift
struct HBFont {
    static func lora(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func loraItalic(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
```

---

## How to Open in Xcode

1. Create a new Xcode project: **File → New → Project → iOS App**
   - Product Name: `HandbookApp`
   - Interface: SwiftUI
   - Language: Swift

2. Delete the default `ContentView.swift`

3. Drag all `.swift` files from this folder into the project, maintaining the folder structure

4. Add fonts if using Option A above

5. Build and run on iPhone simulator or device (iOS 16+)

---

---

## Quiz / Practice Test

The app includes a full practice exam that mirrors the real Life in the UK test.

### Features
- **24 questions** randomly drawn from a pool of 1,014 questions
- **45-minute countdown timer** with a red warning in the last 5 minutes
- **Pass mark: 18/24** — clearly indicated on the results screen
- **Multi-select questions** automatically detected (e.g. "Which TWO…")
- **Animated transitions** between questions (slide in/out)
- **Results screen** — two distinct designs for pass (navy) and fail (red)
- **Answer review** — expandable list of all 24 questions showing:
  - ✓ Correct answers (green)
  - ✗ Wrong answers (red) — including what the correct answer was and a contextual explanation

### Adding the Questions File
Add `questions.json` to your Xcode project:
1. Drag `Quiz/Resources/questions.json` into Xcode
2. Ensure **"Add to target: HandbookApp"** is checked
3. Ensure **"Copy items if needed"** is checked

The `QuestionBank` class will automatically load and shuffle questions at exam start.

---

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+
