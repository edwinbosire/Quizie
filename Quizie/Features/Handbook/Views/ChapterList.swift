import SwiftUI

struct ChapterList: View {
		let chapters: [HandbookChapter]
	@Environment(ReadingProgressLibrary.self) private var progressLibrary
	@Environment(HighlightLibrary.self) private var highlightLibrary
	private var allProgress: [ReadingProgressSnapshot] { progressLibrary.records }
	private var allHighlights: [HighlightSnapshot] { highlightLibrary.highlights }

	private var overallCompletion: Double {
			guard !chapters.isEmpty else { return 0 }
			return allProgress.reduce(0) { $0 + $1.progress } / Double(chapters.count)
	}

	private var totalReadingTime: TimeInterval {
		allProgress.reduce(0) { $0 + $1.totalReadingTime }
	}

	private var mostRecentProgress: ReadingProgressSnapshot? {
		allProgress.max { $0.lastReadDate < $1.lastReadDate }
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
				ForEach(chapters) { chapter in
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
