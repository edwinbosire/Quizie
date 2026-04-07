import SwiftUI
import SwiftData

// MARK: - Highlightable Block Wrapper

struct HighlightableBlock<Content: View>: View {
    let chapterId: Int
    let sectionId: String
    let blockIndex: Int
    let totalBlockCount: Int
    let block: ContentBlock
    let existingHighlight: Highlight?
    let previousHighlight: Highlight?
    let nextHighlight: Highlight?
    @ViewBuilder let content: Content

    @Environment(\.modelContext) private var modelContext
    @State private var showHighlightSheet = false

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlightBackground)
            .padding(.horizontal, -8)
            .padding(.vertical, -4)
            .onLongPressGesture(minimumDuration: 0.5) {
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.impactOccurred()
                showHighlightSheet = true
            }
            .sheet(isPresented: $showHighlightSheet) {
                HighlightActionSheet(
                    chapterId: chapterId,
                    sectionId: sectionId,
                    blockIndex: blockIndex,
                    totalBlockCount: totalBlockCount,
                    block: block,
                    existingHighlight: existingHighlight
                )
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var highlightBackground: some View {
        if let highlight = existingHighlight {
            let sameColorAbove = previousHighlight?.highlightColor == highlight.highlightColor
            let sameColorBelow = nextHighlight?.highlightColor == highlight.highlightColor

            let topRadius: CGFloat = sameColorAbove ? 0 : 6
            let bottomRadius: CGFloat = sameColorBelow ? 0 : 6

            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius
            )
            .fill(highlight.highlightColor.backgroundColor)
        }
    }
}

// MARK: - Highlight Action Sheet

struct HighlightActionSheet: View {
    let chapterId: Int
    let sectionId: String
    let blockIndex: Int
    let totalBlockCount: Int
    let block: ContentBlock
    let existingHighlight: Highlight?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: HighlightColor

    private var isEditing: Bool { existingHighlight != nil }

    init(
        chapterId: Int,
        sectionId: String,
        blockIndex: Int,
        totalBlockCount: Int,
        block: ContentBlock,
        existingHighlight: Highlight?
    ) {
        self.chapterId = chapterId
        self.sectionId = sectionId
        self.blockIndex = blockIndex
        self.totalBlockCount = totalBlockCount
        self.block = block
        self.existingHighlight = existingHighlight
        _selectedColor = State(initialValue: existingHighlight?.highlightColor ?? .yellow)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(isEditing ? "Edit Highlight" : "Highlight")
                .font(HBFont.sans(16, weight: .semibold))
                .foregroundColor(.hbTextPrimary)

            // Text preview
            Text(String(block.plainText.prefix(100)))
                .font(HBFont.sans(13))
                .foregroundColor(.hbTextMuted)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Color picker
            HStack(spacing: 16) {
                ForEach(HighlightColor.allCases) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 40, height: 40)

                            if selectedColor == color {
                                Circle()
                                    .stroke(Color.hbTextPrimary, lineWidth: 2.5)
                                    .frame(width: 40, height: 40)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }

            // Extend/Reduce controls (only when editing)
            if isEditing {
                HStack(spacing: 12) {
                    Button {
                        extendHighlight(direction: -1)
                    } label: {
                        Label("Extend Up", systemImage: "arrow.up.to.line")
                            .font(HBFont.sans(13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(blockIndex == 0)

                    Button {
                        extendHighlight(direction: 1)
                    } label: {
                        Label("Extend Down", systemImage: "arrow.down.to.line")
                            .font(HBFont.sans(13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(blockIndex >= totalBlockCount - 1)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                if isEditing {
                    Button(role: .destructive) {
                        deleteHighlight()
                        dismiss()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(HBFont.sans(14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    saveHighlight()
                    dismiss()
                } label: {
                    Text(isEditing ? "Update" : "Highlight")
                        .font(HBFont.sans(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hbAccent)
            }
        }
        .padding(20)
    }

    // MARK: - Actions

    private func saveHighlight() {
        if let existing = existingHighlight {
            existing.highlightColor = selectedColor
            try? modelContext.save()
        } else {
            let preview = String(block.plainText.prefix(120))
            let highlight = Highlight(
                chapterId: chapterId,
                sectionId: sectionId,
                blockIndex: blockIndex,
                color: selectedColor,
                textPreview: preview
            )
            modelContext.insert(highlight)
            try? modelContext.save()
        }
    }

    private func deleteHighlight() {
        if let existing = existingHighlight {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    private func extendHighlight(direction: Int) {
        let targetIndex = blockIndex + direction
        guard targetIndex >= 0, targetIndex < totalBlockCount else { return }

        // Check if adjacent block already has a highlight
        let existing = Highlight.find(
            chapterId: chapterId,
            sectionId: sectionId,
            blockIndex: targetIndex,
            in: modelContext
        )

        if let existing {
            // If it's the same color, remove it (reduce)
            if existing.highlightColor == selectedColor {
                modelContext.delete(existing)
                try? modelContext.save()
            } else {
                // Change to match current color (extend with same color)
                existing.highlightColor = selectedColor
                try? modelContext.save()
            }
        } else {
            // Find the block text for preview - we need the section's blocks
            // Use the block's plainText if available from the parent context
            let highlight = Highlight(
                chapterId: chapterId,
                sectionId: sectionId,
                blockIndex: targetIndex,
                color: selectedColor,
                textPreview: ""
            )
            modelContext.insert(highlight)
            try? modelContext.save()
        }
    }
}
