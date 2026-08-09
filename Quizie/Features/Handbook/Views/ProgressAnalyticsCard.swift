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
					.appFont(.callout.weight(.semibold))
					.foregroundColor(.hbAccent)

				Text("Your Progress")
					.appFont(.footnote.weight(.semibold))
					.foregroundColor(.hbTextPrimary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			// Overall completion progress bar
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Overall Completion")
						.appFont(.footnote)
						.foregroundColor(.hbTextSecondary)
						.frame(maxWidth: .infinity, alignment: .leading)

					Text("\(Int(progress * 100))%")
						.contentTransition(.numericText(value: progress))
						.appFont(.subheadline.weight(.bold))
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
		.accessibilityIdentifier("handbook.progress")
		.task(id: overallCompletion) {
			animateProgress = false
			progress = 0.0001
			do {
				try await Task.sleep(for: .seconds(1))
			} catch {
				return
			}
			withAnimation(.bouncy) {
				animateProgress = true
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
						.appFont(.body)
						.foregroundColor(.hbAccent)
				}

			// Text
			VStack(alignment: .leading, spacing: 0) {
				Text(label)
					.appFont(.caption2)
					.foregroundColor(.hbTextMuted)
					.frame(maxWidth: .infinity, alignment: .leading)

				Text(value)
					.appFont(.footnote.weight(.semibold))
					.foregroundColor(.hbTextPrimary)
			}

		}
		.frame(maxWidth: .infinity)
		.padding(4)
		.background(Color.hbSurface2.opacity(0.5))
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
	}
}

// MARK: - My Highlights Card
