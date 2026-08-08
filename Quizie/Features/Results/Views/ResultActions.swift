import SwiftUI

struct ActionButtons: View {
    let engine: QuizEngine
    @Binding var showReview: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Review answers
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showReview.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showReview ? "chevron.up" : "list.bullet.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text(showReview ? "Hide Answer Review" : "Review Answers")
                        .font(HBFont.sans(16, weight: .semibold))
                }
                .foregroundColor(Color.hbAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.hbAccentLight)
                .cornerRadius(HBRadius.md)
                .overlay(RoundedRectangle(cornerRadius: HBRadius.md).stroke(Color.hbAccent.opacity(0.4), lineWidth: 1))
            }

            // New exam
            Button {
                engine.startExam()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Try Another Exam")
                        .font(HBFont.sans(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.hbAccent)
                .cornerRadius(HBRadius.md)
                .shadow(color: Color.hbAccent.opacity(0.3), radius: 6, x: 0, y: 3)
            }

            // Return home
            Button {
                engine.returnToLobby()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .medium))
                    Text("Return to Home")
                        .font(HBFont.sans(15))
                }
                .foregroundColor(.hbTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Answer Review List
struct AnswerReviewList: View {
    let session: ExamSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("ANSWER REVIEW")
                    .font(HBFont.sans(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundColor(.hbTextMuted)
                Spacer()
                let correct = session.score
                let wrong = session.questions.count - correct
                HStack(spacing: 12) {
                    Label("\(correct)", systemImage: "checkmark.circle.fill")
                        .font(HBFont.sans(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#145A32"))
                    Label("\(wrong)", systemImage: "xmark.circle.fill")
                        .font(HBFont.sans(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#922B21"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(Array(session.questions.enumerated()), id: \.element.id) { idx, question in
                    let answer = session.answers[question.id]
                    AnswerReviewRow(index: idx + 1, question: question, answer: answer)
						.padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Answer Review Row
