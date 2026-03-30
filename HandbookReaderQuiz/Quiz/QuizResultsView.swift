import SwiftUI

struct QuizResultsView: View {
    @EnvironmentObject var engine: QuizEngine
    @State private var showReview = false
    @State private var showConfetti = false

    var session: ExamSession? { engine.session }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let session {
                        // Hero result banner
                        ResultHero(session: session, showConfetti: $showConfetti)

                        // Score breakdown cards
                        ScoreBreakdown(session: session)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                        // Action buttons
                        ActionButtons(showReview: $showReview)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)

                        // Answer review list
                        if showReview {
                            AnswerReviewList(session: session)
                                .padding(.top, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.bottom, 48)
            }
            .background(Color.hbBackground)
            .ignoresSafeArea(edges: .top)
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Result Hero
struct ResultHero: View {
    let session: ExamSession
    @Binding var showConfetti: Bool

    var passed: Bool { session.passed }
    
    @State private var animatedScore: Int = 00
    @State private var scoreScale: CGFloat = 1.0

    // Pass: rich navy; Fail: deep warm red
    var heroColor: Color {
        passed ? Color(hex: "#1B4F72") : Color(hex: "#922B21")
    }
    var accentBadgeColor: Color {
        passed ? Color(hex: "#D4E6F1") : Color(hex: "#FADBD8")
    }
    var icon: String {
        passed ? "checkmark.seal.fill" : "xmark.seal.fill"
    }
    var headline: String {
        passed ? "Congratulations!" : "Keep Practising"
    }
    var subline: String {
        passed
        ? "You've passed the practice exam. You're well prepared for the real test."
        : "You didn't reach the pass mark this time. Review your answers and try again."
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroColor

            // Decorative circles - positioned relative to container edges
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 120, y: -60)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 150, height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -30, y: 200)

            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 250, height: 250)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 80, y: 80)

            VStack(alignment: .leading, spacing: 0) {
                // Icon + badge
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)

                    Text(passed ? "PASSED" : "NOT PASSED")
                        .font(HBFont.sans(12, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(passed ? Color(hex: "#1B4F72") : Color(hex: "#922B21"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 18)

                Text(headline)
                    .font(HBFont.lora(30))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text(subline)
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.75))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 24)

                // Big score display (animated)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
						Text(animatedScore, format: .number.precision(.integerLength(2...)))
							.font(.system(size: 64, weight: .bold, design: .rounded))
							.foregroundColor(.white)
							.contentTransition(.numericText())
							.scaleEffect(scoreScale)
							.animation(.easeOut(duration: 0.5), value: animatedScore)

						Text("/")
							.font(.system(size: 28, weight: .medium, design: .rounded))
							.foregroundColor(Color.white.opacity(0.4))
							.id("division_sign") // Stable identity prevents re-layout

						Text("\(session.questions.count)")
							.font(.system(size: 28, weight: .medium, design: .rounded))
							.foregroundColor(Color.white.opacity(0.6))
							.id("denominator") // Stable identity prevents re-layout
                }
                .padding(.bottom, 8)

                // Circular score arc
                ScoreArcView(
                    score: session.score,
                    total: session.questions.count,
                    passAt: ExamSession.passMarkCount,
                    passed: passed
                )
                .frame(height: 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
		.task {
			try? await Task.sleep(nanoseconds: 300_000_000)
			// Animate score counting up slowly for dramatic effect (2.5 seconds)
			animatedScore = session.score

			// Bouncy scale animation when count completes
			try? await Task.sleep(nanoseconds: 300_000_000)
			withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
				scoreScale = 1.15
			}
			withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
				scoreScale = 1.0
			}

			// Trigger confetti if passed
			if passed {
				showConfetti = true
			}
		}
    }
}

// MARK: - Score Arc (horizontal bar showing pass threshold)
struct ScoreArcView: View {
    let score: Int
    let total: Int
    let passAt: Int
    let passed: Bool
    
    @State private var animatedScore: Double = 0

