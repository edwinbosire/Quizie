import SwiftUI

struct SelectableTextSelection: Equatable {
    let range: NSRange
    let rect: CGRect
}

struct SelectableTextHighlight {
    let range: NSRange
    let color: Color
}

enum SelectableTextStyle {
    case body
    case serifBodyItalic
    case serifHeadlineSemibold
    case footnoteSemibold
    case captionSemibold
    case footnote

    var swiftUIFont: Font {
        switch self {
        case .body: .body
        case .serifBodyItalic: .system(.body, design: .serif).italic()
        case .serifHeadlineSemibold: .system(.headline, design: .serif, weight: .semibold)
        case .footnoteSemibold: .footnote.weight(.semibold)
        case .captionSemibold: .caption.weight(.semibold)
        case .footnote: .footnote
        }
    }
}

#if canImport(UIKit)
import UIKit

/// A SwiftUI-sized `UITextView` that keeps UIKit's native selection interaction,
/// including the selection handles and loupe.
struct SelectableTextView: UIViewRepresentable {
    let attributedText: AttributedString
    let fontScale: CGFloat
    let lineSpacing: CGFloat
    let style: SelectableTextStyle
    let rangeOffset: Int
    let emphasizedRanges: [NSRange]
    let highlights: [SelectableTextHighlight]
    let isSelectionActive: Bool
    let onSelectionChange: (SelectableTextSelection?) -> Void
    let onHighlight: ([NSRange], HighlightColor) -> Void
    let onCreateFlashcard: ([NSRange]) -> Void
    let onHighlightTap: (SelectableTextSelection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChange: onSelectionChange,
            onHighlight: onHighlight,
            onCreateFlashcard: onCreateFlashcard,
            onHighlightTap: onHighlightTap
        )
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        context.coordinator.observeTextInteraction(in: textView)
        context.coordinator.observeHighlightTaps(in: textView)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onCreateFlashcard = onCreateFlashcard
        context.coordinator.onHighlightTap = onHighlightTap
        context.coordinator.rangeOffset = rangeOffset
        context.coordinator.observeTextInteraction(in: textView)
        context.coordinator.observeHighlightTaps(in: textView)

