import SwiftUI
import SwiftData

struct HandbookView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section (matches .hero in CSS)
                    HeroHeader()

                    // Chapter List
                    ChapterList()
                }
            }
            .background(Color.hbBackground)
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Hero Header
struct HeroHeader: View {
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

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 160, height: 160)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -20, y: 200)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text("OFFICIAL STUDY GUIDE")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(2)
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.bottom, 12)

                Text("Life in the\nUnited Kingdom")
                    .font(HBFont.lora(32))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.bottom, 10)

                Text("Your complete guide to British values, history, culture and citizenship.")
                    .font(HBFont.sans(15))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)

                // Union Jack stripe accent
                FlagStripes()
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
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
struct ChapterList: View {
    @Query private var allProgress: [ReadingProgress]
    @Environment(\.modelContext) private var modelContext
    
    private var overallCompletion: Double {
        ReadingProgress.overallCompletionPercentage(totalChapters: HandbookData.chapters.count, in: modelContext)
    }
    
    private var totalReadingTime: TimeInterval {
        ReadingProgress.totalReadingTime(in: modelContext)
    }
    
    private var mostRecentProgress: ReadingProgress? {
        ReadingProgress.mostRecentlyRead(in: modelContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHAPTERS")
                .font(HBFont.sans(11, weight: .semibold))
                .kerning(1.5)
                .foregroundColor(.hbTextMuted)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            
            // Progress Analytics Card
            if !allProgress.isEmpty {
                ProgressAnalyticsCard(
                    overallCompletion: overallCompletion,
                    totalReadingTime: totalReadingTime,
                    lastReadDate: mostRecentProgress?.lastReadDate
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                ForEach(HandbookData.chapters) { chapter in
                    NavigationLink(destination: ChapterView(chapter: chapter)) {
                        HomeChapterCard(chapter: chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Progress Analytics Card
struct ProgressAnalyticsCard: View {
    let overallCompletion: Double
    let totalReadingTime: TimeInterval
    let lastReadDate: Date?
    
    private var formattedReadingTime: String {
        let minutes = Int(totalReadingTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            }
        }
    }
    
    private var formattedLastRead: String {
        guard let date = lastReadDate else { return "Not started" }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.hbAccent)
                
                Text("Your Progress")
                    .font(HBFont.sans(14, weight: .semibold))
                    .foregroundColor(.hbTextPrimary)
                
                Spacer()
            }
            
            // Overall completion progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Completion")
                        .font(HBFont.sans(13))
                        .foregroundColor(.hbTextSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(overallCompletion * 100))%")
                        .font(HBFont.sans(15, weight: .bold))
                        .foregroundColor(.hbAccent)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.hbSurface2)
                            .frame(height: 8)
                        
                        // Progress fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.hbAccent, Color.hbAccent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * overallCompletion, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Stats row
            HStack(spacing: 12) {
                // Reading time stat
                StatBox(
                    icon: "clock.fill",
                    label: "Reading Time",
                    value: formattedReadingTime
                )
                
                // Last read stat
                StatBox(
                    icon: "book.fill",
                    label: "Last Read",
                    value: formattedLastRead
                )
            }
        }
        .padding(20)
        .background(Color.hbSurface)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbAccent.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.hbAccent.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.hbAccent)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(HBFont.sans(11))
                    .foregroundColor(.hbTextMuted)
                
                Text(value)
                    .font(HBFont.sans(13, weight: .semibold))
                    .foregroundColor(.hbTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.hbSurface2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.sm))
    }
}

#Preview {
    HandbookView()
        .modelContainer(for: [ReadingProgress.self, ExamAttempt.self])
}
