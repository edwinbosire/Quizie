import SwiftUI

struct TestsHero: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hbAccent

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -50)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -30, y: 140)

            VStack(alignment: .leading, spacing: 16) {
                Text("MOCK TESTS")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(2)
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose Your\nPractice Test")
                    .font(HBFont.lora(30))
                    .foregroundColor(.white)
                    .lineSpacing(4)

                Text("Take any of the official-style practice tests below to gauge how ready you are.")
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stats Card
