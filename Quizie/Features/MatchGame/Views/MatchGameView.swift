import SwiftUI

struct MatchGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = MatchGameState()
    @State private var feedbackTrigger = 0
    @State private var isReadyContentVisible = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        ZStack {
            Color.hbBackground.ignoresSafeArea()

            switch game.phase {
            case .ready:
                readyView
            case .playing:
                gameView
            case .finished:
                resultsView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(.error, trigger: feedbackTrigger)
        .onChange(of: game.phase) { _, phase in
            guard phase == .finished, let finalTime = game.finalTime else { return }
            StudyStatistics.recordMatchRound(time: finalTime)
        }
    }

    private var readyView: some View {
        VStack(spacing: 0) {
            gameHeader(showsTimer: false)

            ScrollView {
                VStack(spacing: 0) {
                    MatchGameHowToDemo()
                        .padding(.top, 26)

                    Text("Ready to match?")
                        .appFont(.system(.title, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.hbTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)

                    Text("Tap a term, then tap the meaning that belongs with it. Match all 6 pairs as quickly as you can.")
                        .appFont(.body)
                        .foregroundStyle(Color.hbTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 10)

                    MatchGameRulesCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 24)
                }
                .opacity(isReadyContentVisible ? 1 : 0)
                .offset(y: isReadyContentVisible ? 0 : 12)
            }
            .scrollIndicators(.hidden)

            Button {
                game.start()
            } label: {
                Label("Start game", systemImage: "play.fill")
                    .appFont(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.hbAccent)
                    .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
            }
            .accessibilityIdentifier("matchGame.start")
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color.hbBackground)
        }
        .task {
            guard !isReadyContentVisible else { return }
            if reduceMotion {
                isReadyContentVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    isReadyContentVisible = true
                }
            }
        }
    }

    private var gameView: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            ScrollView {
                VStack(spacing: 18) {
                    gameHeader(showsTimer: true, date: context.date)

                    HStack {
                        Label(
                            "\(game.matchedCount) of \(game.pairCount) matched",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(Color.hbAccent)

                        Spacer()

                        if game.mistakeCount > 0 {
                            Text("+\(Int(game.penaltyTime))s penalty")
                                .foregroundStyle(Color(hex: "#A33A2B"))
                        } else {
                            Text("No penalties")
                                .foregroundStyle(Color.hbTextMuted)
                        }
                    }
                    .appFont(.footnote.weight(.semibold))
                    .padding(.horizontal, 20)

                    ProgressView(value: Double(game.matchedCount), total: Double(game.pairCount))
                        .tint(Color.hbAccent)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(game.cards) { card in
                            MatchTile(
                                card: card,
                                isSelected: game.selectedCardID == card.id,
                                isMatched: game.isMatched(card),
                                isIncorrect: game.incorrectCardIDs.contains(card.id)
                            ) {
                                let previousMistakes = game.mistakeCount
                                withAnimation(.snappy(duration: 0.25)) {
                                    game.select(cardID: card.id, at: context.date)
                                }
                                if game.mistakeCount > previousMistakes {
                                    feedbackTrigger += 1
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            gameHeader(showsTimer: false)

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.ch4AccentLight)
                    .frame(width: 118, height: 118)

                Image(systemName: "trophy.fill")
                    .appFont(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.ch4Accent)
            }

            Text("All matched!")
                .appFont(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Color.hbTextPrimary)
                .padding(.top, 26)

            Text(format(game.finalTime ?? 0))
                .appFont(.largeTitle.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.hbAccent)
                .padding(.top, 8)

            Text(resultSummary)
                .appFont(.callout)
                .foregroundStyle(Color.hbTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    game.restart()
                } label: {
                    Label("Play again", systemImage: "arrow.clockwise")
                        .appFont(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.hbAccent)
                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                }

                Button("Back to home") {
                    dismiss()
                }
                .appFont(.headline.weight(.semibold))
                .foregroundStyle(Color.hbAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private var resultSummary: String {
        if game.mistakeCount == 0 {
            return "Perfect round — no time penalties."
        }
        return "\(game.mistakeCount) wrong \(game.mistakeCount == 1 ? "match" : "matches") added \(Int(game.penaltyTime)) seconds."
    }

    @ViewBuilder
    private func gameHeader(showsTimer: Bool, date: Date = .now) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .appFont(.headline.weight(.bold))
                    .foregroundStyle(Color.hbTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.hbSurface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(Color.hbBorder, lineWidth: 1)
                    }
            }
            .accessibilityLabel("Close matching game")

            Spacer()

            if showsTimer {
                Label(format(game.elapsedTime(at: date)), systemImage: "stopwatch.fill")
                    .appFont(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.hbAccent)
                    .accessibilityIdentifier("matchGame.timer")
            } else {
                Text("QUICK MATCH")
                    .appFont(.caption.weight(.semibold))
                    .foregroundStyle(Color.hbTextMuted)
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func format(_ time: TimeInterval) -> String {
        String(format: "%.1f seconds", time)
    }
}

private struct MatchGameHowToDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    var body: some View {
        VStack(spacing: 8) {
            demoCard(
                label: "TERM",
                text: "House of Commons",
                isSelected: step == 1,
                isMatched: step == 2
            )

            ZStack {
                Capsule()
                    .fill(step == 2 ? Color.ch4Accent : Color.hbBorder)
                    .frame(width: 3, height: 22)

                Image(systemName: step == 2 ? "checkmark.circle.fill" : "arrow.down")
                    .appFont(.caption.weight(.bold))
                    .foregroundStyle(step == 2 ? Color.ch4Accent : Color.hbTextMuted)
                    .padding(5)
                    .background(Color.hbBackground)
                    .clipShape(Circle())
            }

            demoCard(
                label: "MEANING",
                text: "The elected chamber of Parliament",
                isSelected: false,
                isMatched: step == 2
            )
        }
        .frame(maxWidth: 310)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example match: House of Commons pairs with the elected chamber of Parliament")
        .task {
            guard step == 0 else { return }

            if reduceMotion {
                step = 2
                return
            }

            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.35)) {
                step = 1
            }

            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.4)) {
                step = 2
            }
        }
    }

    private func demoCard(
        label: String,
        text: String,
        isSelected: Bool,
        isMatched: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .appFont(.caption2.weight(.bold))
                .foregroundStyle(
                    isSelected ? Color.white.opacity(0.82) : isMatched ? Color.ch4Accent : Color.hbTextMuted
                )
                .frame(width: 58, alignment: .leading)

            Text(text)
                .appFont(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.hbTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isMatched ? "checkmark.circle.fill" : "hand.tap")
                .foregroundStyle(
                    isSelected ? Color.white : isMatched ? Color.ch4Accent : Color.hbTextMuted
                )
                .symbolEffect(.bounce, value: isSelected || isMatched)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(isSelected ? Color.hbAccent : isMatched ? Color.ch4AccentLight : Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(
                    isSelected ? Color.hbAccent : isMatched ? Color.ch4Accent : Color.hbBorder,
                    lineWidth: isSelected || isMatched ? 2 : 1
                )
        }
        .scaleEffect(isSelected ? 0.98 : 1)
    }
}

