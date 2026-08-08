import SwiftUI

struct QuizTopBar: View {
    let engine: QuizEngine
    let onOptionsPressed: () -> Void
    
    @State private var optionsButtonPressed = false

	var body: some View {
        VStack(spacing: 0) {
            HStack {

                // Timer
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.footnote)
                        .foregroundColor(engine.isTimeWarning ? Color(hex: "#C0392B") : .hbTextMuted)
                    Text(engine.formattedTime)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(engine.isTimeWarning ? Color(hex: "#C0392B") : .hbTextPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(engine.isTimeWarning ? Color(hex: "#FDEDEC") : Color.hbSurface)
                .cornerRadius(HBRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: HBRadius.sm)
                        .stroke(engine.isTimeWarning ? Color(hex: "#F1948A") : Color.hbBorder, lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.3), value: engine.isTimeWarning)

				Spacer()
                // Options button
                Button(action: {
                    optionsButtonPressed.toggle()
                    onOptionsPressed()
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.hbTextSecondary)
                }
                .padding(.leading, 8)
                .accessibilityLabel("Quiz options")
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: optionsButtonPressed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
            
            Rectangle()
                .fill(Color.hbBorder)
                .frame(height: 1)
        }
        .background(Color.hbBackground)
        .safeAreaPadding(.top)
    }
}

// MARK: - Progress Bar
struct QuizProgressBar: View {
    let current: Int
    let total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        let result = Double(current) / Double(total)
        return result.isFinite ? min(max(result, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.hbBorder)
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.hbAccent)
                    .frame(width: max(0, geo.size.width * fraction), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Question Card
