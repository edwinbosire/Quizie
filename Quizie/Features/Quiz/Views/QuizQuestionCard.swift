import SwiftUI

struct QuestionCard: View {
    let question: QuizQuestion
    let questionIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
			HStack {
				// Multi-select hint
				if question.isMultiSelect {
					HStack(spacing: 6) {
						Image(systemName: "checkmark.square.fill")
							.appFont(.caption)
							.foregroundColor(Color(hex: "#512E5F"))
						Text("SELECT \(question.correctIndices.count) ANSWERS")
							.appFont(.caption2.weight(.semibold))
							.foregroundColor(Color(hex: "#512E5F"))
					}
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(Color(hex: "#EAD9F5"))
					.cornerRadius(20)
				}

				Spacer()
				VStack(alignment: .trailing, spacing: 2) {
					Text("\(questionIndex + 1) / 24")
						.appFont(.caption2.weight(.semibold))
						.foregroundColor(.hbTextMuted)
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(Color.hbBackground, in: Capsule())
				}

			}

            Text(question.question)
                .appFont(.studyPrompt)
                .foregroundColor(.hbTextPrimary)

            // Year hint
//            if !question.year.isEmpty {
//                HStack(spacing: 5) {
//                    Image(systemName: "calendar")
//                        .appFont(.caption2)
//                    Text("Hint: \(question.year)")
//                        .appFont(.footnote)
//                }
//                .foregroundColor(.hbTextMuted)
//            }
        }
        .padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Choice Options
struct ChoicesView: View {
    let engine: QuizEngine
    let question: QuizQuestion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        engine.toggleChoice(idx, isMultiSelect: question.isMultiSelect)
                    }
                } label: {
                    ChoiceButton(
                        label: choiceLabel(idx),
                        text: choice,
                        isSelected: engine.selectedIndices.contains(idx),
                        isMultiSelect: question.isMultiSelect,
                        isCorrect: engine.hasSubmittedAnswer ? question.correctIndices.contains(idx) : nil,
                        hasSubmitted: engine.hasSubmittedAnswer
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quiz.choice.\(idx)")
                .disabled(engine.hasSubmittedAnswer)
                .accessibilityValue(engine.selectedIndices.contains(idx) ? "Selected" : "Not selected")
                .accessibilityAddTraits(engine.selectedIndices.contains(idx) ? .isSelected : [])
                .sensoryFeedback(.selection, trigger: engine.selectedIndices.contains(idx))
				.staggered(0.2 + (0.1 * Double(idx)))
            }
        }
    }

    func choiceLabel(_ idx: Int) -> String {
        ["A", "B", "C", "D", "E"][safe: idx] ?? "\(idx + 1)"
    }
}


// MARK: - Choice Button
struct ChoiceButton: View {
    let label: String
    let text: String
    let isSelected: Bool
    let isMultiSelect: Bool
    let isCorrect: Bool?  // nil before submission, true/false after
    let hasSubmitted: Bool
    
    // Visual state after submission
    var feedbackColor: Color? {
        guard hasSubmitted, let isCorrect = isCorrect else { return nil }
        return isCorrect ? Color(hex: "#27AE60") : nil  // Show green for correct answers
    }
    
    var feedbackBackgroundColor: Color? {
        guard hasSubmitted, let isCorrect = isCorrect else { return nil }
        return isCorrect ? Color(hex: "#D5F4E6") : nil  // Light green background
    }
    
    var shouldShowAsWrong: Bool {
        hasSubmitted && isSelected && isCorrect == false
    }

    var body: some View {
        HStack(spacing: 14) {
            // Label circle or checkbox
            ZStack {
                if isMultiSelect {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(feedbackColor ?? (isSelected ? Color.hbAccent : Color.hbSurface2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(feedbackColor ?? (isSelected ? Color.hbAccent : Color.hbBorder), lineWidth: 1.5)
                        )
                    if isSelected || (hasSubmitted && isCorrect == true) {
                        Image(systemName: "checkmark")
                            .appFont(.caption.weight(.bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Circle()
                        .fill(feedbackColor ?? (isSelected ? Color.hbAccent : Color.hbSurface2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(feedbackColor ?? (isSelected ? Color.hbAccent : Color.hbBorder), lineWidth: 1.5)
                        )
                    if hasSubmitted && isCorrect == true {
                        Image(systemName: "checkmark")
                            .appFont(.caption.weight(.bold))
                            .foregroundColor(.white)
                    } else {
                        Text(label)
                            .appFont(.footnote.weight(.semibold))
                            .foregroundColor(feedbackColor != nil ? .white : (isSelected ? .white : .hbTextMuted))
                    }
                }
            }

            Text(text)
                .appFont(.subheadline)
                .foregroundColor(feedbackColor ?? (isSelected ? Color.hbTextPrimary : Color.hbTextSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show X icon for wrong selections
            if shouldShowAsWrong {
                Image(systemName: "xmark.circle.fill")
                    .appFont(.callout.weight(.bold))
                    .foregroundColor(Color(hex: "#E74C3C"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(feedbackBackgroundColor ?? (isSelected ? Color.hbAccentLight : Color.hbSurface))
        .cornerRadius(HBRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.sm)
                .stroke(
                    shouldShowAsWrong ? Color(hex: "#E74C3C") : (feedbackColor ?? (isSelected ? Color.hbAccent : Color.hbBorder)),
                    lineWidth: (isSelected || feedbackColor != nil || shouldShowAsWrong) ? 1.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.06 : 0.03), radius: 3, x: 0, y: 1)
        .scaleEffect(isSelected ? 1.0 : 1.0)
        .phaseAnimator(
            [CGFloat.zero, -10, 10, -8, 8, 0],
            trigger: shouldShowAsWrong
        ) { content, offset in
            content.offset(x: offset)
        } animation: { _ in
            .spring(response: 0.2, dampingFraction: 0.3)
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.3), value: hasSubmitted)
        .sensoryFeedback(.success, trigger: hasSubmitted && isCorrect == true && isSelected)
        .sensoryFeedback(.error, trigger: shouldShowAsWrong)
    }
}

// MARK: - Submit Button