private struct MatchGameRulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOW TO PLAY")
                .appFont(.caption2.weight(.bold))
                .foregroundStyle(Color.hbTextMuted)

            rule(
                icon: "hand.tap.fill",
                title: "Choose two cards",
                detail: "One term and one meaning"
            )
            rule(
                icon: "checkmark.circle.fill",
                title: "Correct pairs stay matched",
                detail: "Clear all 6 pairs to finish"
            )
            rule(
                icon: "plus.circle.fill",
                title: "Wrong pair? Keep going",
                detail: "+3 seconds is added to your time",
                tint: Color(hex: "#A33A2B")
            )
        }
        .padding(16)
        .background(Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("matchGame.howToPlay")
    }

    private func rule(
        icon: String,
        title: String,
        detail: String,
        tint: Color = .hbAccent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .appFont(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.hbTextPrimary)

                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(Color.hbTextSecondary)
            }
        }
    }
}

private struct MatchTile: View {
    let card: MatchGameCard
    let isSelected: Bool
    let isMatched: Bool
    let isIncorrect: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(backgroundColor)

                Text(card.text)
                    .appFont(card.kind == .term ? .headline : .footnote)
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if card.kind == .term && !isMatched {
                    Text("TERM")
                        .appFont(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.hbTextMuted)
                        .padding(8)
                }

                if isMatched {
                    Image(systemName: "checkmark.circle.fill")
                        .appFont(.subheadline.weight(.bold))
                        .foregroundStyle(Color.ch4Accent)
                        .padding(8)
                }
            }
            .frame(minHeight: 128)
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(borderColor, lineWidth: isSelected || isIncorrect ? 2 : 1)
            }
            .scaleEffect(isSelected ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .accessibilityLabel("\(card.kind == .term ? "Term" : "Definition"): \(card.text)")
        .accessibilityValue(isMatched ? "Matched" : isSelected ? "Selected" : "")
        .accessibilityIdentifier("matchGame.card.\(card.id)")
    }

    private var backgroundColor: Color {
        if isMatched {
            return Color.ch4AccentLight
        }
        if isIncorrect {
            return Color(hex: "#F8DDD8")
        }
        if isSelected {
            return Color.hbAccent
        }
        return Color.hbSurface
    }

    private var foregroundColor: Color {
        isSelected ? .white : .hbTextPrimary
    }

    private var borderColor: Color {
        if isMatched {
            return Color.ch4Accent
        }
        if isIncorrect {
            return Color(hex: "#B54131")
        }
        if isSelected {
            return Color.hbAccent
        }
        return Color.hbBorder
    }
}

#Preview {
    NavigationStack {
        MatchGameView()
    }
}
