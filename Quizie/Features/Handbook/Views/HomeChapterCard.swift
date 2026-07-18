import SwiftUI

struct HomeChapterCard: View {
    let chapter: HandbookChapter
    @Environment(ReadingProgressLibrary.self) private var progressLibrary

    init(chapter: HandbookChapter) { self.chapter = chapter }

    private var theme: ChapterTheme {
        ChapterTheme.forChapter(chapter.id)
    }

    private var cardAccentColors: [Color] = [
        Color(hex: "#1B4F72"), Color(hex: "#1A5276"),
        Color(hex: "#6E2C00"), Color(hex: "#145A32"), Color(hex: "#512E5F")
    ]
    
    private var readingProgress: ReadingProgressSnapshot? { progressLibrary.progress(for: chapter.contentID) }

	var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(chapter.number.uppercased())
                        .font(HBFont.sans(11, weight: .semibold))
                        .kerning(1)
                        .foregroundColor(.white)
						.frame(maxWidth: .infinity, alignment: .leading)

                    // Progress indicator
                    if let progress = readingProgress {
						// Reading time if available
						if progress.totalReadingTime > 60 {
							HStack(spacing: 4) {
								Image(systemName: "clock.fill")
									.font(.system(size: 10))
								Text(progress.formattedReadingTime)
									.font(HBFont.sans(11, weight: .medium))
							}
							.foregroundColor(.white)
						}
                        ProgressBadge(progress: progress)
                    }
                }

                Text(chapter.title)
                    .font(HBFont.lora(18))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Pill labels and reading time
                HStack(spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(chapter.pillLabels, id: \.self) { label in
                            Text(label)
                                .font(HBFont.sans(12))
                                .foregroundColor(.hbTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.hbSurface2)
                                .overlay(
                                    Capsule().stroke(Color.hbBorder, lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            
            // Progress bar at bottom if started
            if let progress = readingProgress, progress.isStarted {
                ProgressBar(progress: progress.progress, color: cardAccentColor)
					.padding(.leading, 10)
					.padding(.bottom, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            Rectangle()
                .fill(cardAccentColor)
				.frame(maxWidth: .infinity)
        }
		.background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

	private var cardAccentColor: Color {
		cardAccentColors[min(chapter.id, cardAccentColors.count - 1)]
	}
}

// MARK: - Progress Badge
struct ProgressBadge: View {
    let progress: ReadingProgressSnapshot
    
    var body: some View {
        if progress.isCompleted {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Completed")
                    .font(HBFont.sans(10, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#145A32"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#D5F5E3"))
            .clipShape(Capsule())
        } else if progress.isStarted {
            Text("\(Int(progress.progress * 100))%")
                .font(HBFont.sans(10, weight: .semibold))
                .foregroundColor(Color.hbAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.hbAccentLight)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(color.opacity(0.15))
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Flow Layout (for pill labels)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Previews

private struct HomeChapterCardPreview: View {
    private let chapter = HandbookChapter(
        id: 0,
        contentID: "chapter_01",
        number: "Chapter 1",
        title: "The values and principles of the UK",
        pillLabels: ["British Values", "Responsibilities", "Rights"],
        sections: []
    )

    var body: some View {
        HomeChapterCard(chapter: chapter)
            .padding()
    }
}

#Preview("HomeChapterCard") {
    let progress = ReadingProgressSnapshot(chapterID: "chapter_01", progress: 0.65, totalReadingTime: 480)
    let services = PersistenceServices(attemptStore: InMemoryExamAttemptStore(), progressStore: InMemoryReadingProgressStore(records: [progress]), highlightStore: InMemoryHighlightStore())
    HomeChapterCardPreview()
        .environment(services.progress)
}
