import SwiftUI

struct QuizQuestionView: View {
    @EnvironmentObject var engine: QuizEngine
    let questionIndex: Int

    @State private var animateSubmitButton = false
    @State private var showOptionsSheet = false
    @State private var showRestartAlert = false
    @State private var showQuitAlert = false
    @AppStorage("bookmarkedQuestions") private var bookmarkedQuestionsData = Data()
    
    private var bookmarkedQuestions: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: bookmarkedQuestionsData)) ?? []
        }
    }
    
    private func updateBookmarks(_ bookmarks: Set<String>) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            bookmarkedQuestionsData = data
        }
    }

    var question: QuizQuestion? { engine.session?.questions[safe: questionIndex] }
    
    var isBookmarked: Bool {
        guard let q = question else { return false }
        return bookmarkedQuestions.contains(q.id)
    }

    var body: some View {
		VStack(spacing: 0) {
			// Top bar: timer + progress + options
			QuizTopBar(onOptionsPressed: { showOptionsSheet = true })

			// Progress track
			QuizProgressBar(current: questionIndex + 1, total: engine.totalQuestions)

			if let question {
				QuestionView(question: question, questionIndex: questionIndex)
			}
		}
        .sheet(isPresented: $showOptionsSheet) {
            QuizOptionsSheet(
                question: question,
                isBookmarked: isBookmarked,
                onRestart: { showRestartAlert = true },
                onQuit: { showQuitAlert = true },
                onToggleBookmark: toggleBookmark
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .alert("Restart Quiz?", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                engine.startExam()
            }
        } message: {
            Text("Your current progress will be lost permanently. This will reset all answers and restart the timer.")
        }
        .alert("Quit Quiz?", isPresented: $showQuitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                engine.returnToLobby()
            }
        } message: {
            Text("Your current progress will be lost permanently. You can start a new quiz from the lobby.")
        }
        .onAppear {
            // Delay submit button animation by 3 seconds
            withAnimation(.bouncy.delay(1.05)) {
                animateSubmitButton = true
            }
        }
        .onChange(of: questionIndex) { _, _ in
            animateSubmitButton = false

            // Delay submit button animation by 3 seconds
            withAnimation(.bouncy.delay(1.05)) {
                animateSubmitButton = true
            }
        }
    }
    
    private func toggleBookmark() {
        guard let q = question else { return }
        var bookmarks = bookmarkedQuestions
        if bookmarks.contains(q.id) {
            bookmarks.remove(q.id)
        } else {
            bookmarks.insert(q.id)
        }
        updateBookmarks(bookmarks)
    }
}

private struct QuestionView: View {
	let question: QuizQuestion
	let questionIndex: Int
	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				// Question card
				QuestionCard(question: question, questionIndex: questionIndex)
					.frame(minHeight: 200)
					.padding(.horizontal, 16)
					.padding(.vertical, 20)
					.staggered(0.1)

				// Choice options
				ChoicesView(question: question)
					.padding(.horizontal, 16)
					.padding(.top, 16)
					.staggered(0.2)

				// Submit button
				SubmitButton(question: question)
					.padding(.horizontal, 16)
					.padding(.top, 20)
					.padding(.bottom, 40)
					.staggered(0.4)
			}
		}
		.background(Color.hbBackground)
	}
}

// MARK: - Top Bar (timer + question count + options)
struct QuizTopBar: View {
    @EnvironmentObject var engine: QuizEngine
    let onOptionsPressed: () -> Void
    
    @State private var optionsButtonPressed = false

	var body: some View {
        VStack(spacing: 0) {
            HStack {

                // Timer
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(engine.isTimeWarning ? Color(hex: "#C0392B") : .hbTextMuted)
                    Text(engine.formattedTime)
                        .font(HBFont.sans(14, weight: .semibold))
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
                        .font(.system(size: 22))
                        .foregroundColor(.hbTextSecondary)
                }
                .padding(.leading, 8)
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
							.font(.system(size: 12))
							.foregroundColor(Color(hex: "#512E5F"))
						Text("SELECT \(question.correctIndices.count) ANSWERS")
							.font(HBFont.sans(11, weight: .semibold))
							.kerning(1.2)
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
						.font(HBFont.sans(11, weight: .semibold))
						.kerning(1.2)
						.foregroundColor(.hbTextMuted)
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(Color.hbBackground, in: Capsule())
				}

			}

            Text(question.question)
                .font(HBFont.lora(20))
                .foregroundColor(.hbTextPrimary)
                .lineSpacing(6)

