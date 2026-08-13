import SwiftUI

struct SubmitButton: View {
    let engine: QuizEngine
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
                        .appFont(.subheadline.weight(.semibold))
                    Text("Correct! Moving to next...")
                        .appFont(.callout.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .background(Color(hex: "#27AE60")) // Green for correct
                .cornerRadius(HBRadius.md)
                .shadow(color: Color(hex: "#27AE60").opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                if engine.isStreakMode {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.slash.fill")
                            .appFont(.subheadline.weight(.semibold))
                        Text("Streak ended")
                            .appFont(.callout.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Color(hex: "#E74C3C"))
                    .cornerRadius(HBRadius.md)
                    .shadow(color: Color(hex: "#E74C3C").opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    // Incorrect answer - manual advance required
                    Button {
                        engine.manualAdvance()
                    } label: {
                        HStack(spacing: 8) {
                            Text(isLast ? "Submit Exam" : "Next Question")
                                .appFont(.callout.weight(.semibold))
                            Image(systemName: isLast ? "checkmark.circle.fill" : "arrow.right")
                                .appFont(.subheadline.weight(.semibold))
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
            }
        } else if shouldShowManualSubmit {
            // Manual submit button (only for multi-select with wrong count)
            Button {
                engine.submitAndAdvance()
            } label: {
                HStack(spacing: 8) {
                    Text("Submit Answer")
                        .appFont(.callout.weight(.semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .appFont(.subheadline.weight(.semibold))
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
    let source: QuizQuestionSource?
    let isBookmarked: Bool
    let onShowHint: (QuizQuestionSource) -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void
    let onToggleBookmark: () -> Void
    
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
                if let source, source.hasHint {
                    OptionRow(
                        icon: "lightbulb.fill",
                        title: "Show Hint",
                        iconColor: Color(hex: "#F39C12")
                    ) {
                        onShowHint(source)
                        dismiss()
                    }
                    .accessibilityIdentifier("quiz.options.hint")
                    
                    Divider()
                        .padding(.leading, 52)
                }
                
                OptionRow(
                    icon: "arrow.clockwise",
                    title: "Restart Quiz",
                    iconColor: Color(hex: "#E67E22")
                ) {
                    onRestart()
                    dismiss()
                }
                
                Divider()
                    .padding(.leading, 52)
                
                OptionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Quit Quiz",
                    iconColor: Color(hex: "#C0392B")
                ) {
                    onQuit()
                    dismiss()
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
                    .appFont(.body.weight(.medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .appFont(.callout)
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
