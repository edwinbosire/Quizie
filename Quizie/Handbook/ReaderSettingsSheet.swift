import SwiftUI

struct ReaderSettingsSheet: View {
    @Binding var themeStyle: ReadingThemeStyle
    @Binding var fontSizeAdjustment: CGFloat

    private let minAdjustment: CGFloat = -2
    private let maxAdjustment: CGFloat = 4

    var body: some View {
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
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)

                    HStack(spacing: 16) {
                        // Small A
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                fontSizeAdjustment = max(minAdjustment, fontSizeAdjustment - 1)
                            }
                        } label: {
                            Text("A")
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundColor(fontSizeAdjustment <= minAdjustment ? .hbTextMuted.opacity(0.4) : .hbTextSecondary)
                                .frame(width: 40, height: 40)
                                .background(Color.hbSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
                        }
                        .disabled(fontSizeAdjustment <= minAdjustment)

                        // Slider
                        Slider(
                            value: $fontSizeAdjustment,
                            in: minAdjustment...maxAdjustment,
                            step: 1
                        )
                        .tint(Color.hbAccent)

                        // Large A
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                fontSizeAdjustment = min(maxAdjustment, fontSizeAdjustment + 1)
                            }
                        } label: {
                            Text("A")
                                .font(.system(size: 22, weight: .medium, design: .serif))
                                .foregroundColor(fontSizeAdjustment >= maxAdjustment ? .hbTextMuted.opacity(0.4) : .hbTextSecondary)
                                .frame(width: 40, height: 40)
                                .background(Color.hbSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
                        }
                        .disabled(fontSizeAdjustment >= maxAdjustment)
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.hbBorder)
                    .frame(height: 1)

                // Theme Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("THEME")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)

                    HStack(spacing: 12) {
                        ForEach(ReadingThemeStyle.allCases) { style in
                            ThemeOption(
                                style: style,
                                isSelected: themeStyle == style,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        themeStyle = style
                                    }
                                }
                            )
                        }
                    }
                }

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("PREVIEW")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("The United Kingdom")
                            .font(HBFont.lora(18 + fontSizeAdjustment))
                            .foregroundColor(themeStyle.textPrimary)

                        Text("A constitutional monarchy with a rich history spanning over a thousand years of tradition, culture and democratic governance.")
                            .font(HBFont.sans(16 + fontSizeAdjustment))
                            .foregroundColor(themeStyle.textSecondary)
                            .lineSpacing(6 + (fontSizeAdjustment * 0.5))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: HBRadius.sm)
                            .stroke(themeStyle.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.hbBackground)
        .presentationDetents([.height(420)])
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
                    .font(HBFont.sans(12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .hbAccent : .hbTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ReaderSettingsSheet(
                themeStyle: .constant(.classic),
                fontSizeAdjustment: .constant(0)
            )
        }
}
