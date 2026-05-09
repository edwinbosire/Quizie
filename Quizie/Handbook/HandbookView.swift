import SwiftUI
import SwiftData

struct HandbookView: View {
	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				// Hero Section (matches .hero in CSS)
				HeroHeader()

				// Chapter List
				ChapterList()
					.staggered(0.2)
			}
		}
		.background(Color.hbBackground)
		.ignoresSafeArea(edges: .top)
		.navigationBarHidden(true)
	}
}

// MARK: - Hero Header
struct HeroHeader: View {
	@State private var animateBubbles: Bool = false
	var body: some View {
		ZStack(alignment: .topLeading) {
			// Background
			Color.hbAccent

			// Decorative circles (matching CSS ::before / ::after)
			Circle()
				.fill(Color.white.opacity(0.06))
				.frame(width: 220, height: 220)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
				.offset(x: 110, y: -60)
				.scaleEffect(animateBubbles ? 1.0 : 0.05)

			Circle()
				.fill(Color.white.opacity(0.04))
				.frame(width: 160, height: 160)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
				.offset(x: -20, y: 200)
				.scaleEffect(animateBubbles ? 1.0 : 0.05)

			// Content
			VStack(alignment: .leading, spacing: 10) {
				Text("OFFICIAL STUDY GUIDE")
					.font(HBFont.sans(11, weight: .semibold))
					.kerning(2)
					.foregroundColor(Color.hbTextMuted)
					.staggered(0.1)

				Text("Life in the\nUnited Kingdom")
					.font(HBFont.lora(32))
					.foregroundColor(.white)
					.staggered(0.2)

				Text("Your complete guide to British values, history, culture and citizenship.")
					.font(HBFont.sans(15))
					.foregroundColor(Color.white.opacity(0.7))
					.padding(.bottom, 20)
					.staggered(0.4)

				// Union Jack stripe accent
				FlagStripes()
					.mask {
						let diameter = animateBubbles ? 750.0 : 0.0
						Circle()
							.frame(width: diameter, height: diameter)
							.animation(.easeOut(duration: 1), value: animateBubbles)
					}
			}
			.padding(.horizontal)
			.padding(.top, 56)
			.padding(.bottom, 36)
		}
		.frame(maxWidth: .infinity)
		.onAppear {
			withAnimation(.bouncy(duration: 1).delay(0.6)) {
				animateBubbles = true
			}
		}
	}

}

// MARK: - Flag Stripe Decoration
struct FlagStripes: View {
	var body: some View {
		HStack(spacing: 0) {
			Rectangle().fill(Color(hex: "#012169")).frame(height: 4)
			Rectangle().fill(Color.white.opacity(0.6)).frame(height: 4)
			Rectangle().fill(Color(hex: "#CF142B")).frame(height: 4)
			Rectangle().fill(Color.white.opacity(0.6)).frame(height: 4)
			Rectangle().fill(Color(hex: "#012169")).frame(height: 4)
		}
		.clipShape(Capsule())
		.frame(height: 4)
	}
}

// MARK: - Chapter List
struct ChapterList: View {
	@Query private var allProgress: [ReadingProgress]
	@Query private var allHighlights: [Highlight]
	@Environment(\.modelContext) private var modelContext

	private var overallCompletion: Double {
		ReadingProgress.overallCompletionPercentage(totalChapters: HandbookData.chapters.count, in: modelContext)
	}

	private var totalReadingTime: TimeInterval {
		ReadingProgress.totalReadingTime(in: modelContext)
	}

	private var mostRecentProgress: ReadingProgress? {
		ReadingProgress.mostRecentlyRead(in: modelContext)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("CHAPTERS")
				.font(HBFont.sans(11, weight: .semibold))
				.kerning(1.5)
				.foregroundColor(.hbTextMuted)
				.padding(.horizontal, 24)
				.padding(.top, 24)
				.padding(.bottom, 12)

			// Progress Analytics Card
			if !allProgress.isEmpty {
				ProgressAnalyticsCard(
					overallCompletion: overallCompletion,
					totalReadingTime: totalReadingTime,
					lastReadDate: mostRecentProgress?.lastReadDate
				)
				.padding(.horizontal, 16)
				.padding(.bottom, 16)
			}

			// My Highlights card
			if !allHighlights.isEmpty {
				NavigationLink(destination: HighlightsView()) {
					MyHighlightsCard(highlightCount: allHighlights.count)
				}
				.buttonStyle(.plain)
				.padding(.horizontal, 16)
				.padding(.bottom, 16)
			}

			VStack(spacing: 12) {
				ForEach(HandbookData.chapters) { chapter in
					NavigationLink(destination: ChapterView(chapter: chapter)) {
						HomeChapterCard(chapter: chapter)
					}
					.buttonStyle(.plain)
					.staggered(0.4 + (0.1 * Double(chapter.id)))
				}
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 32)
		}
	}
}

// MARK: - Progress Analytics Card
struct ProgressAnalyticsCard: View {
	let overallCompletion: Double
	let totalReadingTime: TimeInterval
	let lastReadDate: Date?