        let updatedText = NSMutableAttributedString(
            attributedString: NSAttributedString(attributedText)
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        let font = style.uiFont(
            scale: fontScale,
            compatibleWith: textView.traitCollection
        )
        updatedText.addAttribute(
            .font,
            value: font,
            range: NSRange(location: 0, length: updatedText.length)
        )
        updatedText.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: updatedText.length)
        )
        for emphasizedRange in emphasizedRanges where
            emphasizedRange.location >= 0 &&
            NSMaxRange(emphasizedRange) <= updatedText.length {
            updatedText.addAttribute(
                .font,
                value: style.uiFont(
                    scale: fontScale,
                    emphasized: true,
                    compatibleWith: textView.traitCollection
                ),
                range: emphasizedRange
            )
        }
        let localizedHighlights = localizedHighlights(textLength: updatedText.length)
        context.coordinator.highlightRanges = localizedHighlights.map(\.range)
        for highlight in localizedHighlights {
            updatedText.addAttribute(.backgroundColor, value: UIColor(highlight.color), range: highlight.range)
        }
        if !textView.attributedText.isEqual(to: updatedText) {
            context.coordinator.isUpdatingText = true
            defer { context.coordinator.isUpdatingText = false }
            let selectedRange = textView.selectedRange
            textView.attributedText = updatedText
            if NSMaxRange(selectedRange) <= updatedText.length {
                textView.selectedRange = selectedRange
            }
        }

        if context.coordinator.wasSelectionActive && !isSelectionActive {
            context.coordinator.isUpdatingText = true
            textView.selectedRange = NSRange(location: 0, length: 0)
            context.coordinator.isUpdatingText = false
        }
        context.coordinator.wasSelectionActive = isSelectionActive
    }

    private func localizedHighlights(textLength: Int) -> [SelectableTextHighlight] {
        let segmentRange = NSRange(location: rangeOffset, length: textLength)
        return highlights.compactMap { highlight in
            let intersection = NSIntersectionRange(highlight.range, segmentRange)
            guard intersection.length > 0 else { return nil }
            return SelectableTextHighlight(
                range: NSRange(
                    location: intersection.location - rangeOffset,
                    length: intersection.length
                ),
                color: highlight.color
            )
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UITextInteractionDelegate {
        var onSelectionChange: (SelectableTextSelection?) -> Void
        var onHighlight: ([NSRange], HighlightColor) -> Void
        var onCreateFlashcard: ([NSRange]) -> Void
        var onHighlightTap: (SelectableTextSelection) -> Void
        var highlightRanges: [NSRange] = []
        var wasSelectionActive = false
        var textInteraction: UITextInteraction?
        var isUpdatingText = false
        var rangeOffset = 0

        private var isInteracting = false
        private weak var textView: UITextView?
        private weak var highlightTapRecognizer: UITapGestureRecognizer?

        init(
            onSelectionChange: @escaping (SelectableTextSelection?) -> Void,
            onHighlight: @escaping ([NSRange], HighlightColor) -> Void,
            onCreateFlashcard: @escaping ([NSRange]) -> Void,
            onHighlightTap: @escaping (SelectableTextSelection) -> Void
        ) {
            self.onSelectionChange = onSelectionChange
            self.onHighlight = onHighlight
            self.onCreateFlashcard = onCreateFlashcard
            self.onHighlightTap = onHighlightTap
        }

        func observeTextInteraction(in textView: UITextView) {
            self.textView = textView
            guard textInteraction == nil else { return }

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                let interaction = textView.interactions
                    .compactMap { $0 as? UITextInteraction }
                    .first { $0.textInteractionMode == .nonEditable }
                interaction?.delegate = self
                self.textInteraction = interaction
            }
        }

        func observeHighlightTaps(in textView: UITextView) {
            guard highlightTapRecognizer == nil else { return }
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(handleHighlightTap(_:))
            )
            recognizer.cancelsTouchesInView = false
            textView.addGestureRecognizer(recognizer)
            highlightTapRecognizer = recognizer
        }

        @objc private func handleHighlightTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let textView,
                  let range = highlightRange(
                      at: recognizer.location(in: textView),
                      in: textView
                  ) else { return }

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.isUpdatingText = true
                textView.selectedRange = range
                self.isUpdatingText = false
                self.onHighlightTap(
                    SelectableTextSelection(
                        range: NSRange(
                            location: range.location + self.rangeOffset,
                            length: range.length
                        ),
                        rect: self.selectionRect(for: range, in: textView)
                    )
                )
            }
        }

        private func highlightRange(at point: CGPoint, in textView: UITextView) -> NSRange? {
            highlightRanges.first { range in
                guard let start = textView.position(
                    from: textView.beginningOfDocument,
                    offset: range.location
                ),
                let end = textView.position(from: start, offset: range.length),
                let textRange = textView.textRange(from: start, to: end) else {
                    return false
                }
                return textView.selectionRects(for: textRange).contains {
                    !$0.rect.isEmpty && $0.rect.insetBy(dx: -2, dy: -2).contains(point)
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView
            guard !isInteracting, !isUpdatingText else { return }
            publishSelection(from: textView)
        }

        func interactionWillBegin(_ interaction: UITextInteraction) {
            isInteracting = true
        }

        func interactionDidEnd(_ interaction: UITextInteraction) {
            isInteracting = false
            if let textView {
                publishSelection(from: textView)
            }
        }

        private func publishSelection(from textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else {
                onSelectionChange(nil)
                return
            }
            onSelectionChange(
                SelectableTextSelection(
                    range: NSRange(
                        location: range.location + rangeOffset,
                        length: range.length
                    ),
                    rect: selectionRect(for: range, in: textView)
                )
            )
        }

        private func selectionRect(for range: NSRange, in textView: UITextView) -> CGRect {
            guard let start = textView.position(
                from: textView.beginningOfDocument,
                offset: range.location
            ),
            let end = textView.position(from: start, offset: range.length),
            let textRange = textView.textRange(from: start, to: end) else {
                return .zero
            }

            let rect = textView.selectionRects(for: textRange)
                .map(\.rect)
                .filter { !$0.isEmpty }
                .reduce(CGRect.null) { $0.union($1) }
            return rect.isNull ? .zero : textView.convert(rect, to: nil)
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextInRanges ranges: [NSValue],
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let selectedRanges = ranges
                .map(\.rangeValue)
                .filter { $0.length > 0 }
            guard !selectedRanges.isEmpty else { return nil }

            let highlightAction = UIAction(
                title: "Highlight",
                image: UIImage(systemName: "highlighter")
            ) { [weak self] _ in
                guard let self else { return }
                let documentRanges = selectedRanges.map {
                    NSRange(
                        location: $0.location + self.rangeOffset,
                        length: $0.length
                    )
                }
                self.onHighlight(
                    documentRanges,
                    HighlightColor.allCases.first ?? .yellow
                )
            }

            let createFlashcardAction = UIAction(
                title: "Create Flashcard",
                image: UIImage(systemName: "sparkles.rectangle.stack")
            ) { [weak self] _ in
                guard let self else { return }
                self.onCreateFlashcard(selectedRanges.map {
                    NSRange(location: $0.location + self.rangeOffset, length: $0.length)
                })
            }

            return UIMenu(children: [highlightAction, createFlashcardAction])
        }
    }
}

