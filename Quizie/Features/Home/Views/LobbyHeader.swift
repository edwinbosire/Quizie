import SwiftUI

struct LobbyHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
			Color.hbAccent

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -50)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -30, y: 140)

			VStack(alignment: .leading, spacing: 16) {
				Text("PRACTICE TEST")
					.font(HBFont.sans(11, weight: .semibold))
					.kerning(2)
					.foregroundColor(Color.white.opacity(0.6))
					.frame(maxWidth: .infinity, alignment: .leading)

                Text("Life in the UK\nPractice Exam")
                    .font(HBFont.lora(30))
                    .foregroundColor(.white)
                    .lineSpacing(4)

                Text("Test your knowledge with a full-length timed exam, just like the real thing.")
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Exam Info Bar (Compact)
struct ExamInfoBar: View {
    let engine: QuizEngine

    var body: some View {
        HStack(spacing: 0) {
            ExamInfoItem(icon: "questionmark.circle.fill", value: "\(engine.configuration.questionCount)", label: "Questions", color: .hbAccent)
            ExamInfoDivider()
            ExamInfoItem(icon: "clock.fill", value: "\(engine.configuration.durationMinutes) min", label: "Time Limit", color: Color(hex: "#145A32"))
            ExamInfoDivider()
            ExamInfoItem(icon: "checkmark.seal.fill", value: "\(engine.configuration.passPercentage)%", label: "Pass Mark", color: Color(hex: "#6E2C00"))
            ExamInfoDivider()
            ExamInfoItem(icon: "shuffle", value: "Random", label: "Order", color: Color(hex: "#512E5F"))
        }
        .padding(.vertical, 14)
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder, lineWidth: 1))
    }
}

private struct ExamInfoItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(HBFont.sans(14, weight: .semibold))
                .foregroundColor(.hbTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(HBFont.sans(10))
                .foregroundColor(.hbTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExamInfoDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hbBorder)
            .frame(width: 1, height: 36)
    }
}

// MARK: - Rules Card
