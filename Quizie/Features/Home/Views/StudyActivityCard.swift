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
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.hbTextPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(metric)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(accent)
                        .monospacedDigit()

                    Text(metricLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.hbTextMuted)
                        .textCase(.uppercase)
                }

                Divider()

                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hbTextSecondary)
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
