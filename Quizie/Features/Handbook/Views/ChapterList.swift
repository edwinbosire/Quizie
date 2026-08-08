import SwiftUI

struct ChapterList: View {
	let chapters: [HandbookChapter]
	let dependencies: HandbookReaderDependencies
	private var progressLibrary: ReadingProgressLibrary { dependencies.progress }
	private var highlightLibrary: HighlightLibrary { dependencies.highlights }
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
				.appFont(.caption2.weight(.semibold))
				.foregroundColor(.hbTextMuted)
				.accessibilityIdentifier("handbook.chapters.heading")
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
					NavigationLink(destination: HighlightsView(dependencies: dependencies)) {
					MyHighlightsCard(highlightCount: allHighlights.count)
				}
				.buttonStyle(.plain)
				.padding(.horizontal, 16)
				.padding(.bottom, 16)
			}

			VStack(spacing: 12) {
				ForEach(chapters) { chapter in
					NavigationLink(destination: ChapterView(chapter: chapter, dependencies: dependencies)) {
						HomeChapterCard(chapter: chapter, progressLibrary: progressLibrary)
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