#else

struct SelectableTextView: View {
    let attributedText: AttributedString
    let fontScale: CGFloat
    let lineSpacing: CGFloat
    let style: SelectableTextStyle
    let rangeOffset: Int
    let emphasizedRanges: [NSRange]
    let highlights: [SelectableTextHighlight]
    let isSelectionActive: Bool
    let onSelectionChange: (SelectableTextSelection?) -> Void
    let onHighlight: ([NSRange], HighlightColor) -> Void
    let onCreateFlashcard: ([NSRange]) -> Void
    let onHighlightTap: (SelectableTextSelection) -> Void

    var body: some View {
        Text(renderedText)
            .font(style.swiftUIFont.scaled(by: fontScale))
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
    }

    private var renderedText: AttributedString {
        var result = attributedText
        let plainText = String(result.characters)
        let segmentRange = NSRange(
            location: rangeOffset,
            length: (plainText as NSString).length
        )
        for highlight in highlights {
            let intersection = NSIntersectionRange(highlight.range, segmentRange)
            let localRange = NSRange(
                location: intersection.location - rangeOffset,
                length: intersection.length
            )
            guard intersection.length > 0,
                  let stringRange = Range(localRange, in: plainText),
                  let attributedRange = Range(stringRange, in: result) else {
                continue
            }
            result[attributedRange].backgroundColor = highlight.color
        }
        return result
    }
}

#endif

#if canImport(UIKit)
private extension SelectableTextStyle {
    func uiFont(
        scale: CGFloat,
        emphasized: Bool = false,
        compatibleWith traitCollection: UITraitCollection
    ) -> UIFont {
        let configuration: (
            size: CGFloat,
            textStyle: UIFont.TextStyle,
            weight: UIFont.Weight,
            design: UIFontDescriptor.SystemDesign,
            italic: Bool
        ) = switch self {
        case .body: (17, .body, emphasized ? .semibold : .regular, .default, false)
        case .serifBodyItalic: (17, .body, emphasized ? .semibold : .regular, .serif, true)
        case .serifHeadlineSemibold: (17, .headline, .semibold, .serif, false)
        case .footnoteSemibold: (13, .footnote, .semibold, .default, false)
        case .captionSemibold: (12, .caption1, .semibold, .default, false)
        case .footnote: (13, .footnote, emphasized ? .semibold : .regular, .default, false)
        }

        var descriptor = UIFont.systemFont(
            ofSize: configuration.size * scale,
            weight: configuration.weight
        ).fontDescriptor
        descriptor = descriptor.withDesign(configuration.design) ?? descriptor
        if configuration.italic,
           let italicDescriptor = descriptor.withSymbolicTraits(.traitItalic) {
            descriptor = italicDescriptor
        }
        let font = UIFont(descriptor: descriptor, size: configuration.size * scale)
        return UIFontMetrics(forTextStyle: configuration.textStyle).scaledFont(
            for: font,
            compatibleWith: traitCollection
        )
    }
}
#endif
