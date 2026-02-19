import SwiftUI
import AppKit

struct SelectableTextView: NSViewRepresentable {
    let chapter: Chapter
    let bookName: String
    let chapterNumber: Int
    let highlights: [Highlight]
    let searchHighlightStart: Int?
    let searchHighlightEnd: Int?
    let onHighlight: (Int, Int, Int, HighlightColor) -> Void  // verse, startChar, endChar, color
    let onRemoveHighlights: (Int, Int, Int) -> Void  // verse, startChar, endChar
    @Binding var contentHeight: CGFloat
    @Binding var dropCapFontSize: CGFloat
    var onHighlightVerseYOffset: ((CGFloat) -> Void)?
    let notes: [Note]
    let onAddNote: (Int, Int) -> Void  // verseStart, verseEnd
    let onEditNote: (Note) -> Void

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
        context.coordinator.onAddNote = onAddNote
        context.coordinator.onEditNote = onEditNote
        context.coordinator.notes = notes

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Observe frame changes so we can recalculate height after SwiftUI sets the frame
        scrollView.postsFrameChangedNotifications = true
        context.coordinator.scrollView = scrollView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewFrameDidChange),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HighlightableTextView else { return }
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onRemoveHighlights = onRemoveHighlights
        context.coordinator.onAddNote = onAddNote
        context.coordinator.onEditNote = onEditNote
        context.coordinator.notes = notes
        context.coordinator.verseBoundaries = []

        // Compute drop-cap size from body font metrics so the number spans exactly two lines
        let serifDescriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
        let bodyFont = NSFont(descriptor: serifDescriptor, size: 16) ?? NSFont.systemFont(ofSize: 16)
        let lineHeight = bodyFont.ascender + abs(bodyFont.descender) + bodyFont.leading
        let twoLineHeight = lineHeight * 2 + 6 // 6 = paragraphStyle.lineSpacing

        let computedFontSize = twoLineHeight

        let dropCapFont = NSFont(descriptor: serifDescriptor, size: computedFontSize) ?? NSFont.systemFont(ofSize: computedFontSize)
        let dropCapStr = NSAttributedString(string: "\(chapterNumber)", attributes: [.font: dropCapFont])
        let dropCapSize = dropCapStr.size()
        let exclusionWidth = ceil(dropCapSize.width) + 12
        context.coordinator.dropCapWidth = exclusionWidth

        // Report font size back to SwiftUI
        DispatchQueue.main.async {
            if abs(self.dropCapFontSize - computedFontSize) > 0.5 {
                self.dropCapFontSize = computedFontSize
            }
        }

        textView.textContainer?.exclusionPaths = [
            NSBezierPath(rect: CGRect(x: 0, y: 0, width: exclusionWidth, height: twoLineHeight))
        ]

        let attrStr = buildAttributedString(coordinator: context.coordinator)
        textView.textStorage?.setAttributedString(attrStr)

        // Store height callback for frame-change-driven recalculation
        let heightBinding = $contentHeight
        context.coordinator.contentHeightCallback = { newHeight in
            if abs(heightBinding.wrappedValue - newHeight) > 1 {
                heightBinding.wrappedValue = newHeight
            }
        }

        // Immediate async fallback for height + verse offset calculation
        let highlightVerse = searchHighlightStart
        let reportOffset = onHighlightVerseYOffset
        let boundaries = context.coordinator.verseBoundaries
        DispatchQueue.main.async {
            context.coordinator.recalculateHeight()

            if let verse = highlightVerse,
               let layoutManager = textView.layoutManager,
               let container = textView.textContainer,
               let boundary = boundaries.first(where: { $0.verse == verse }) {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: boundary.start, length: boundary.end - boundary.start), actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
                reportOffset?(rect.origin.y)
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
            // Skip verse 1 number — it's replaced by the drop-cap chapter number
            if verse.number > 1 {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: verseNumFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .baselineOffset: 6,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: "\(verse.number) ", attributes: numAttrs))
            }

            // Note indicator icon
            let verseNotes = coordinator.notes.filter { verse.number >= $0.verseStart && verse.number <= $0.verseEnd }
            if !verseNotes.isEmpty {
                let attachment = NSTextAttachment()
                if let image = NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: "Note") {
                    let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
                    attachment.image = image.withSymbolConfiguration(config)
                }
                let attachStr = NSMutableAttributedString(attachment: attachment)
                attachStr.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: NSRange(location: 0, length: attachStr.length))
                attachStr.append(NSAttributedString(string: " "))
                result.append(attachStr)
            }

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
        weak var scrollView: NSScrollView?
        var onHighlight: ((Int, Int, Int, HighlightColor) -> Void)?
        var onRemoveHighlights: ((Int, Int, Int) -> Void)?
        var onAddNote: ((Int, Int) -> Void)?
        var onEditNote: ((Note) -> Void)?
        var notes: [Note] = []
        var verseBoundaries: [(verse: Int, start: Int, end: Int)] = []
        var contentHeightCallback: ((CGFloat) -> Void)?
        var dropCapWidth: CGFloat = 0

        @objc func scrollViewFrameDidChange(_ notification: Notification) {
            recalculateHeight()
        }

        func recalculateHeight() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer,
                  let scrollView = scrollView else { return }
            let width = scrollView.contentView.bounds.width
            guard width > 0 else { return }
            // Explicitly set container width to match the actual available width
            container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: container)
            let usedRect = layoutManager.usedRect(for: container)
            contentHeightCallback?(usedRect.height + 8)
        }

        func mapToVerse(_ charIndex: Int) -> (verse: Int, offset: Int)? {
            for boundary in verseBoundaries {
                if charIndex >= boundary.start && charIndex < boundary.end {
                    return (boundary.verse, charIndex - boundary.start)
                }
            }
            return nil
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
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

        menu.addItem(NSMenuItem.separator())

        let noteItem = NSMenuItem(title: "Add Note", action: #selector(addNote(_:)), keyEquivalent: "")
        noteItem.target = self
        menu.addItem(noteItem)

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

    @objc private func addNote(_ sender: NSMenuItem) {
        guard let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }
        let range = selectedRange()
        guard range.length > 0 else { return }

        var verseStart = Int.max
        var verseEnd = Int.min
        for boundary in coordinator.verseBoundaries {
            let overlapStart = max(range.location, boundary.start)
            let overlapEnd = min(range.location + range.length, boundary.end)
            if overlapStart < overlapEnd {
                verseStart = min(verseStart, boundary.verse)
                verseEnd = max(verseEnd, boundary.verse)
            }
        }

        guard verseStart <= verseEnd else { return }
        coordinator.onAddNote?(verseStart, verseEnd)
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
