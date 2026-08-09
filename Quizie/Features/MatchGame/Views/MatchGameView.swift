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

                    Text("Drag one card onto its match, or tap any two cards. Match all 6 pairs as quickly as you can.")
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
                                isIncorrect: game.incorrectCardIDs.contains(card.id),
                                action: {
                                    let previousMistakes = game.mistakeCount
                                    withAnimation(.snappy(duration: 0.25)) {
                                        game.select(cardID: card.id, at: context.date)
                                    }
                                    if game.mistakeCount > previousMistakes {
                                        feedbackTrigger += 1
                                    }
                                },
                                onDrop: { sourceCardID in
                                    let previousMatches = game.matchedCount
                                    let previousMistakes = game.mistakeCount

                                    withAnimation(.snappy(duration: 0.3)) {
                                        game.match(cardID: sourceCardID, with: card.id, at: .now)
                                    }

                                    if game.mistakeCount > previousMistakes {
                                        feedbackTrigger += 1
                                    }

                                    return game.matchedCount > previousMatches
                                        || game.mistakeCount > previousMistakes
                                }
                            )
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

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            demoCard(
                label: "TERM",
                text: "House of Commons",
                isSelected: step == 1,
                isMatched: step == 2
            )

            ghostCard()
            ghostCard()
            ghostCard()

            demoCard(
                label: "MEANING",
                text: "Elected chamber of Parliament",
                isSelected: false,
                isMatched: step == 2
            )

            ghostCard()
        }
        .padding(.horizontal, 20)
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
        ZStack(alignment: .topLeading) {
            Text(text)
                .appFont(label == "TERM" ? .caption.weight(.semibold) : .caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.hbTextPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .padding(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(label)
                .appFont(.caption2.weight(.bold))
                .foregroundStyle(
                    isSelected ? Color.white.opacity(0.82) : isMatched ? Color.ch4Accent : Color.hbTextMuted
                )
                .padding(8)

            if isMatched || isSelected {
                Image(systemName: isMatched ? "checkmark.circle.fill" : "hand.tap.fill")
                    .appFont(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? Color.white : Color.ch4Accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
                    .symbolEffect(.bounce, value: isSelected || isMatched)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(isSelected ? Color.hbAccent : isMatched ? Color.ch4AccentLight : Color.hbSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    isSelected ? Color.hbAccent : isMatched ? Color.ch4Accent : Color.hbBorder,
                    lineWidth: isSelected || isMatched ? 2 : 1
                )
        }
        .scaleEffect(isSelected ? 0.98 : 1)
    }

    private func ghostCard() -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(Color.hbTextMuted.opacity(0.14))
                .frame(width: 28, height: 6)

            Spacer()

            Capsule()
                .fill(Color.hbTextMuted.opacity(0.12))
                .frame(height: 7)

            Capsule()
                .fill(Color.hbTextMuted.opacity(0.09))
                .frame(width: 48, height: 7)
        }
        .padding(10)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.hbSurface2.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.hbBorder.opacity(0.65), lineWidth: 1)
        }
        .accessibilityHidden(true)
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
                title: "Drag or tap two cards",
                detail: "Pair one term with one meaning"
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var isDropTargeted = false

    let card: MatchGameCard
    let isSelected: Bool
    let isMatched: Bool
    let isIncorrect: Bool
    let action: () -> Void
    let onDrop: (String) -> Bool

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
                        .symbolEffect(.bounce, value: isMatched)
                }
            }
            .frame(minHeight: 128)
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(borderColor, lineWidth: isSelected || isIncorrect || isDropTargeted ? 2 : 1)
            }
            .scaleEffect(tileScale)
            .rotationEffect(.degrees(isIncorrect ? -1.2 : 0))
            .shadow(
                color: isDropTargeted ? Color.hbAccent.opacity(0.22) : .clear,
                radius: 8,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .draggable(card.id) {
            MatchTileDragPreview(card: card)
        }
        .dropDestination(for: String.self) { cardIDs, _ in
            guard let sourceCardID = cardIDs.first else { return false }
            return onDrop(sourceCardID)
        } isTargeted: { targeted in
            withAnimation(.snappy(duration: 0.2)) {
                isDropTargeted = targeted && !isMatched
            }
        }
        .animation(.snappy(duration: 0.24), value: isSelected)
        .animation(.snappy(duration: 0.24), value: isMatched)
        .animation(.bouncy(duration: 0.32), value: isIncorrect)
        .accessibilityLabel("\(card.kind == .term ? "Term" : "Definition"): \(card.text)")
        .accessibilityValue(isMatched ? "Matched" : isSelected ? "Selected" : "")
        .accessibilityHint("Tap to select, or drag onto its matching card")
        .accessibilityIdentifier("matchGame.card.\(card.id)")
    }

    private var backgroundColor: Color {
        if isMatched {
            return Color.ch4AccentLight
        }
        if isDropTargeted {
            return Color.hbSurface2
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
        if isDropTargeted {
            return Color.hbAccent
        }
        if isIncorrect {
            return Color(hex: "#B54131")
        }
        if isSelected {
            return Color.hbAccent
        }
        return Color.hbBorder
    }

    private var tileScale: CGFloat {
        if isDropTargeted {
            return 1.035
        }
        if isSelected {
            return 0.97
        }
        if isIncorrect {
            return 0.98
        }
        return 1
    }
}

private struct MatchTileDragPreview: View {
    let card: MatchGameCard

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.hbSurface)

            Text(card.text)
                .appFont(card.kind == .term ? .headline : .footnote)
                .foregroundStyle(Color.hbTextPrimary)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if card.kind == .term {
                Text("TERM")
                    .appFont(.caption2.weight(.semibold))
                    .foregroundStyle(Color.hbTextMuted)
                    .padding(8)
            }
        }
        .frame(width: 112, height: 128)
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.hbAccent, lineWidth: 2)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 7)
        .scaleEffect(1.03)
    }
}

#Preview {
    NavigationStack {
        MatchGameView()
    }
}