    var scoreFrac: Double { Double(score) / Double(total) }
    var passFrac: Double  { Double(passAt) / Double(total) }
    var animatedFrac: Double { animatedScore / Double(total) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Track
                Capsule().fill(Color.white.opacity(0.2)).frame(height: 8)

				// Pass threshold marker
				Rectangle()
					.fill(Color.white.opacity(0.4))
					.frame(width: 2, height: 16)
					.offset(x: w * passFrac - 1, y: 0)

                // Fill (animated)
                Capsule()
                    .fill(passed ? Color.white : Color(hex: "#F1948A"))
                    .frame(width: w * animatedFrac, height: 8)
            }
        }
        .frame(height: 8)
        .task {
            withAnimation(.bouncy(duration: 1.5)) {
                animatedScore = Double(score)
            }
        }
    }
}

// MARK: - Score Breakdown Cards
struct ScoreBreakdown: View {
    let session: ExamSession

    var wrongCount: Int { session.questions.count - session.score }
    var scorePercent: Int { Int(session.percentage.rounded()) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(value: "\(session.score)", label: "Correct", color: Color(hex: "#145A32"), bg: Color(hex: "#D5F5E3"))
                StatCard(value: "\(wrongCount)", label: "Incorrect", color: Color(hex: "#922B21"), bg: Color(hex: "#FADBD8"))
            }
            HStack(spacing: 12) {
                StatCard(value: "\(scorePercent)%", label: "Score", color: Color.hbAccent, bg: Color.hbAccentLight)
                StatCard(value: session.formattedElapsed, label: "Time taken", color: Color(hex: "#512E5F"), bg: Color(hex: "#EAD9F5"))
            }

