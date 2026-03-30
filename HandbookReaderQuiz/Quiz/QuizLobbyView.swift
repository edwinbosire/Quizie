import SwiftUI
import SwiftData

struct QuizLobbyView: View {
    @EnvironmentObject var engine: QuizEngine
    @Query(sort: \ExamAttempt.attemptDate, order: .reverse) private var attempts: [ExamAttempt]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    LobbyHero()

                    // Performance Summary (only show if there are attempts)
                    if !attempts.isEmpty {
                        PerformanceSummary(attempts: attempts)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }

                    // Info cards grid (only show for first-time users)
                    if attempts.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            InfoCard(
                                icon: "questionmark.circle.fill",
                                value: "24",
                                label: "Questions",
                                color: Color.hbAccent
                            )
                            InfoCard(
                                icon: "clock.fill",
                                value: "45",
                                label: "Minutes",
                                color: Color(hex: "#145A32")
                            )
                            InfoCard(
                                icon: "checkmark.seal.fill",
                                value: "18/24",
                                label: "Pass Mark",
                                color: Color(hex: "#6E2C00")
                            )
                            InfoCard(
                                icon: "shuffle",
                                value: "∞",
                                label: "Random",
                                color: Color(hex: "#512E5F")
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }

                    // Recent Attempts (show last 3 if available)
                    if !attempts.isEmpty {
                        RecentAttemptsList(attempts: Array(attempts.prefix(3)))
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    // Rules card
                    RulesCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Space for fixed button
                }
            }
            
            // Fixed Start button at bottom
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    engine.startExam()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(attempts.isEmpty ? "Start Practice Exam" : "Try Another Exam")
                            .font(HBFont.sans(17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.hbAccent)
                    .cornerRadius(HBRadius.md)
                    .shadow(color: Color.hbAccent.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(Color.hbBackground)
        }
        .background(Color.hbBackground)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Lobby Hero
struct LobbyHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hbAccent

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -50)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -30, y: 140)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text("PRACTICE TEST")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(2)
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.bottom, 14)

                Text("Life in the UK\nPractice Exam")
                    .font(HBFont.lora(30))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.bottom, 10)

                Text("Test your knowledge with a full-length timed exam, just like the real thing.")
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Info Card (Grid Style)
struct InfoCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Large value
            Text(value)
                .font(HBFont.lora(36))
                .foregroundColor(.hbTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Label
            Text(label)
                .font(HBFont.sans(13))
                .foregroundColor(.hbTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.08),
                    color.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(color.opacity(0.15), lineWidth: 1))
        .shadow(color: color.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Rules Card
struct RulesCard: View {
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
                RuleItem(icon: "4.circle", text: "The exam ends when you answer all 24 questions or time runs out")
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
struct PerformanceSummary: View {
    let attempts: [ExamAttempt]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PROGRESS")
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(.hbTextMuted)
                    
                    Text(encouragementMessage)
                        .font(HBFont.sans(14))
                        .foregroundColor(.hbTextSecondary)
                }
                Spacer()
                
                // Total attempts badge
                VStack(spacing: 2) {
                    Text("\(attempts.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.hbAccent)
                    Text("ATTEMPTS")
                        .font(HBFont.sans(9, weight: .semibold))
                        .kerning(0.8)
                        .foregroundColor(.hbTextMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.hbAccentLight)
                .cornerRadius(HBRadius.sm)
            }
            
            // Stats row
            HStack(spacing: 10) {
                PerformanceStat(
                    icon: "target",
                    value: String(format: "%.0f%%", attempts.averagePercentage),
                    label: "Avg Score",
                    color: Color.hbAccent
                )
                
                PerformanceStat(
                    icon: "trophy.fill",
                    value: "\(attempts.bestScore)/24",
                    label: "Best Score",
                    color: Color(hex: "#145A32")
                )
                
                PerformanceStat(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", attempts.passRate),
                    label: "Pass Rate",
                    color: Color(hex: "#6E2C00")
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.hbAccent.opacity(0.08),
                    Color.hbAccent.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbAccent.opacity(0.15), lineWidth: 1))
    }
    
    var encouragementMessage: String {
        let passRate = attempts.passRate
        if passRate >= 80 {
            return "Excellent progress! You're ready for the real test."
        } else if passRate >= 60 {
            return "Great work! Keep practicing to improve further."
        } else if passRate >= 40 {
            return "Good effort! A few more attempts will help."
        } else {
            return "Keep going! Practice makes perfect."
        }
    }
}

struct PerformanceStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(HBFont.sans(10, weight: .medium))
                .foregroundColor(.hbTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.hbBackground)
        .cornerRadius(HBRadius.sm)
    }
}

// MARK: - Recent Attempts List
struct RecentAttemptsList: View {
    let attempts: [ExamAttempt]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ATTEMPTS")
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1.5)
                .foregroundColor(.hbTextMuted)
                .padding(.horizontal, 2)
            
            VStack(spacing: 8) {
                ForEach(attempts) { attempt in
                    RecentAttemptRow(attempt: attempt)
                }
            }
        }
    }
}

struct RecentAttemptRow: View {
    let attempt: ExamAttempt
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(attempt.passed ? Color(hex: "#D5F5E3") : Color(hex: "#FADBD8"))
                    .frame(width: 42, height: 42)
                
                Image(systemName: attempt.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
            }
            
            // Attempt details
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(attempt.passed ? "Passed" : "Not Passed")
                        .font(HBFont.sans(14, weight: .semibold))
                        .foregroundColor(attempt.passed ? Color(hex: "#145A32") : Color(hex: "#922B21"))
                    
                    Spacer()
                    
                    Text("\(attempt.score)/\(attempt.totalQuestions)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.hbTextPrimary)
                }
                
                HStack(spacing: 8) {
                    Label(attempt.formattedElapsed, systemImage: "clock")
                        .font(HBFont.sans(12))
                        .foregroundColor(.hbTextMuted)
                    
                    Text("•")
                        .foregroundColor(.hbTextMuted)
                    
                    Text(attempt.attemptDate, style: .relative)
                        .font(HBFont.sans(12))
                        .foregroundColor(.hbTextMuted)
                }
            }
        }
        .padding(12)
        .background(Color.hbSurface)
        .cornerRadius(HBRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(attempt.passed ? Color(hex: "#A9DFBF") : Color(hex: "#F1948A"), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview("Quiz Lobby") {
    NavigationStack {
        QuizLobbyView()
            .environmentObject(QuizEngine())
    }
    .modelContainer(for: ExamAttempt.self, inMemory: true)
}

#Preview("Quiz Lobby with History") {
    let container = try! ModelContainer(for: ExamAttempt.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Add sample attempts
    let context = container.mainContext
    let attempts = [
        ExamAttempt(attemptDate: Date().addingTimeInterval(-86400), score: 20, totalQuestions: 24, passed: true, elapsedSeconds: 1800),
        ExamAttempt(attemptDate: Date().addingTimeInterval(-172800), score: 16, totalQuestions: 24, passed: false, elapsedSeconds: 2100),
        ExamAttempt(attemptDate: Date().addingTimeInterval(-259200), score: 22, totalQuestions: 24, passed: true, elapsedSeconds: 1650),
    ]
    attempts.forEach { context.insert($0) }
    
    return NavigationStack {
        QuizLobbyView()
            .environmentObject(QuizEngine())
    }
    .modelContainer(container)
}


