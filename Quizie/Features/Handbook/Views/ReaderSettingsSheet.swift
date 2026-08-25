import SwiftUI

struct ReaderSettingsSheet: View {
    @Binding var themeStyle: ReadingThemeStyle
    @Binding var textSize: ReaderTextSize
    let qualityAnalysis: ContentQualityAnalysis?
    @AppStorage(ContentReviewSettings.storageKey) private var contentReviewModeEnabled = false

    init(themeStyle: Binding<ReadingThemeStyle>, textSize: Binding<ReaderTextSize>, qualityAnalysis: ContentQualityAnalysis? = nil) {
        _themeStyle = themeStyle
        _textSize = textSize
        self.qualityAnalysis = qualityAnalysis
    }

    private var readingTheme: ReadingTheme {
        ReadingTheme(style: themeStyle, textSize: textSize)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 24) {
                        // Font Size Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("TEXT SIZE")
                                .appFont(.caption2.weight(.semibold))
                                .foregroundColor(.hbTextMuted)

                            Picker("Reader text size", selection: $textSize) {
                                ForEach(ReaderTextSize.allCases) { size in
                                    Text(size.name)
                                        .accessibilityIdentifier("reader.textSize.\(size.rawValue)")
                                        .tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("reader.textSize")
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.hbBorder)
                            .frame(height: 1)

                        // Theme Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("THEME")
                                .appFont(.caption2.weight(.semibold))
                                .foregroundColor(.hbTextMuted)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                                ForEach(ReadingThemeStyle.allCases) { style in
                                    ThemeOption(style: style, isSelected: themeStyle == style) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            themeStyle = style
                                        }
                                    }
                                }
                            }
                        }

                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREVIEW")
                                .appFont(.caption2.weight(.semibold))
                                .foregroundColor(.hbTextMuted)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("The United Kingdom")
                                    .font(readingTheme.scaledFont(.system(.headline, design: .serif, weight: .semibold)))
                                    .foregroundColor(themeStyle.textPrimary)

                                Text("A constitutional monarchy with a rich history spanning over a thousand years of tradition, culture and democratic governance.")
                                    .font(readingTheme.scaledFont(.body))
                                    .foregroundColor(themeStyle.textSecondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeStyle.surface)
                            .overlay(RoundedRectangle(cornerRadius: HBRadius.sm).stroke(themeStyle.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
                        }

                        if let qualityAnalysis {
                            Rectangle()
                                .fill(Color.hbBorder)
                                .frame(height: 1)

                            VStack(alignment: .leading, spacing: 14) {
                                Text("CONTENT QUALITY")
                                    .appFont(.caption2.weight(.semibold))
                                    .foregroundColor(.hbTextMuted)

                                Toggle(isOn: $contentReviewModeEnabled) {
                                    Label("Content review mode", systemImage: "checkmark.shield")
                                        .appFont(.callout.weight(.semibold))
                                        .foregroundStyle(Color.hbTextPrimary)
                                }
                                .tint(Color.hbAccent)
                                .accessibilityIdentifier("settings.contentReviewMode")

                                Text("Shows issue-reporting tools on questions and bundled flashcards. Reports are composed in your email app and sent only when you choose Send.")
                                    .appFont(.caption)
                                    .foregroundStyle(Color.hbTextMuted)

                                if contentReviewModeEnabled {
                                    NavigationLink {
                                        ContentQualityReviewView(analysis: qualityAnalysis)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "waveform.path.ecg.rectangle")
                                                .appFont(.headline.weight(.semibold))
                                                .foregroundStyle(Color.hbAccent)
                                                .frame(width: 40, height: 40)
                                                .background(Color.hbAccentLight, in: RoundedRectangle(cornerRadius: HBRadius.sm))

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Open quality analysis")
                                                    .appFont(.callout.weight(.semibold))
                                                    .foregroundStyle(Color.hbTextPrimary)
                                                Text("\(qualityAnalysis.findings.count) automated findings")
                                                    .appFont(.caption)
                                                    .foregroundStyle(Color.hbTextMuted)
                                            }

                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .appFont(.caption.weight(.semibold))
                                                .foregroundStyle(Color.hbTextMuted)
                                        }
                                        .padding(12)
                                        .background(Color.hbSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: HBRadius.md)
                                                .stroke(Color.hbBorder, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("settings.contentQualityAnalysis")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityIdentifier("reader.settings")
            .background(Color.hbBackground)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
    }
}

// MARK: - Theme Option Button

struct ThemeOption: View {
    let style: ReadingThemeStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Swatch circle
                ZStack {
                    Circle()
                        .fill(style.swatchColor)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.hbAccent : style.swatchBorder, lineWidth: isSelected ? 2.5 : 1)
                        )

                    // Text lines preview
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(style.textPrimary.opacity(0.5))
                            .frame(width: 20, height: 2.5)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(style.textSecondary.opacity(0.4))
                            .frame(width: 16, height: 2)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(style.textSecondary.opacity(0.3))
                            .frame(width: 18, height: 2)
                    }
                }

                // Label
                Text(style.name)
                    .appFont(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .hbAccent : .hbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("app.theme.\(style.rawValue)")
    }
}

// MARK: - Preview

#Preview {
    ReaderSettingsSheet(
        themeStyle: .constant(.classic),
        textSize: .constant(.standard)
    )
}
