import SwiftUI

struct MockExamInstructionsView: View {
    let configuration: QuizConfiguration
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                RulesCard(configuration: configuration)
            }
            .padding(20)
        }
        .background(Color.hbBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button(action: onStart) {
                Label("Start mock exam", systemImage: "checklist.checked")
                    .appFont(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.hbAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("quiz.instructions.start")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .appFont(.headline.weight(.semibold))
                    .foregroundStyle(Color.hbTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.hbSurface, in: Circle())
                    .overlay { Circle().stroke(Color.hbBorder) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("quiz.instructions.back")

            VStack(alignment: .leading, spacing: 8) {
                Text("Mock exam")
                    .appFont(.caption.weight(.semibold))
                    .foregroundStyle(Color.hbAccent)
                    .textCase(.uppercase)
                Text("Before you start")
                    .appFont(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.hbTextPrimary)
                Text("You’ll have \(configuration.durationMinutes) minutes to answer \(configuration.questionCount) questions. You need \(configuration.passMarkCount) correct answers to pass.")
                    .appFont(.body)
                    .foregroundStyle(Color.hbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RulesCard: View {
    let configuration: QuizConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BEFORE YOU START")
                .appFont(.caption2.weight(.semibold))
                .foregroundColor(.hbTextMuted)

            VStack(alignment: .leading, spacing: 8) {
                RuleItem(icon: "1.circle", text: "Read each question carefully before answering")
                RuleItem(icon: "2.circle", text: "Some questions require TWO correct answers — select all that apply")
                RuleItem(icon: "3.circle", text: "You cannot go back to a previous question")
                RuleItem(icon: "4.circle", text: "The exam ends when you answer all \(configuration.questionCount) questions or time runs out")
            }
        }
        .padding(18)
        .background(Color.hbSurface2)
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder, lineWidth: 1))
    }
}

struct RuleItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .appFont(.subheadline.weight(.medium))
                .foregroundColor(.hbAccent)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .appFont(.footnote)
                .foregroundColor(.hbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Mock Exam Instructions") {
    MockExamInstructionsView(configuration: .mock, onStart: {}, onCancel: {})
}

// MARK: - Performance Summary
