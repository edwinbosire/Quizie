# Native Adaptive Typography

Quizie uses SwiftUI's semantic system fonts directly so text inherits Dynamic Type, Bold Text, adaptive tracking, and system leading.

## Style roles

| Content role | SwiftUI style |
| --- | --- |
| Primary screen header | `.largeTitle` |
| Major section header | `.title` |
| Subsection header | `.title2` |
| Card or group title | `.title3` |
| Emphasized content | `.headline` |
| Paragraph or interactive text | `.body` |
| Secondary prominent text | `.callout` |
| Minor description | `.subheadline` |
| Auxiliary or legal text | `.footnote` |
| Metadata, badges, and hints | `.caption` / `.caption2` |

Use `.bold()`, `.italic()`, or `.fontWeight(.semibold)` only when the content hierarchy calls for emphasis. Editorial headings and quotations use the system serif design, scores may use rounded, and timers or changing values use `monospacedDigit()`.

## Reader presets

Handbook content supports Small, Standard, and Large presets. They scale the selected semantic style by 0.90, 1.00, and 1.15 respectively with `Font.scaled(by:)`, so the preset compounds with the user's Dynamic Type setting instead of replacing it.

## Rules

- Do not use fixed point sizes, `pointSize(_:)`, custom fonts, or a Dynamic Type environment override for user-visible text.
- Do not add manual tracking or line spacing to system text styles.
- Let important and interactive text wrap vertically instead of shrinking or truncating it.
- Let meaningful SF Symbols inherit the surrounding text style; fixed dimensions are reserved for decorative artwork.

## References

- [Apple Typography Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/typography)
- [SwiftUI Font documentation](https://developer.apple.com/documentation/swiftui/font)
