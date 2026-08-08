import SwiftUI

struct MatchGameHomeCard: View {
    @AppStorage(StudyStatistics.matchRoundsKey) private var completedRounds = 0
    @AppStorage(StudyStatistics.matchBestTimeKey) private var bestTime = 0.0
    let onOpen: () -> Void

    var body: some View {
        StudyActivityCard(
            title: "Quick Match",
            icon: "rectangle.3.group.fill",
            accent: .ch5Accent,
            accentLight: .ch5AccentLight,
            metric: bestTime == 0 ? "—" : String(format: "%.1fs", bestTime),
            metricLabel: bestTime == 0 ? "Set a time" : "Best time",
            detail: completedRounds == 0
                ? "6 pairs ready"
                : "\(completedRounds) \(completedRounds == 1 ? "round" : "rounds") played",
            accessibilityIdentifier: "matchGame.homeCard",
            action: onOpen
        )
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
