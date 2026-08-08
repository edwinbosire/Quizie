import SwiftUI

struct PerformanceSummary: View {
    let attempts: [ExamAttemptSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PROGRESS")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.hbTextMuted)
                    
                    Text(encouragementMessage)
                        .font(.footnote)
                        .foregroundColor(.hbTextSecondary)
                }
                Spacer()
                
                // Total attempts badge
                VStack(spacing: 2) {
                    Text("\(attempts.count)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(Color.hbAccent)
                    Text("ATTEMPTS")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.hbTextMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.hbAccentLight)
                .cornerRadius(HBRadius.sm)
            }
            
            // Stats row
            HStack(spacing: 10) {
                PerformanceStat(
                    icon: "target",
                    value: String(format: "%.0f%%", attempts.averagePercentage),
                    label: "Avg Score",
                    color: Color.hbAccent
                )
                
                PerformanceStat(
                    icon: "trophy.fill",
                    value: "\(attempts.bestScore)/24",
                    label: "Best Score",
                    color: Color(hex: "#145A32")
                )
                
                PerformanceStat(
                    icon: "checkmark.circle.fill",
                    value: String(format: "%.0f%%", attempts.passRate),
                    label: "Pass Rate",
                    color: Color(hex: "#6E2C00")
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.hbAccent.opacity(0.08),
                    Color.hbAccent.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(HBRadius.md)
        .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbAccent.opacity(0.15), lineWidth: 1))
    }
    
    var encouragementMessage: String {
        let passRate = attempts.passRate
        if passRate >= 80 {
            return "Excellent progress! You're ready for the real test."
        } else if passRate >= 60 {
            return "Great work! Keep practicing to improve further."
        } else if passRate >= 40 {
            return "Good effort! A few more attempts will help."
        } else {
            return "Keep going! Practice makes perfect."
        }
    }
}

struct PerformanceStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.hbTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.hbBackground)
        .cornerRadius(HBRadius.sm)
    }
}

// MARK: - Recent Attempts List
