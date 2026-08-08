import SwiftUI

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
                        .font(.largeTitle.weight(.medium))
                        .foregroundColor(.white)

                    Text(passed ? "PASSED" : "NOT PASSED")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(passed ? Color(hex: "#1B4F72") : Color(hex: "#922B21"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 18)

                Text(headline)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text(subline)
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 24)

                // Big score display (animated)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
						Text(animatedScore, format: .number.precision(.integerLength(2...)))
							.font(.system(.largeTitle, design: .rounded, weight: .bold))
							.foregroundColor(.white)
							.contentTransition(.numericText())
							.scaleEffect(scoreScale)
							.animation(.easeOut(duration: 0.5), value: animatedScore)

						Text("/")
							.font(.system(.title, design: .rounded, weight: .medium))
							.foregroundColor(Color.white.opacity(0.4))
							.id("division_sign") // Stable identity prevents re-layout

						Text("\(session.questions.count)")
							.font(.system(.title, design: .rounded, weight: .medium))
							.foregroundColor(Color.white.opacity(0.6))
							.id("denominator") // Stable identity prevents re-layout
                }
                .padding(.bottom, 8)

                // Circular score arc
                ScoreArcView(
                    score: session.score,
                    total: session.questions.count,
                    passAt: session.configuration.passMarkCount,
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
                    .font(.footnote)
                    .foregroundColor(.hbTextMuted)
                Spacer()
                Text(session.passed ? "✓ Passed" : "✗ Not passed")
                    .font(.footnote.weight(.semibold))
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
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
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
