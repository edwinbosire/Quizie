import SwiftUI

struct StreakResultView: View {
    let engine: QuizEngine
    let onReturnHome: () -> Void

    private var clearedQuestionBank: Bool {
        engine.totalQuestions > 0 && engine.currentStreak == engine.totalQuestions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    Image(systemName: clearedQuestionBank ? "trophy.fill" : "flame.slash.fill")
                        .appFont(.system(size: 44, weight: .bold))
                        .foregroundStyle(clearedQuestionBank ? Color(hex: "#F5A623") : Color(hex: "#E74C3C"))
                        .frame(width: 92, height: 92)
                        .background(Color.white.opacity(0.2), in: Circle())

                    Text(clearedQuestionBank ? "Perfect Streak!" : "Streak Ended")
                        .appFont(.system(.largeTitle, design: .serif, weight: .bold))
                    Text(clearedQuestionBank ? "You cleared every question in the bank." : "One wrong answer ended this run. Start over and see if you can go further.")
                        .appFont(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .padding(.bottom, 34)
                .background(LinearGradient(colors: [Color(hex: "#E85D3F"), Color(hex: "#F5A623")], startPoint: .topLeading, endPoint: .bottomTrailing))

                HStack(spacing: 12) {
                    StreakMetric(title: "THIS STREAK", value: engine.currentStreak, icon: "flame.fill")
                    StreakMetric(title: "PERSONAL BEST", value: engine.bestStreak, icon: "trophy.fill")
                }
                .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    Button(action: engine.startStreak) {
                        Label("Start Over", systemImage: "arrow.clockwise")
                            .appFont(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#E67E22"), in: RoundedRectangle(cornerRadius: HBRadius.md))
                    }
                    .accessibilityIdentifier("quiz.streak.restart")

                    Button(action: onReturnHome) {
                        Label("Return to Home", systemImage: "house")
                            .appFont(.subheadline)
                            .foregroundStyle(Color.hbTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 48)
        }
        .background(Color.hbBackground)
        .ignoresSafeArea(edges: .top)
    }
}

private struct StreakMetric: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .appFont(.title3.weight(.semibold))
                .foregroundStyle(Color(hex: "#E67E22"))
            Text("\(value)")
                .appFont(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.hbTextPrimary)
            Text(title)
                .appFont(.caption2.weight(.semibold))
                .foregroundStyle(Color.hbTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.hbSurface, in: RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder))
    }
}

#Preview("Streak Result") {
    let defaults = UserDefaults(suiteName: "StreakResultPreview")!
    let engine = QuizEngine(questionRepository: InMemoryQuestionRepository([]), statisticsDefaults: defaults)
    return StreakResultView(engine: engine, onReturnHome: {})
}
