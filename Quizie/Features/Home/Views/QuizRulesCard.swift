import SwiftUI

struct RulesCard: View {
    let engine: QuizEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BEFORE YOU START")
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1.5)
                .foregroundColor(.hbTextMuted)

            VStack(alignment: .leading, spacing: 8) {
                RuleItem(icon: "1.circle", text: "Read each question carefully before answering")
                RuleItem(icon: "2.circle", text: "Some questions require TWO correct answers — select all that apply")
                RuleItem(icon: "3.circle", text: "You cannot go back to a previous question")
                RuleItem(icon: "4.circle", text: "The exam ends when you answer all \(engine.configuration.questionCount) questions or time runs out")
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
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.hbAccent)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(HBFont.sans(14))
                .foregroundColor(.hbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Performance Summary
