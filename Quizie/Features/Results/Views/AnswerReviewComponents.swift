import SwiftUI

struct AnswerReviewRow: View {
    let index: Int
    let question: QuizQuestion
    let answer: UserAnswer?

    var isCorrect: Bool { answer?.isCorrect ?? false }
    var wasAnswered: Bool { answer != nil }

    @State private var expanded = false

    var rowAccent: Color { isCorrect ? Color(hex: "#145A32") : Color(hex: "#922B21") }
    var rowBg: Color    { isCorrect ? Color(hex: "#D5F5E3") : Color(hex: "#FADBD8") }
    var rowBorder: Color{ isCorrect ? Color(hex: "#A9DFBF") : Color(hex: "#F1948A") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row header (always visible, tappable to expand)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Number + status
                    ZStack {
                        Circle()
                            .fill(rowBg)
                            .frame(width: 34, height: 34)
                        if isCorrect {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(rowAccent)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(rowAccent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Q\(index)")
                            .font(HBFont.sans(11, weight: .semibold))
                            .kerning(0.5)
                            .foregroundColor(rowAccent.opacity(0.75))
                        Text(question.question)
                            .font(HBFont.sans(14))
                            .foregroundColor(.hbTextPrimary)
                            .lineLimit(expanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.hbTextMuted)
                        .padding(.top, 4)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            // Expanded detail (wrong answers only auto-expand hint, but all are expandable)
            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(rowBorder)

                    // User's answer
                    if let answer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR ANSWER")
                                .font(HBFont.sans(10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundColor(.hbTextMuted)
                            ForEach(Array(answer.selectedIndices).sorted(), id: \.self) { idx in
                                AnswerChip(
                                    text: question.choices[safe: idx] ?? "—",
                                    style: isCorrect ? .correct : .wrong
                                )
                            }
                        }
                    }

                    // Correct answer (shown only if wrong, or as confirmation if correct)
                    if !isCorrect {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CORRECT ANSWER")
                                .font(HBFont.sans(10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundColor(.hbTextMuted)
                            ForEach(Array(question.correctIndices).sorted(), id: \.self) { idx in
                                AnswerChip(
                                    text: question.choices[safe: idx] ?? "—",
                                    style: .correct
                                )
                            }
                        }

                        // Explanation (handbook hint)
                        ExplanationBox(question: question)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(rowBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Answer Chip
enum AnswerChipStyle { case correct, wrong, neutral }

struct AnswerChip: View {
    let text: String
    let style: AnswerChipStyle

    var fg: Color {
        switch style {
        case .correct: return Color(hex: "#145A32")
        case .wrong:   return Color(hex: "#922B21")
        case .neutral: return Color.hbTextSecondary
        }
    }
    var bg: Color {
        switch style {
        case .correct: return Color(hex: "#D5F5E3")
        case .wrong:   return Color(hex: "#FADBD8")
        case .neutral: return Color.hbSurface2
        }
    }
    var icon: String {
        switch style {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        case .neutral: return "circle"
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(fg)
            Text(text)
                .font(HBFont.sans(14))
                .foregroundColor(fg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .cornerRadius(HBRadius.sm)
    }
}

// MARK: - Explanation Box
struct ExplanationBox: View {
    let question: QuizQuestion

    // Generate a contextual explanation based on correct answer + question text
    var explanationText: String {
        let answers = question.correctChoices.joined(separator: " and ")
        if !question.year.isEmpty {
            return "The correct answer is \(answers). This occurred in \(question.year). Review the relevant section of the handbook for more detail."
        }
        return "The correct answer is \(answers). Review the relevant section of the handbook to understand why."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#6E2C00"))
                Text("EXPLANATION")
                    .font(HBFont.sans(10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundColor(Color(hex: "#6E2C00"))
            }
            Text(explanationText)
                .font(HBFont.sans(13))
                .foregroundColor(Color(hex: "#6E2C00"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(hex: "#F5E6DA"))
        .cornerRadius(HBRadius.sm)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.sm).stroke(Color(hex: "#E0B89A"), lineWidth: 1))
    }
}

// MARK: - Confetti View