            // Pass mark indicator
            HStack {
                Text("Pass mark: 18/24")
                    .font(HBFont.sans(13))
                    .foregroundColor(.hbTextMuted)
                Spacer()
                Text(session.passed ? "✓ Passed" : "✗ Not passed")
                    .font(HBFont.sans(13, weight: .semibold))
                    .foregroundColor(session.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
            }
            .padding(.horizontal, 4)
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    let bg: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1)
                .foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(bg)
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Action Buttons
struct ActionButtons: View {
    @EnvironmentObject var engine: QuizEngine
    @Binding var showReview: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Review answers
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showReview.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showReview ? "chevron.up" : "list.bullet.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text(showReview ? "Hide Answer Review" : "Review Answers")
                        .font(HBFont.sans(16, weight: .semibold))
                }
                .foregroundColor(Color.hbAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.hbAccentLight)
                .cornerRadius(HBRadius.md)
                .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbAccent.opacity(0.4), lineWidth: 1))
            }

            // New exam
            Button {
                engine.startExam()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Try Another Exam")
                        .font(HBFont.sans(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.hbAccent)
                .cornerRadius(HBRadius.md)
                .shadow(color: Color.hbAccent.opacity(0.3), radius: 6, x: 0, y: 3)
            }

            // Return home
            Button {
                engine.returnToLobby()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .medium))
                    Text("Return to Home")
                        .font(HBFont.sans(15))
                }
                .foregroundColor(.hbTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Answer Review List
struct AnswerReviewList: View {
    let session: ExamSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("ANSWER REVIEW")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundColor(.hbTextMuted)
                Spacer()
                let correct = session.score
                let wrong = session.questions.count - correct
                HStack(spacing: 12) {
                    Label("\(correct)", systemImage: "checkmark.circle.fill")
                        .font(HBFont.sans(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#145A32"))
                    Label("\(wrong)", systemImage: "xmark.circle.fill")
                        .font(HBFont.sans(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#922B21"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(Array(session.questions.enumerated()), id: \.offset) { idx, question in
                    let answer = session.answers[question.id]
                    AnswerReviewRow(
                        index: idx + 1,
                        question: question,
                        answer: answer
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Answer Review Row
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
                .stroke(isCorrect ? rowBorder : rowBorder, lineWidth: 1)
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
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, screenHeight: geometry.size.height)
                }
            }
            .onAppear {
                generateConfetti(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            }
        }
    }
    
    private func generateConfetti(screenWidth: CGFloat, screenHeight: CGFloat) {
        let confettiCount = 100
        
        for _ in 0..<confettiCount {
            let delay = Double.random(in: 0...1.5)
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...screenWidth),
                y: -20,
                color: randomConfettiColor(),
                size: CGFloat.random(in: 8...16),
                rotation: Double.random(in: 0...360),
                delay: delay,
                duration: Double.random(in: 2.5...4.5),
                swingAmount: CGFloat.random(in: 30...80),
                swingSpeed: Double.random(in: 0.8...1.5)
            )
            confettiPieces.append(piece)
        }
    }
    
    private func randomConfettiColor() -> Color {
        let colors: [Color] = [
            Color(hex: "#1B4F72"), // Blue
            Color(hex: "#145A32"), // Green
            Color(hex: "#512E5F"), // Purple
            Color(hex: "#E67E22"), // Orange
            Color(hex: "#C0392B"), // Red
            Color(hex: "#F39C12"), // Yellow
            Color(hex: "#16A085"), // Teal
            Color(hex: "#E91E63"), // Pink
        ]
        return colors.randomElement() ?? .blue
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let delay: Double
    let duration: Double
    let swingAmount: CGFloat
    let swingSpeed: Double
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenHeight: CGFloat
    
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotationAmount: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 1.5)
            .rotationEffect(.degrees(piece.rotation + rotationAmount))
            .opacity(opacity)
            .position(x: piece.x + xOffset, y: piece.y + yOffset)
            .onAppear {
                // Y-axis fall
                withAnimation(.easeIn(duration: piece.duration).delay(piece.delay)) {
                    yOffset = screenHeight + 50
                }
                
                // X-axis swing
                withAnimation(.easeInOut(duration: piece.swingSpeed).repeatForever(autoreverses: true).delay(piece.delay)) {
                    xOffset = piece.swingAmount
                }
                
                // Rotation
                withAnimation(.linear(duration: piece.duration * 0.7).repeatForever(autoreverses: false).delay(piece.delay)) {
                    rotationAmount = 360
                }
                
                // Fade out near bottom
                DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay + piece.duration * 0.7) {
                    withAnimation(.easeOut(duration: piece.duration * 0.3)) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Previews
#Preview("Quiz Results - Passed") {
    NavigationStack {
        QuizResultsView()
            .environmentObject(PreviewResultsEngine.passedEngine)
    }
}

#Preview("Quiz Results - Failed") {
    NavigationStack {
        QuizResultsView()
            .environmentObject(PreviewResultsEngine.failedEngine)
    }
}

// MARK: - Preview Helper
@MainActor
class PreviewResultsEngine {
    static var passedEngine: QuizEngine {
        let engine = QuizEngine()
        let mockQuestions = createMockQuestions()
        
        var session = ExamSession(questions: mockQuestions)
        session.startedAt = Date().addingTimeInterval(-2100) // 35 minutes ago
        session.finishedAt = Date()
        
        // Simulate 20 correct answers (passed)
        for question in mockQuestions.prefix(20) {
            session.submit(answer: question.correctIndices, for: question)
        }
        // 4 wrong answers
        for question in mockQuestions.suffix(4) {
            let wrongAnswer = Set([1]) // Wrong answer (correct is 0)
            session.submit(answer: wrongAnswer, for: question)
        }
        
        engine.session = session
        engine.phase = .results
        return engine
    }
    
    static var failedEngine: QuizEngine {
        let engine = QuizEngine()
        let mockQuestions = createMockQuestions()
        
        var session = ExamSession(questions: mockQuestions)
        session.startedAt = Date().addingTimeInterval(-2400) // 40 minutes ago
        session.finishedAt = Date()
        
        // Simulate 15 correct answers (failed - need 18)
        for question in mockQuestions.prefix(15) {
            session.submit(answer: question.correctIndices, for: question)
        }
        // 9 wrong answers
        for question in mockQuestions.suffix(9) {
            let wrongAnswer = Set([1]) // Wrong answer (correct is 0)
            session.submit(answer: wrongAnswer, for: question)
        }
        
        engine.session = session
        engine.phase = .results
        return engine
    }
    
    private static func createMockQuestions() -> [QuizQuestion] {
        return (1...24).map { i in
            QuizQuestion(
                id: "q\(i)",
                question: "Question \(i): What is the capital of England?",
                choices: [
                    "London",
                    "Manchester",
                    "Birmingham",
                    "Liverpool"
                ],
                correctIndices: [0],
                isMultiSelect: false,
                year: "1066",
                category: 1,
                explanationLink: "https://example.com"
            )
        }
    }
}

