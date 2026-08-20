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
    let selectedFont: String
    let bionicReadingEnabled: Bool
    let theme: ReadingTheme

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
        let bodyFont = resolvedBodyFont
        let lineHeight = bodyFont.ascender + abs(bodyFont.descender) + bodyFont.leading
        let twoLineHeight = lineHeight * 2 + 6 // 6 = paragraphStyle.lineSpacing

        let computedFontSize = twoLineHeight

        let serifDescriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
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

        let bodyFont = resolvedBodyFont
        let verseNumFont = NSFont.systemFont(ofSize: 10)

        var boundaries: [(verse: Int, start: Int, end: Int)] = []

        // PoetryLayout drops the omitted verses (Mark 9:44, Acts 8:37, …), which
        // carry no text and would otherwise leave a dangling numeral, and decides
        // where a poem breaks away from the surrounding prose.
        let paragraphStarts = ParagraphService.shared.paragraphStarts(
            book: bookName, chapter: chapter.number)
        let headings = HeadingService.shared.headings(book: bookName, chapter: chapter.number)
        let headingForVerse = Dictionary(headings.map { ($0.verse, $0.text) },
                                         uniquingKeysWith: { first, _ in first })


        for (entryIndex, entry) in PoetryLayout.layout(chapter.verses,
                                                       paragraphStarts: paragraphStarts).enumerated() {
            let verse = entry.verse
            let chunk = NSMutableAttributedString()

            // The ESV's own heading, above the paragraph it opens. It sits
            // between verse chunks, so it shifts no offset inside a verse.
            // entryIndex 0's heading is rendered above the text view instead.
            if entryIndex > 0, entry.startsParagraph, let heading = headingForVerse[verse.number] {
                let headingStyle = NSMutableParagraphStyle()
                headingStyle.lineSpacing = 6
                headingStyle.paragraphSpacingBefore = entryIndex > 0 ? headingGap : 0
                headingStyle.paragraphSpacing = 2
                result.append(NSAttributedString(string: heading + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: theme.nsTextColor,
                    .paragraphStyle: headingStyle
                ]))
            }
            // Space before a new paragraph — but not above the first one, which
            // would push the whole chapter down away from the drop cap.
            let opensWithHeading = entry.startsParagraph && headingForVerse[verse.number] != nil
            let spacingBefore: CGFloat = entry.startsParagraph && entryIndex > 0 && !opensWithHeading ? paragraphGap : 0

            // Skip verse 1 number — it's replaced by the drop-cap chapter number
            if verse.number > 1 {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: verseNumFont,
                    .foregroundColor: theme.nsSecondaryColor,
                    .baselineOffset: 6,
                    .paragraphStyle: paragraphStyle
                ]
                chunk.append(NSAttributedString(string: "\(verse.number) ", attributes: numAttrs))
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
                chunk.append(attachStr)
            }

            // Everything before the verse text — number, note icon — shifts the
            // poetic line ranges, which are measured against the verse text alone.
            let prefixLength = chunk.length

            // Verse text
            let verseStart = result.length + prefixLength
            let isSearchHighlighted = isSearchHighlight(verse.number)

            let baseColor: NSColor = isSearchHighlighted ? .controlAccentColor : theme.nsTextColor
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: baseColor
            ]
            let textStr = NSMutableAttributedString(string: verse.text + entry.separator, attributes: baseAttrs)

            // Apply red-letter coloring from the authoritative data file.
            // Each range is a (start, end) pair into verse.text (end exclusive).
            if !isSearchHighlighted {
                let redRanges = RedLetterService.shared.redLetterRanges(
                    book: bookName, chapter: chapter.number, verse: verse.number)
                for range in redRanges {
                    let length = range.end - range.start
                    if length > 0 && range.start >= 0 && range.end <= verse.text.count {
                        textStr.addAttribute(.foregroundColor, value: NSColor.systemRed,
                                             range: NSRange(location: range.start, length: length))
                    }
                }
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

            // Apply bionic reading if enabled
            if bionicReadingEnabled {
                applyBionicReading(to: textStr, font: bodyFont)
            }

            chunk.append(textStr)

            // Give each poetic line its own paragraph style so a wrapped line
            // hangs under the line it continues instead of resetting to the
            // margin. The indent spaces stay in the text — removing them would
            // shift every offset highlights are keyed on — so they set the first
            // line's position and headIndent only has to match it.
            if entry.isPoetry {
                for (index, line) in entry.lines.enumerated() {
                    // The first line owns the prefix; the last owns the separator.
                    let start = index == 0 ? 0 : prefixLength + line.range.location
                    let end = index == entry.lines.count - 1
                        ? chunk.length
                        : prefixLength + line.range.upperBound
                    guard start < end else { continue }
                    let style = poeticParagraphStyle(indent: line.indent, font: bodyFont,
                                                     spacingBefore: index == 0 ? spacingBefore : 0)
                    chunk.addAttribute(.paragraphStyle, value: style,
                                       range: NSRange(location: start, length: end - start))
                }
            } else if spacingBefore > 0 {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 6
                style.paragraphSpacingBefore = spacingBefore
                chunk.addAttribute(.paragraphStyle, value: style,
                                   range: NSRange(location: 0, length: chunk.length))
            }

            let verseEnd = result.length + chunk.length
            result.append(chunk)
            boundaries.append((verse: verse.number, start: verseStart, end: verseEnd))
        }

        coordinator.verseBoundaries = boundaries
        return result
    }

    /// Indent spaces already set where a poetic line starts; headIndent repeats
    /// that position for its wrapped continuations, plus a hang so they read as
    /// continuations rather than as new lines.
    private var paragraphGap: CGFloat { 10 }
    private var headingGap: CGFloat { 18 }

    private func poeticParagraphStyle(indent: Int, font: NSFont, spacingBefore: CGFloat = 0) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacingBefore = spacingBefore
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let hang = spaceWidth * 3
        style.headIndent = CGFloat(indent) * spaceWidth * 4 + hang
        return style
    }

    private func isSearchHighlight(_ verseNumber: Int) -> Bool {
        guard let start = searchHighlightStart else { return false }
        let end = searchHighlightEnd ?? start
        return verseNumber >= start && verseNumber <= end
    }

    private var resolvedBodyFont: NSFont {
        // Falls back to system font if selectedFont is an unrecognized PostScript name.
        NSFont(name: selectedFont, size: 16) ?? NSFont.systemFont(ofSize: 16)
    }

    private func applyBionicReading(to attrStr: NSMutableAttributedString, font: NSFont) {
        // If the selected font has no bold variant, NSFontManager returns the same font
        // unchanged and bionic reading will have no visible effect.
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let nsString = attrStr.string as NSString
        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: .byWords
        ) { _, wordRange, _, _ in
            let boldLength = max(1, Int(ceil(Double(wordRange.length) / 2.0)))
            let boldRange = NSRange(location: wordRange.location, length: boldLength)
            attrStr.addAttribute(.font, value: boldFont, range: boldRange)
        }
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
