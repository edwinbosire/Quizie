import SwiftUI

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
