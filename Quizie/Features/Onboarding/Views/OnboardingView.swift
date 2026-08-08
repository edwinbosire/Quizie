import SwiftUI

// MARK: - Onboarding Data

struct OnboardingPage {
    let icon: String
    let accentColor: Color
    let tagline: String
    let title: String
    let description: String
    let decorativeItems: [String]
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        icon: "book.fill",
        accentColor: .ch1Accent,
        tagline: "OFFICIAL STUDY GUIDE",
        title: "Master the\nHandbook",
        description: "Read the complete Life in the United Kingdom handbook — covering British values, history, traditions and government — organised into clear chapters and sections.",
        decorativeItems: ["Values & Principles", "History", "Government", "Traditions", "Culture"]
    ),
    OnboardingPage(
        icon: "pencil.and.list.clipboard",
        accentColor: .ch4Accent,
        tagline: "PRACTICE EXAMS",
        title: "Test Your\nKnowledge",
        description: "Take timed practice exams that mirror the real Life in the UK test — \(QuizConfiguration.practice.questionCount) questions, \(QuizConfiguration.practice.durationMinutes) minutes, with instant results and detailed scoring.",
        decorativeItems: [
            "\(QuizConfiguration.practice.questionCount) Questions",
            "\(QuizConfiguration.practice.durationMinutes) Minutes",
            "Timed",
            "Instant Results"
        ]
    ),
    OnboardingPage(
        icon: "chart.line.uptrend.xyaxis",
        accentColor: .ch5Accent,
        tagline: "TRACK PROGRESS",
        title: "Stay on\nTrack",
        description: "Monitor your reading progress and exam performance over time. See which chapters you've completed and how your scores are improving.",
        decorativeItems: ["Reading Time", "Pass Rate", "Completion", "Best Score"]
    )
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(onboardingPages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom controls
            OnboardingControls(
                currentPage: $currentPage,
                pageCount: onboardingPages.count,
                onFinish: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedOnboarding = true
                    }
                }
            )
        }
        .background(Color.hbBackground)
    }
}

// MARK: - Single Onboarding Page

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero illustration area
                OnboardingHero(page: page)

                // Text content
                VStack(alignment: .leading, spacing: 0) {
                    Text(page.tagline)
                        .appFont(.caption2.weight(.semibold))
                        .foregroundColor(page.accentColor.opacity(0.7))
                        .padding(.bottom, 12)

                    Text(page.title)
                        .appFont(.system(.title, design: .serif, weight: .semibold))
                        .foregroundColor(.hbTextPrimary)
                        .padding(.bottom, 14)

                    Text(page.description)
                        .appFont(.callout)
                        .foregroundColor(.hbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)

                    // Decorative pill tags
                    FlowLayout(spacing: 8) {
                        ForEach(page.decorativeItems, id: \.self) { item in
                            Text(item)
                                .appFont(.footnote.weight(.medium))
                                .foregroundColor(page.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(page.accentColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(page.accentColor.opacity(0.2), lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
        }
    }
}

// MARK: - Onboarding Hero

struct OnboardingHero: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            // Background
            page.accentColor

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 80, y: -40)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -30, y: 20)

            // Central icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: page.icon)
                        .appFont(.largeTitle.weight(.medium))
                        .foregroundColor(.white)
                }

                // Flag stripes accent
                FlagStripes()
                    .frame(width: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
    }
}

// MARK: - Bottom Controls

struct OnboardingControls: View {
    @Binding var currentPage: Int
    let pageCount: Int
    let onFinish: () -> Void

    private var isLastPage: Bool {
        currentPage == pageCount - 1
    }

    var body: some View {
        VStack(spacing: 16) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.hbAccent : Color.hbBorder)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // Action button
            Button {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(isLastPage ? "Get Started" : "Continue")
                        .appFont(.headline.weight(.semibold))

                    if !isLastPage {
                        Image(systemName: "arrow.right")
                            .appFont(.footnote.weight(.semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.hbAccent)
                .cornerRadius(HBRadius.md)
                .shadow(color: Color.hbAccent.opacity(0.35), radius: 8, x: 0, y: 4)
            }

            // Skip / secondary action
            if !isLastPage {
                Button {
                    onFinish()
                } label: {
                    Text("Skip")
                        .appFont(.subheadline.weight(.medium))
                        .foregroundColor(.hbTextMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.hbBackground)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
