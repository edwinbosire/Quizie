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
                    .font(.body)
                    .foregroundColor(.hbAccent)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Reading")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(rt.textPrimary)
                
                Text("Resume from \(Int(progress * 100))% complete")
                    .font(.caption)
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
                        .font(.footnote.weight(.medium))
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
                        .font(.callout.weight(.semibold))
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
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "textformat.size")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.hbAccent)
                .clipShape(Circle())
                .shadow(color: Color.hbAccent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Reader settings")
    }
}

// MARK: - Custom Navigation Bar
struct ChapterNavBar: View {
    let currentChapter: HandbookChapter
    let dismiss: DismissAction
    let onChooseChapter: () -> Void
    let readingTheme: ReadingTheme

    private var rt: ReadingThemeStyle { readingTheme.style }

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                    Text("Contents")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(rt == .night ? .white : Color.hbAccent)
            }
            .buttonStyle(ReaderNavigationButtonStyle(theme: rt))
            .accessibilityLabel("Back to handbook contents")

            Spacer()

            Button(action: onChooseChapter) {
                HStack(spacing: 4) {
                    Text(currentChapter.number)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(rt.textMuted)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(rt.textMuted)
                }
            }
            .buttonStyle(ReaderNavigationButtonStyle(theme: rt))
            .accessibilityLabel("Choose chapter")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct ReaderNavigationButtonStyle: ButtonStyle {
    let theme: ReadingThemeStyle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(theme.surface2.opacity(theme == .night ? 0.82 : 1), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.border.opacity(0.9), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Chapter Picker Sheet