            // Year hint
//            if !question.year.isEmpty {
//                HStack(spacing: 5) {
//                    Image(systemName: "calendar")
//                        .font(.system(size: 11))
//                    Text("Hint: \(question.year)")
//                        .font(HBFont.sans(13))
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
    @EnvironmentObject var engine: QuizEngine
    let question: QuizQuestion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                ChoiceButton(
                    label: choiceLabel(idx),
                    text: choice,
                    isSelected: engine.selectedIndices.contains(idx),
                    isMultiSelect: question.isMultiSelect,
                    isCorrect: engine.hasSubmittedAnswer ? question.correctIndices.contains(idx) : nil,
                    hasSubmitted: engine.hasSubmittedAnswer
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        engine.toggleChoice(idx, isMultiSelect: question.isMultiSelect)
                    }
                }
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
    
    @State private var shakeOffset: CGFloat = 0
    
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
                            .font(.system(size: 12, weight: .bold))
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(label)
                            .font(HBFont.sans(13, weight: .semibold))
                            .foregroundColor(feedbackColor != nil ? .white : (isSelected ? .white : .hbTextMuted))
                    }
                }
            }

            Text(text)
                .font(HBFont.sans(15.5))
                .foregroundColor(feedbackColor ?? (isSelected ? Color.hbTextPrimary : Color.hbTextSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show X icon for wrong selections
            if shouldShowAsWrong {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
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
        .offset(x: shakeOffset)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.3), value: hasSubmitted)
        .sensoryFeedback(.success, trigger: hasSubmitted && isCorrect == true && isSelected)
        .sensoryFeedback(.error, trigger: shouldShowAsWrong)
        .onChange(of: shouldShowAsWrong) { oldValue, newValue in
            if newValue && !oldValue {
                // Trigger shake animation when answer becomes wrong
                triggerShake()
            }
        }
    }
    
    private func triggerShake() {
        let animation = Animation.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0)
        
        withAnimation(animation) {
            shakeOffset = -10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animation) {
                shakeOffset = 10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(animation) {
                shakeOffset = -8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                shakeOffset = 8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(animation) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Submit Button
struct SubmitButton: View {
    @EnvironmentObject var engine: QuizEngine
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
		QuizQuestionView(questionIndex: 0)
			.environmentObject(PreviewQuizEngine.sampleEngine)
	}
}

#Preview("Quiz Question - Multi-Select") {
    QuizQuestionView(questionIndex: 1)
        .environmentObject(PreviewQuizEngine.multiSelectEngine)
}

#Preview("Quiz Question - Time Warning") {
    QuizQuestionView(questionIndex: 0)
        .environmentObject(PreviewQuizEngine.timeWarningEngine)
}

// MARK: - Preview Helper
@MainActor
class PreviewQuizEngine {
    static var sampleEngine: QuizEngine {
        let engine = QuizEngine()
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What year was the Declaration of Independence signed?",
                choices: [
                    "1774",
                    "1775",
                    "1776",
                    "1777"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1776",
                category: 1,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q2",
                question: "Which of the following are branches of the U.S. government?",
                choices: [
                    "Legislative",
                    "Executive",
                    "Judicial",
                    "Administrative"
                ],
                correctIndices: [0, 1, 2],
                isMultiSelect: true,
                year: "1787",
                category: 2,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q3",
                question: "Who was the first President of the United States?",
                choices: [
                    "John Adams",
                    "Thomas Jefferson",
                    "George Washington",
                    "Benjamin Franklin"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1789",
                category: 1,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.session = ExamSession(questions: mockQuestions)
        engine.phase = .question(index: 0)
        engine.timeRemaining = 2700 // 45 minutes
        return engine
    }
    
    static var multiSelectEngine: QuizEngine {
        let engine = QuizEngine()
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What year was the Declaration of Independence signed?",
                choices: [
                    "1774",
                    "1775",
                    "1776",
                    "1777"
                ],
                correctIndices: [2],
                isMultiSelect: false,
                year: "1776",
                category: 1,
                explanationLink: "https://example.com"
            ),
            QuizQuestion(
                id: "q2",
                question: "Which of the following are branches of the U.S. government? Select all that apply.",
                choices: [
                    "Legislative",
                    "Executive",
                    "Judicial",
                    "Administrative",
                    "Monetary"
                ],
                correctIndices: [0, 1, 2],
                isMultiSelect: true,
                year: "1787",
                category: 2,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.session = ExamSession(questions: mockQuestions)
        engine.phase = .question(index: 1)
        engine.selectedIndices = [0, 1] // Pre-select some choices
        engine.timeRemaining = 2400
        return engine
    }
    
    static var timeWarningEngine: QuizEngine {
        let engine = QuizEngine()
        let mockQuestions = [
            QuizQuestion(
                id: "q1",
                question: "What is the supreme law of the land?",
                choices: [
                    "The Declaration of Independence",
                    "The Constitution",
                    "The Bill of Rights",
                    "The Articles of Confederation"
                ],
                correctIndices: [1],
                isMultiSelect: false,
                year: "1787",
                category: 1,
                explanationLink: "https://example.com"
            )
        ]
        
        engine.session = ExamSession(questions: mockQuestions)
        engine.phase = .question(index: 0)
        engine.timeRemaining = 240 // 4 minutes - triggers warning
        return engine
    }
}

