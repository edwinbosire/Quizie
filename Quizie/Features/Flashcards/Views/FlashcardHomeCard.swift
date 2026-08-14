import SwiftUI

struct FlashcardHomeCard: View {
    @AppStorage(StudyStatistics.flashcardsReviewedKey) private var reviewedCount = 0
    @AppStorage(StudyStatistics.flashcardsKnownKey) private var knownCount = 0
    let onOpen: () -> Void

    var body: some View {
        QuickStartCard(
            title: "Flashcards",
            subtitle: reviewedCount == 0 ? "Cards ready to learn" : "\(knownPercentage)% known",
            icon: "rectangle.stack.fill",
            colors: [Color(hex: "#287271"), Color(hex: "#52B69A")],
            action: onOpen
        )
        .accessibilityIdentifier("flashcards.homeCard")
    }

    private var knownPercentage: Int {
        guard reviewedCount > 0 else { return 0 }
        return Int((Double(knownCount) / Double(reviewedCount) * 100).rounded())
    }
}

// MARK: - Previews

#Preview("Flashcard Home Card - New") {
    let defaults = UserDefaults(suiteName: "FlashcardHomeCardPreview.New")!
    defaults.set(0, forKey: StudyStatistics.flashcardsReviewedKey)
    defaults.set(0, forKey: StudyStatistics.flashcardsKnownKey)

    return FlashcardHomeCard(onOpen: {})
        .padding()
        .background(Color.hbBackground)
        .defaultAppStorage(defaults)
}

#Preview("Flashcard Home Card - Progress") {
    let defaults = UserDefaults(suiteName: "FlashcardHomeCardPreview.Progress")!
    defaults.set(42, forKey: StudyStatistics.flashcardsReviewedKey)
    defaults.set(34, forKey: StudyStatistics.flashcardsKnownKey)

    return FlashcardHomeCard(onOpen: {})
        .padding()
        .background(Color.hbBackground)
        .defaultAppStorage(defaults)
}
