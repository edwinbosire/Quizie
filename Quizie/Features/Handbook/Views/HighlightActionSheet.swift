import SwiftUI

// MARK: - Block Frame Preference Key

struct BlockFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Block Selection State

struct BlockSelection: Equatable {
    var anchorIndex: Int
    var currentIndex: Int
    var isDragging: Bool = true

    var startIndex: Int { min(anchorIndex, currentIndex) }
    var endIndex: Int { max(anchorIndex, currentIndex) }

    func contains(_ index: Int) -> Bool {
        index >= startIndex && index <= endIndex
    }
}

// MARK: - Highlightable Block Wrapper

struct HighlightableBlock<Content: View>: View {
    let displayIndex: Int
    let existingHighlight: HighlightSnapshot?
    let previousHighlight: HighlightSnapshot?
    let nextHighlight: HighlightSnapshot?
    let isSelected: Bool
    let isSelectionStart: Bool
    let isSelectionEnd: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlightBackground)
            .padding(.horizontal, -8)
            .padding(.vertical, -4)
    }

    @ViewBuilder
    private var highlightBackground: some View {
        if isSelected {
            let topRadius: CGFloat = isSelectionStart ? 6 : 0
            let bottomRadius: CGFloat = isSelectionEnd ? 6 : 0

            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius
            )
            .fill(Color.accentColor.opacity(0.15))
            .overlay {
                HStack(spacing: 0) {
                    if isSelectionStart {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 2)
                        }
                        .frame(maxHeight: .infinity)
                        .offset(x: -2)
                    }

                    Spacer(minLength: 0)

                    if isSelectionEnd {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 2)
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                        }
                        .frame(maxHeight: .infinity)
                        .offset(x: 2)
                    }
                }
            }
        } else if let highlight = existingHighlight {
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

// MARK: - Highlight Selection Toolbar

struct HighlightSelectionToolbar: View {
    let hasExistingHighlights: Bool
    let initialColor: HighlightColor
    let onSave: (HighlightColor) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var selectedColor: HighlightColor

    init(
        hasExistingHighlights: Bool,
        initialColor: HighlightColor = .yellow,
        onSave: @escaping (HighlightColor) -> Void,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.hasExistingHighlights = hasExistingHighlights
        self.initialColor = initialColor
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _selectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(HighlightColor.allCases) { color in
                    Button {
                        selectedColor = color
                        onSave(color)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 30, height: 30)

                            if selectedColor == color {
                                Image(systemName: "checkmark")
                                    .appFont(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                if hasExistingHighlights {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .appFont(.footnote.weight(.medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .appFont(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}
