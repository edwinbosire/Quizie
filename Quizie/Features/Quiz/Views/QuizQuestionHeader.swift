import SwiftUI

struct QuizTopBar: View {
    let engine: QuizEngine
    let onOptionsPressed: () -> Void
    let onClosePressed: () -> Void
    
    @State private var optionsButtonPressed = false
    @State private var closeButtonPressed = false

	var body: some View {
        VStack(spacing: 0) {
            HStack {

                // Timer or current streak
                HStack(spacing: 6) {
                    Image(systemName: engine.isStreakMode ? "flame.fill" : "clock.fill")
                        .appFont(.footnote)
                        .foregroundColor(engine.isStreakMode ? Color(hex: "#E67E22") : (engine.isTimeWarning ? Color(hex: "#C0392B") : .hbTextMuted))
                    Text(engine.isStreakMode ? String(format: "Streak %d", engine.currentStreak) : engine.formattedTime)
                        .appFont(.footnote.weight(.semibold))
                        .foregroundColor(engine.isStreakMode ? Color(hex: "#A04000") : (engine.isTimeWarning ? Color(hex: "#C0392B") : .hbTextPrimary))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(engine.isStreakMode ? Color(hex: "#FEF0E3") : (engine.isTimeWarning ? Color(hex: "#FDEDEC") : Color.hbSurface))
                .cornerRadius(HBRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: HBRadius.sm)
                        .stroke(engine.isStreakMode ? Color(hex: "#F5B77B") : (engine.isTimeWarning ? Color(hex: "#F1948A") : Color.hbBorder), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.3), value: engine.isTimeWarning)

				Spacer()

                Button(action: {
                    optionsButtonPressed.toggle()
                    onOptionsPressed()
                }) {
                    Image(systemName: "ellipsis.circle")
                        .appFont(.title2)
                        .foregroundColor(.hbTextSecondary)
                }
                .padding(.leading, 8)
                .accessibilityLabel("Quiz options")
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: optionsButtonPressed)

                Button(action: {
                    closeButtonPressed.toggle()
                    onClosePressed()
                }) {
                    Image(systemName: "xmark")
                        .appFont(.title2.weight(.medium))
                        .foregroundColor(.hbTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Quit quiz")
                .accessibilityHint("Shows a confirmation before quitting")
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: closeButtonPressed)
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
    let questions: [QuizQuestion]
    let answers: [String: UserAnswer]
    let currentIndex: Int

    private var segmentStates: [QuizProgressSegmentState] {
        questions.enumerated().map { index, question in
            if let answer = answers[question.id] {
                return answer.isCorrect ? .correct : .incorrect
            }
            return index == currentIndex ? .current : .unanswered
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: segmentSpacing(for: geometry.size.width)) {
                ForEach(Array(segmentStates.enumerated()), id: \.offset) { _, state in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(state.color)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.hbBackground)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .animation(.easeInOut(duration: 0.25), value: answers.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quiz progress")
        .accessibilityValue("Question \(min(currentIndex + 1, questions.count)) of \(questions.count), \(answers.count) answered")
    }

    private func segmentSpacing(for width: CGFloat) -> CGFloat {
        guard !questions.isEmpty else { return 0 }
        return min(3, max(0, width / CGFloat(questions.count) * 0.25))
    }
}

enum QuizProgressSegmentState {
    case unanswered
    case current
    case correct
    case incorrect

    var color: Color {
        switch self {
        case .unanswered: return .hbBorder
        case .current: return .hbAccent
        case .correct: return Color(hex: "#27AE60")
        case .incorrect: return Color(hex: "#E74C3C")
        }
    }
}

// MARK: - Question Card
