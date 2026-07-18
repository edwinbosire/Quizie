import SwiftUI

struct ContinueReadingBanner: View {
    let progress: Double
    let onContinue: () -> Void
    let onDismiss: () -> Void
    let readingTheme: ReadingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.hbAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.hbAccent)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Reading")
                    .font(HBFont.sans(14, weight: .semibold))
                    .foregroundColor(rt.textPrimary)
                
                Text("Resume from \(Int(progress * 100))% complete")
                    .font(HBFont.sans(12))
                    .foregroundColor(rt.textSecondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(rt.textMuted)
                        .frame(width: 32, height: 32)
                        .background(rt.surface2)
                        .clipShape(Circle())
                }
                
                // Continue button
                Button {
                    onContinue()
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.hbAccent)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(rt.surface)
        .overlay(
            RoundedRectangle(cornerRadius: HBRadius.md)
                .stroke(Color.hbAccent.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
        .shadow(color: Color.hbAccent.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Reader Toolbar (Floating Action Button)
struct ReaderToolbar: View {
    @Binding var showReaderSettings: Bool

    var body: some View {
        Button {
            showReaderSettings = true
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.hbAccent)
                .clipShape(Circle())
                .shadow(color: Color.hbAccent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Custom Navigation Bar
struct ChapterNavBar: View {
    let currentChapter: HandbookChapter
    let dismiss: DismissAction
    @Binding var showChapterPicker: Bool
    let readingTheme: ReadingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                    Text("Contents")
                        .font(HBFont.sans(15, weight: .medium))
                }
                .foregroundColor(rt == .night ? .white : .hbAccent)
            }

            Spacer()

            Button {
                showChapterPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(currentChapter.number)
                        .font(HBFont.sans(14, weight: .semibold))
                        .foregroundColor(rt.textMuted)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(rt.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Chapter Picker Sheet
