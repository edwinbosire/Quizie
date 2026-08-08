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
                    .appFont(.caption2.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose Your\nPractice Test")
                    .appFont(.system(.title, design: .serif, weight: .semibold))
                    .foregroundColor(.white)

                Text("Take any of the official-style practice tests below to gauge how ready you are.")
                    .appFont(.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
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
