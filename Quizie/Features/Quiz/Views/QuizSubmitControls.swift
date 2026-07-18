import SwiftUI

struct SubmitButton: View {
    @ObservedObject var engine: QuizEngine
    let question: QuizQuestion

    var isLast: Bool { engine.currentIndex == engine.totalQuestions - 1 }
    
    // Only show submit button if answer hasn't been submitted and user has made selections but not enough
    var shouldShowManualSubmit: Bool {
        if engine.hasSubmittedAnswer { return false }
        if question.isMultiSelect {
            // For multi-select, only show if user has selections but not the exact required count
            return !engine.selectedIndices.isEmpty && engine.selectedIndices.count != question.correctIndices.count
        }
        return false // Never show for single choice - auto-submits
    }

    var body: some View {
        if engine.hasSubmittedAnswer {
            // Show different states based on correctness
            if engine.isCurrentAnswerCorrect {
                // Correct answer - auto-advancing
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Correct! Moving to next...")
                        .font(HBFont.sans(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .background(Color(hex: "#27AE60")) // Green for correct
                .cornerRadius(HBRadius.md)
                .shadow(color: Color(hex: "#27AE60").opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                // Incorrect answer - manual advance required
                Button {
                    engine.manualAdvance()
                } label: {
                    HStack(spacing: 8) {
                        Text(isLast ? "Submit Exam" : "Next Question")
                            .font(HBFont.sans(16, weight: .semibold))
                        Image(systemName: isLast ? "checkmark.circle.fill" : "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color(hex: "#E74C3C")) // Red for incorrect
                    .cornerRadius(HBRadius.md)
                    .shadow(color: Color(hex: "#E74C3C").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .sensoryFeedback(.impact, trigger: engine.currentIndex)
            }
        } else if shouldShowManualSubmit {
            // Manual submit button (only for multi-select with wrong count)
            Button {
                engine.submitAndAdvance()
            } label: {
                HStack(spacing: 8) {
                    Text("Submit Answer")
                        .font(HBFont.sans(16, weight: .semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .background(Color.hbBorder)
                .cornerRadius(HBRadius.md)
            }
            .disabled(true) // Keep disabled since they don't have right count
            .opacity(0.6)
        }
    }
}
// MARK: - Quiz Options Sheet
struct QuizOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let question: QuizQuestion?
    let isBookmarked: Bool
    let onRestart: () -> Void
    let onQuit: () -> Void
    let onToggleBookmark: () -> Void
    
    @State private var showHintAlert = false
    
    var hasHint: Bool {
        guard let question = question else { return false }
        return !question.year.isEmpty
    }
    
    var hintMessage: String {
        guard let question = question, !question.year.isEmpty else {
            return "No hint available for this question."
        }
        return "Hint: This event occurred in \(question.year)."
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar area
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // Options list
            VStack(spacing: 1) {
                // Hint option (only show if hint is available)
                if hasHint {
                    OptionRow(
                        icon: "lightbulb.fill",
                        title: "Show Hint",
                        iconColor: Color(hex: "#F39C12")
                    ) {
                        showHintAlert = true
                    }
                    
                    Divider()
                        .padding(.leading, 52)
                }
                
                OptionRow(
                    icon: "arrow.clockwise",
                    title: "Restart Quiz",
                    iconColor: Color(hex: "#E67E22")
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRestart()
                    }
                }
                
                Divider()
                    .padding(.leading, 52)
                
                OptionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Quit Quiz",
                    iconColor: Color(hex: "#C0392B")
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onQuit()
                    }
                }
                
                Divider()
                    .padding(.leading, 52)
                
                OptionRow(
                    icon: isBookmarked ? "bookmark.fill" : "bookmark",
                    title: isBookmarked ? "Remove Bookmark" : "Bookmark Question",
                    iconColor: Color(hex: "#2980B9")
                ) {
                    onToggleBookmark()
                    dismiss()
                }
            }
            .background(Color.hbSurface)
            .cornerRadius(HBRadius.md)
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .background(Color.hbBackground)
        .alert("Hint", isPresented: $showHintAlert) {
            Button("Got it", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(hintMessage)
        }
    }
}

// MARK: - Option Row
struct OptionRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed.toggle()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(HBFont.sans(16))
                    .foregroundColor(.hbTextPrimary)
					.frame(maxWidth: .infinity, alignment: .leading)

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: isPressed)
    }
}

// MARK: - Preview
#Preview("Quiz Question View") {
	NavigationStack {
		QuizQuestionView(engine: PreviewQuizEngine.sampleEngine, questionIndex: 0)
	}
}

#Preview("Quiz Question - Multi-Select") {
    QuizQuestionView(engine: PreviewQuizEngine.multiSelectEngine, questionIndex: 1)
}

#Preview("Quiz Question - Time Warning") {
    QuizQuestionView(engine: PreviewQuizEngine.timeWarningEngine, questionIndex: 0)
}

// MARK: - Preview Helper