	// animation
	@State private var animateProgress: Bool = false
	@State private var progress: Double = 0.0001
	private var formattedReadingTime: String {
		let minutes = Int(totalReadingTime / 60)
		if minutes < 60 {
			return "\(minutes) min"
		} else {
			let hours = minutes / 60
			let remainingMinutes = minutes % 60
			if remainingMinutes > 0 {
				return "\(hours)h \(remainingMinutes)m"
			} else {
				return "\(hours) hour\(hours == 1 ? "" : "s")"
			}
		}
	}

	private var formattedLastRead: String {
		guard let date = lastReadDate else { return "Not started" }

		let calendar = Calendar.current
		let now = Date()

		if calendar.isDateInToday(date) {
			let formatter = DateFormatter()
			formatter.timeStyle = .short
			return "Today at \(formatter.string(from: date))"
		} else if calendar.isDateInYesterday(date) {
			return "Yesterday"
		} else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
			let formatter = DateFormatter()
			formatter.dateFormat = "EEEE" // Day name
			return formatter.string(from: date)
		} else {
			let formatter = DateFormatter()
			formatter.dateStyle = .short
			return formatter.string(from: date)
		}
	}

	var body: some View {
		VStack(spacing: 16) {
			// Header
			HStack {
				Image(systemName: "chart.line.uptrend.xyaxis")
					.font(.system(size: 16, weight: .semibold))
					.foregroundColor(.hbAccent)

				Text("Your Progress")
					.font(HBFont.sans(14, weight: .semibold))
					.foregroundColor(.hbTextPrimary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			// Overall completion progress bar
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Overall Completion")
						.font(HBFont.sans(13))
						.foregroundColor(.hbTextSecondary)
						.frame(maxWidth: .infinity, alignment: .leading)

					Text("\(Int(progress * 100))%")
						.contentTransition(.numericText(value: progress))
						.font(HBFont.sans(15, weight: .bold))
						.foregroundColor(.hbAccent)
						.animation(.easeOut.delay(0.2), value: progress)
				}

				GeometryReader { geometry in
					ZStack(alignment: .leading) {
						// Background track
						Capsule()
							.fill(Color.hbSurface2)
							.frame(height: 8)

						// Progress fill
						Capsule()
							.fill(
								LinearGradient(
									colors: [Color.hbAccent, Color.hbAccent.opacity(0.7)],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.frame(width: animateProgress ? geometry.size.width * overallCompletion : 0.0, height: 8)
					}
				}
				.frame(height: 8)
			}

			// Stats row
			HStack(spacing: 12) {
				// Reading time stat
				StatBox(
					icon: "clock.fill",
					label: "Reading Time",
					value: formattedReadingTime
				)

				// Last read stat
				StatBox(
					icon: "book.fill",
					label: "Last Read",
					value: formattedLastRead
				)
			}
		}
		.padding()
		.background(Color.hbSurface)
		.overlay(
			RoundedRectangle(cornerRadius: HBRadius.md)
				.stroke(Color.hbAccent.opacity(0.2), lineWidth: 1)
		)
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
		.onAppear {
			withAnimation(.bouncy.delay(1)) {
				animateProgress.toggle()
			}
			Task {
				try? await Task.sleep(nanoseconds: 1_000_000_000)
				progress = overallCompletion
			}
		}
	}
}

// MARK: - Stat Box
struct StatBox: View {
	let icon: String
	let label: String
	let value: String

	var body: some View {
		HStack(spacing: 10) {
			// Icon
			Circle()
				.fill(Color.hbAccent.opacity(0.12))
				.frame(width: 18, height: 18)
				.overlay {
					Image(systemName: icon)
						.font(.body)
						.foregroundColor(.hbAccent)
				}

			// Text
			VStack(alignment: .leading, spacing: 0) {
				Text(label)
					.font(HBFont.sans(11))
					.foregroundColor(.hbTextMuted)
					.frame(maxWidth: .infinity, alignment: .leading)

				Text(value)
					.font(HBFont.sans(13, weight: .semibold))
					.foregroundColor(.hbTextPrimary)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}

		}
		.frame(maxWidth: .infinity)
		.padding(4)
		.background(Color.hbSurface2.opacity(0.5))
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
	}
}

// MARK: - My Highlights Card
struct MyHighlightsCard: View {
	let highlightCount: Int

	var body: some View {
		HStack(spacing: 14) {
			ZStack {
				Circle()
					.fill(Color.hbAccent.opacity(0.12))
					.frame(width: 40, height: 40)

				Image(systemName: "highlighter")
					.font(.system(size: 17, weight: .semibold))
					.foregroundColor(.hbAccent)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text("My Highlights")
					.font(HBFont.sans(15, weight: .semibold))
					.foregroundColor(.hbTextPrimary)

				Text("\(highlightCount) highlight\(highlightCount == 1 ? "" : "s")")
					.font(HBFont.sans(12))
					.foregroundColor(.hbTextMuted)
			}

			Spacer()

			Image(systemName: "chevron.right")
				.font(.system(size: 13, weight: .medium))
				.foregroundColor(.hbTextMuted.opacity(0.5))
		}
		.padding(16)
		.background(Color.hbSurface)
		.overlay(
			RoundedRectangle(cornerRadius: HBRadius.md)
				.stroke(Color.hbAccent.opacity(0.2), lineWidth: 1)
		)
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
	}
}

#Preview {
	HandbookView()
		.modelContainer(for: [ReadingProgress.self, ExamAttempt.self, Highlight.self])
}
