import SwiftUI

struct HeroHeader: View {
	@State private var animateBubbles: Bool = false
	var body: some View {
		ZStack(alignment: .topLeading) {
			// Background
			Color.hbAccent

			// Decorative circles (matching CSS ::before / ::after)
			Circle()
				.fill(Color.white.opacity(0.06))
				.frame(width: 220, height: 220)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
				.offset(x: 110, y: -60)
				.scaleEffect(animateBubbles ? 1.0 : 0.05)

			Circle()
				.fill(Color.white.opacity(0.04))
				.frame(width: 160, height: 160)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
				.offset(x: -20, y: 200)
				.scaleEffect(animateBubbles ? 1.0 : 0.05)

			// Content
			VStack(alignment: .leading, spacing: 10) {
				Text("OFFICIAL STUDY GUIDE")
					.font(HBFont.sans(11, weight: .semibold))
					.kerning(2)
					.foregroundColor(Color.hbTextMuted)
					.staggered(0.1)

				Text("Life in the\nUnited Kingdom")
					.font(HBFont.lora(32))
					.foregroundColor(.white)
					.staggered(0.2)

				Text("Your complete guide to British values, history, culture and citizenship.")
					.font(HBFont.sans(15))
					.foregroundColor(Color.white.opacity(0.7))
					.padding(.bottom, 20)
					.staggered(0.4)

				// Union Jack stripe accent
				FlagStripes()
					.mask {
						let diameter = animateBubbles ? 750.0 : 0.0
						Circle()
							.frame(width: diameter, height: diameter)
							.animation(.easeOut(duration: 1), value: animateBubbles)
					}
			}
			.padding(.horizontal)
			.padding(.top, 56)
			.padding(.bottom, 36)
		}
		.frame(maxWidth: .infinity)
		.onAppear {
			withAnimation(.bouncy(duration: 1).delay(0.6)) {
				animateBubbles = true
			}
		}
	}

}

// MARK: - Flag Stripe Decoration
struct FlagStripes: View {
	var body: some View {
		HStack(spacing: 0) {
			Rectangle().fill(Color(hex: "#012169")).frame(height: 4)
			Rectangle().fill(Color.white.opacity(0.6)).frame(height: 4)
			Rectangle().fill(Color(hex: "#CF142B")).frame(height: 4)
			Rectangle().fill(Color.white.opacity(0.6)).frame(height: 4)
			Rectangle().fill(Color(hex: "#012169")).frame(height: 4)
		}
		.clipShape(Capsule())
		.frame(height: 4)
	}
}

// MARK: - Chapter List
