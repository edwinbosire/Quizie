import SwiftUI

struct MatchGameHomeCard: View {
    @AppStorage(StudyStatistics.matchRoundsKey) private var completedRounds = 0
    @AppStorage(StudyStatistics.matchBestTimeKey) private var bestTime = 0.0
    let onOpen: () -> Void

    var body: some View {
        QuickStartCard(
            title: "Quick Match",
            subtitle: completedRounds == 0 ? "6 pairs ready" : "Best: \(String(format: "%.1fs", bestTime))",
            icon: "rectangle.3.group.fill",
            colors: [Color(hex: "#6C3FA0"), Color(hex: "#A56CC1")],
            action: onOpen
        )
        .accessibilityIdentifier("matchGame.homeCard")
    }
}

// MARK: - Previews

#Preview("Match Game Home Card - New") {
    let defaults = UserDefaults(suiteName: "MatchGameHomeCardPreview.New")!
    defaults.set(0, forKey: StudyStatistics.matchRoundsKey)
    defaults.set(0.0, forKey: StudyStatistics.matchBestTimeKey)

    return MatchGameHomeCard(onOpen: {})
        .padding()
        .background(Color.hbBackground)
        .defaultAppStorage(defaults)
}

#Preview("Match Game Home Card - Progress") {
    let defaults = UserDefaults(suiteName: "MatchGameHomeCardPreview.Progress")!
    defaults.set(7, forKey: StudyStatistics.matchRoundsKey)
    defaults.set(18.4, forKey: StudyStatistics.matchBestTimeKey)

    return MatchGameHomeCard(onOpen: {})
        .padding()
        .background(Color.hbBackground)
        .defaultAppStorage(defaults)
}
