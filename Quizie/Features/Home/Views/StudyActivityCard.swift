import SwiftUI

struct StudyActivityCard: View {
    let title: String
    let icon: String
    let accent: Color
    let accentLight: Color
    let metric: String
    let metricLabel: String
    let detail: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(HBFont.sans(16, weight: .semibold))
                    .foregroundStyle(Color.hbTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(metric)
                        .font(HBFont.lora(27))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(metricLabel)
                        .font(HBFont.sans(11, weight: .semibold))
                        .foregroundStyle(Color.hbTextMuted)
                        .textCase(.uppercase)
                        .kerning(0.7)
                }

                Divider()

                Text(detail)
                    .font(HBFont.sans(12, weight: .semibold))
                    .foregroundStyle(Color.hbTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(12)
            .background(Color.hbSurface)
            .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: HBRadius.md)
                    .stroke(Color.hbBorder, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
