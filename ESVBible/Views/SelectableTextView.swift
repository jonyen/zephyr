import SwiftUI
import AppKit

struct SelectableTextView: NSViewRepresentable {
    let chapter: Chapter
    let bookName: String
    let highlights: [Highlight]
    let searchHighlightStart: Int?
    let searchHighlightEnd: Int?
    let onHighlight: (Int, Int, Int, HighlightColor) -> Void  // verse, startChar, endChar, color
    let onRemoveHighlights: (Int, Int, Int) -> Void  // verse, startChar, endChar
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let textView = HighlightableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        context.coordinator.textView = textView
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onRemoveHighlights = onRemoveHighlights

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HighlightableTextView else { return }
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onRemoveHighlights = onRemoveHighlights
        context.coordinator.verseBoundaries = []

        let attrStr = buildAttributedString(coordinator: context.coordinator)
        textView.textStorage?.setAttributedString(attrStr)

        // Calculate and report content height
        DispatchQueue.main.async {
            if let layoutManager = textView.layoutManager, let container = textView.textContainer {
                layoutManager.ensureLayout(for: container)
                let usedRect = layoutManager.usedRect(for: container)
                if abs(contentHeight - usedRect.height) > 1 {
                    contentHeight = usedRect.height + 8
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func buildAttributedString(coordinator: Coordinator) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let bodyFont = NSFont(descriptor: NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body), size: 16) ?? NSFont.systemFont(ofSize: 16)
        let verseNumFont = NSFont.systemFont(ofSize: 10)

        var boundaries: [(verse: Int, start: Int, end: Int)] = []

        for verse in chapter.verses {
            // Verse number (superscript)
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: verseNumFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .baselineOffset: 6,
                .paragraphStyle: paragraphStyle
            ]
            result.append(NSAttributedString(string: "\(verse.number) ", attributes: numAttrs))

            // Verse text
            let verseStart = result.length
            let isRedLetter = RedLetterService.shared.isRedLetter(book: bookName, chapter: chapter.number, verse: verse.number)
            let isSearchHighlighted = isSearchHighlight(verse.number)

            let textStr: NSMutableAttributedString
            if isSearchHighlighted {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: NSColor.controlAccentColor
                ]
                textStr = NSMutableAttributedString(string: verse.text + " ", attributes: attrs)
            } else if isRedLetter {
                textStr = buildRedLetterAttributedString(
                    text: verse.text, font: bodyFont, paragraphStyle: paragraphStyle
                )
            } else {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: NSColor.labelColor
                ]
                textStr = NSMutableAttributedString(string: verse.text + " ", attributes: attrs)
            }

            // Apply user highlights for this verse
            let verseHighlights = highlights.filter { $0.verse == verse.number }
            for h in verseHighlights {
                let start = max(0, h.startCharOffset)
                let end = min(verse.text.count, h.endCharOffset)
                if start < end {
                    textStr.addAttribute(.backgroundColor, value: h.color.nsColor, range: NSRange(location: start, length: end - start))
                }
            }

            result.append(textStr)
            let verseEnd = result.length
            boundaries.append((verse: verse.number, start: verseStart, end: verseEnd))
        }

        coordinator.verseBoundaries = boundaries
        return result
    }

    /// Renders verse text with only the quoted speech in red, matching the original ChapterView behavior.
    private func buildRedLetterAttributedString(text: String, font: NSFont, paragraphStyle: NSParagraphStyle) -> NSMutableAttributedString {
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor
        ]
        let redAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.systemRed
        ]

        if let quoteIndex = text.firstIndex(of: "\u{201C}") {
            let before = String(text[text.startIndex..<quoteIndex])
            let quoted = String(text[quoteIndex...])
            let result = NSMutableAttributedString()
            if !before.isEmpty {
                result.append(NSAttributedString(string: before, attributes: defaultAttrs))
            }
            result.append(NSAttributedString(string: quoted + " ", attributes: redAttrs))
            return result
        } else {
            // No opening quote — continuation of a previous speech
            return NSMutableAttributedString(string: text + " ", attributes: redAttrs)
        }
    }

    private func isSearchHighlight(_ verseNumber: Int) -> Bool {
        guard let start = searchHighlightStart else { return false }
        let end = searchHighlightEnd ?? start
        return verseNumber >= start && verseNumber <= end
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: HighlightableTextView?
        var onHighlight: ((Int, Int, Int, HighlightColor) -> Void)?
        var onRemoveHighlights: ((Int, Int, Int) -> Void)?
        var verseBoundaries: [(verse: Int, start: Int, end: Int)] = []

        func mapToVerse(_ charIndex: Int) -> (verse: Int, offset: Int)? {
            for boundary in verseBoundaries {
                if charIndex >= boundary.start && charIndex < boundary.end {
                    return (boundary.verse, charIndex - boundary.start)
                }
            }
            return nil
        }
    }
}

// MARK: - Custom NSTextView with highlight context menu

class HighlightableTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        guard selectedRange().length > 0 else {
            return super.menu(for: event)
        }

        for color in HighlightColor.allCases {
            let item = NSMenuItem(title: "Highlight \(color.rawValue.capitalized)", action: #selector(applyHighlight(_:)), keyEquivalent: "")
            item.representedObject = color
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let removeItem = NSMenuItem(title: "Remove Highlight", action: #selector(removeHighlight(_:)), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        menu.addItem(copyItem)

        return menu
    }

    @objc private func applyHighlight(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? HighlightColor,
              let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }

        let range = selectedRange()
        guard range.length > 0 else { return }

        for boundary in coordinator.verseBoundaries {
            let overlapStart = max(range.location, boundary.start)
            let overlapEnd = min(range.location + range.length, boundary.end)
            if overlapStart < overlapEnd {
                let charStart = overlapStart - boundary.start
                let charEnd = overlapEnd - boundary.start
                coordinator.onHighlight?(boundary.verse, charStart, charEnd, color)
            }
        }
    }

    @objc private func removeHighlight(_ sender: NSMenuItem) {
        guard let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }

        let range = selectedRange()
        guard range.length > 0 else { return }

        for boundary in coordinator.verseBoundaries {
            let overlapStart = max(range.location, boundary.start)
            let overlapEnd = min(range.location + range.length, boundary.end)
            if overlapStart < overlapEnd {
                let charStart = overlapStart - boundary.start
                let charEnd = overlapEnd - boundary.start
                coordinator.onRemoveHighlights?(boundary.verse, charStart, charEnd)
            }
        }
    }
}
