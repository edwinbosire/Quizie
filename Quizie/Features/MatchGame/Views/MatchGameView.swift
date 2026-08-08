import SwiftUI

struct MatchGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var game = MatchGameState()
    @State private var feedbackTrigger = 0

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

            Spacer(minLength: 28)

            MatchGameMark()
                .padding(.bottom, 34)

            Text("Ready to match?")
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Color.hbTextPrimary)
                .multilineTextAlignment(.center)

            Text("Pair every Life in the UK term with its meaning as quickly as you can. A wrong match adds 3 seconds.")
                .font(.body)
                .foregroundStyle(Color.hbTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 14)

            Spacer()

            Button {
                game.start()
            } label: {
                Label("Start game", systemImage: "play.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.hbAccent)
                    .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
            }
            .accessibilityIdentifier("matchGame.start")
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
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
                    .font(.footnote.weight(.semibold))
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
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.ch4Accent)
            }

            Text("All matched!")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Color.hbTextPrimary)
                .padding(.top, 26)

            Text(format(game.finalTime ?? 0))
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.hbAccent)
                .padding(.top, 8)

            Text(resultSummary)
                .font(.callout)
                .foregroundStyle(Color.hbTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    game.restart()
                } label: {
                    Label("Play again", systemImage: "arrow.clockwise")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.hbAccent)
                        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
                }

                Button("Back to home") {
                    dismiss()
                }
                .font(.headline.weight(.semibold))
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
                    .font(.headline.weight(.bold))
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
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.hbAccent)
                    .accessibilityIdentifier("matchGame.timer")
            } else {
                Text("QUICK MATCH")
                    .font(.caption.weight(.semibold))
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

private struct MatchGameMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 9)
                    .fill(index == 1 || index == 5 ? Color.ch4AccentLight : Color.hbSurface2)
                    .frame(width: index == 1 || index == 5 ? 64 : 46, height: index == 1 || index == 5 ? 64 : 46)
                    .overlay {
                        if index == 1 || index == 5 {
                            Image(systemName: "checkmark")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.ch4Accent)
                        }
                    }
                    .offset(markOffset(for: index))
            }
        }
        .frame(width: 190, height: 150)
        .accessibilityHidden(true)
    }

    private func markOffset(for index: Int) -> CGSize {
        [
            CGSize(width: -70, height: -38),
            CGSize(width: 0, height: -38),
            CGSize(width: 70, height: -38),
            CGSize(width: -70, height: 30),
            CGSize(width: 0, height: 30),
            CGSize(width: 70, height: 30),
            CGSize(width: 0, height: 92)
        ][index]
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
                    .font(card.kind == .term ? .headline : .footnote)
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if card.kind == .term && !isMatched {
                    Text("TERM")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.hbTextMuted)
                        .padding(8)
                }

                if isMatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
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
