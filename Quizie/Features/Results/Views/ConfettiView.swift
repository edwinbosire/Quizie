import SwiftUI

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, screenHeight: geometry.size.height)
                }
            }
            .onAppear {
                generateConfetti(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            }
        }
    }
    
    private func generateConfetti(screenWidth: CGFloat, screenHeight: CGFloat) {
        let confettiCount = 100

        confettiPieces = (0..<confettiCount).map { _ in
            let delay = Double.random(in: 0...1.5)
            return ConfettiPiece(
                x: CGFloat.random(in: 0...screenWidth),
                y: -20,
                color: randomConfettiColor(),
                size: CGFloat.random(in: 8...16),
                rotation: Double.random(in: 0...360),
                delay: delay,
                duration: Double.random(in: 2.5...4.5),
                swingAmount: CGFloat.random(in: 30...80),
                swingSpeed: Double.random(in: 0.8...1.5)
            )
        }
    }
    
    private func randomConfettiColor() -> Color {
        let colors: [Color] = [
            Color(hex: "#1B4F72"), // Blue
            Color(hex: "#145A32"), // Green
            Color(hex: "#512E5F"), // Purple
            Color(hex: "#E67E22"), // Orange
            Color(hex: "#C0392B"), // Red
            Color(hex: "#F39C12"), // Yellow
            Color(hex: "#16A085"), // Teal
            Color(hex: "#E91E63"), // Pink
        ]
        return colors.randomElement() ?? .blue
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let delay: Double
    let duration: Double
    let swingAmount: CGFloat
    let swingSpeed: Double
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenHeight: CGFloat
    
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotationAmount: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 1.5)
            .rotationEffect(.degrees(piece.rotation + rotationAmount))
            .opacity(opacity)
            .position(x: piece.x + xOffset, y: piece.y + yOffset)
            .onAppear {
                // Y-axis fall
                withAnimation(.easeIn(duration: piece.duration).delay(piece.delay)) {
                    yOffset = screenHeight + 50
                }
                
                // X-axis swing
                withAnimation(.easeInOut(duration: piece.swingSpeed).repeatForever(autoreverses: true).delay(piece.delay)) {
                    xOffset = piece.swingAmount
                }
                
                // Rotation
                withAnimation(.linear(duration: piece.duration * 0.7).repeatForever(autoreverses: false).delay(piece.delay)) {
                    rotationAmount = 360
                }
                
            }
            .task(id: piece.id) {
                do {
                    try await Task.sleep(for: .seconds(piece.delay + piece.duration * 0.7))
                } catch {
                    return
                }
                withAnimation(.easeOut(duration: piece.duration * 0.3)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Previews
#Preview("Quiz Results - Passed") {
    NavigationStack {
        QuizResultsView(engine: PreviewResultsEngine.passedEngine)
    }
}

#Preview("Quiz Results - Failed") {
    NavigationStack {
        QuizResultsView(engine: PreviewResultsEngine.failedEngine)
    }
}

// MARK: - Preview Helper
