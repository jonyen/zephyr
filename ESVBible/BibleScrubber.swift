import SwiftUI
import AppKit

// MARK: - Floating label panel

private class LabelPanelState: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show(content: AnyView, screenOrigin: CGPoint, size: CGSize, animate: Bool = true) {
        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovable = false
            p.hidesOnDeactivate = false

            let hosting = NSHostingView(rootView: content)
            hosting.frame = NSRect(origin: .zero, size: size)
            p.contentView = hosting

            self.panel = p
            self.hostingView = hosting
        } else {
            hostingView?.rootView = content
        }

        let frame = NSRect(origin: screenOrigin, size: size)
        if animate, panel?.isVisible == true {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel?.animator().setFrame(frame, display: true)
            }
        } else {
            panel?.setFrame(frame, display: true)
        }
        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    deinit {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Label panel content

private struct LabelPanelContent: View {
    let bookRanges: [BookRange]
    let spacedFractions: [CGFloat]
    let trackInset: CGFloat
    let trackHeight: CGFloat
    let buffer: CGFloat
    let currentFraction: CGFloat
    let hoveredBookIndex: Int?
    let onHoverBook: (Int?) -> Void
    let onTapBook: (String) -> Void
    let labelScaleFn: (Int, CGFloat) -> CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 0)

            ForEach(Array(spacedFractions.enumerated()), id: \.offset) { index, fraction in
                let range = bookRanges[index]
                // Offset by buffer so labels sit in the center portion of the taller panel
                let y = buffer + trackInset + fraction * trackHeight
                let scale = labelScaleFn(index, currentFraction)

                Text(range.name)
                    .font(.system(size: 13 * scale, weight: scale > 1.3 ? .medium : .regular))
                    .foregroundStyle(scale > 1.3 ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
                .position(x: 90, y: y)
                .onHover { hovering in
                    onHoverBook(hovering ? index : nil)
                }
                .onTapGesture {
                    onTapBook(range.name)
                }
            }
        }
    }
}

// MARK: - Shared types

struct BookRange {
    let name: String
    let startFraction: CGFloat
    let endFraction: CGFloat
    var midFraction: CGFloat { (startFraction + endFraction) / 2 }
}

// MARK: - BibleScrubber

struct BibleScrubber: View {
    let currentPosition: ChapterPosition
    let onNavigate: (ChapterPosition) -> Void
    let highlightManager: HighlightManager

    @State private var isDragging = false
    @State private var isHovered = false
    @State private var hoveredBookIndex: Int? = nil
    @State private var dragFraction: CGFloat = 0
    @State private var lastNavigatedIndex: Int = -1
    @StateObject private var panelState = LabelPanelState()

    private let trackInset: CGFloat = 20
    private let scrubberWidth: CGFloat = 30

    private var bookRanges: [BookRange] {
        let total = CGFloat(BibleStore.totalChapters)
        var offset: CGFloat = 0
        return BibleStore.bookNames.map { name in
            let count = CGFloat(BibleStore.chapterCounts[name] ?? 0)
            let start = offset / total
            let end = (offset + count) / total
            offset += count
            return BookRange(name: name, startFraction: start, endFraction: end)
        }
    }

    private var currentFraction: CGFloat {
        if isDragging { return dragFraction }
        let index = BibleStore.globalChapterIndex(book: currentPosition.bookName, chapter: currentPosition.chapterNumber)
        return CGFloat(index) / CGFloat(max(1, BibleStore.totalChapters - 1))
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let trackTop = trackInset
            let trackHeight = height - trackInset * 2
            let thumbY = trackTop + currentFraction * trackHeight
            let showLabels = isHovered || isDragging

            ZStack {
                Canvas { context, size in
                    let trackX = size.width / 2
                    let trackRect = CGRect(x: trackX - 1, y: trackTop, width: 2, height: trackHeight)
                    context.fill(Path(roundedRect: trackRect, cornerRadius: 1), with: .color(.secondary.opacity(0.3)))

                    // Highlight ticks (left of track)
                    let totalChapters = CGFloat(max(1, BibleStore.totalChapters - 1))
                    for highlight in highlightManager.highlights {
                        let idx = CGFloat(BibleStore.globalChapterIndex(book: highlight.book, chapter: highlight.chapter))
                        let fraction = idx / totalChapters
                        let y = trackTop + fraction * trackHeight
                        let tickRect = CGRect(x: trackX - 8, y: y - 1.5, width: 6, height: 3)
                        context.fill(Path(roundedRect: tickRect, cornerRadius: 1), with: .color(highlight.color.scrubberColor))
                    }

                    // Bookmark markers (right of track) — diamond shape
                    for bookmark in highlightManager.bookmarks {
                        let idx = CGFloat(BibleStore.globalChapterIndex(book: bookmark.book, chapter: bookmark.chapter))
                        let fraction = idx / totalChapters
                        let y = trackTop + fraction * trackHeight
                        var diamond = Path()
                        diamond.move(to: CGPoint(x: trackX + 3, y: y - 3))
                        diamond.addLine(to: CGPoint(x: trackX + 6, y: y))
                        diamond.addLine(to: CGPoint(x: trackX + 3, y: y + 3))
                        diamond.addLine(to: CGPoint(x: trackX, y: y))
                        diamond.closeSubpath()
                        context.fill(diamond, with: .color(.accentColor))
                    }

                    // Thumb
                    let thumbWidth: CGFloat = 6
                    let thumbHeight: CGFloat = 30
                    let thumbRect = CGRect(
                        x: trackX - thumbWidth / 2,
                        y: thumbY - thumbHeight / 2,
                        width: thumbWidth,
                        height: thumbHeight
                    )
                    context.fill(Path(roundedRect: thumbRect, cornerRadius: 3), with: .color(.accentColor))
                }
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let fraction = clampedFraction(y: value.location.y, trackTop: trackTop, trackHeight: trackHeight)
                                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 1.0)) {
                                    dragFraction = fraction
                                }
                                let globalIndex = Int(round(fraction * CGFloat(BibleStore.totalChapters - 1)))
                                // Only navigate when the resolved chapter actually changes
                                if globalIndex != lastNavigatedIndex {
                                    lastNavigatedIndex = globalIndex
                                    let pos = BibleStore.chapterPosition(forGlobalIndex: globalIndex)
                                    onNavigate(pos)
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                lastNavigatedIndex = -1
                            }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovered = hovering
                        }
                        if !hovering {
                            hoveredBookIndex = nil
                        }
                    }
            }
            .frame(width: scrubberWidth, height: height)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: showLabels) { _, visible in
                            if visible {
                                showPanel(proxy: proxy, height: height, trackHeight: trackHeight)
                            } else {
                                panelState.hide()
                            }
                        }
                        .onChange(of: currentFraction) { _, _ in
                            if showLabels {
                                showPanel(proxy: proxy, height: height, trackHeight: trackHeight)
                            }
                        }
                        .onChange(of: hoveredBookIndex) { _, _ in
                            if showLabels {
                                showPanel(proxy: proxy, height: height, trackHeight: trackHeight)
                            }
                        }
                }
            )
            .onDisappear {
                panelState.hide()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private func showPanel(proxy: GeometryProxy, height: CGFloat, trackHeight: CGFloat) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }

        let windowOrigin = window.frame.origin
        let contentRect = window.contentLayoutRect

        let ranges = bookRanges
        let fractions = spacedLabelFractions(height: trackHeight)
        let fraction = currentFraction
        let hovered = hoveredBookIndex

        // Find the focused book and compute how far its label is from the thumb
        let focusedIdx: Int
        if let idx = ranges.firstIndex(where: { fraction >= $0.startFraction && fraction < $0.endFraction }) {
            focusedIdx = idx
        } else {
            focusedIdx = ranges.count - 1
        }

        // Buffer: ensure panel is tall enough for all books even when fractions go negative
        // The spacing algorithm may push first books to negative fractions when
        // 66 * minGap > trackHeight. Calculate needed overshoot from actual fractions.
        let minFraction = fractions.min() ?? 0
        let maxFraction = fractions.max() ?? 1
        let overshootAbove = minFraction < 0 ? abs(minFraction) * trackHeight : 0
        let overshootBelow = maxFraction > 1 ? (maxFraction - 1) * trackHeight : 0
        let buffer = max(300, overshootAbove + 100, overshootBelow + 100)

        // Delta to align focused label with thumb
        let thumbY = trackInset + fraction * trackHeight
        let labelY = trackInset + fractions[focusedIdx] * trackHeight
        let delta = thumbY - labelY

        let panelX = window.frame.maxX + 4
        let panelBaseY = windowOrigin.y + contentRect.origin.y
        // Panel is taller by 2*buffer; shift its origin down by buffer to center the content,
        // then apply the delta to align the focused book with the thumb
        let panelY = panelBaseY - buffer - delta
        let panelWidth: CGFloat = 180
        let panelHeight = height + buffer * 2

        let content = LabelPanelContent(
            bookRanges: ranges,
            spacedFractions: fractions,
            trackInset: trackInset,
            trackHeight: trackHeight,
            buffer: buffer,
            currentFraction: fraction,
            hoveredBookIndex: hovered,
            onHoverBook: { idx in hoveredBookIndex = idx },
            onTapBook: { name in
                let pos = ChapterPosition(bookName: name, chapterNumber: 1)
                onNavigate(pos)
            },
            labelScaleFn: labelScale
        )

        panelState.show(
            content: AnyView(content),
            screenOrigin: CGPoint(x: panelX, y: panelY),
            size: CGSize(width: panelWidth, height: panelHeight)
        )
    }

    private func clampedFraction(y: CGFloat, trackTop: CGFloat, trackHeight: CGFloat) -> CGFloat {
        min(1, max(0, (y - trackTop) / trackHeight))
    }

    private func labelScale(for index: Int, thumbFraction: CGFloat) -> CGFloat {
        if hoveredBookIndex == index { return 2.0 }
        let range = bookRanges[index]
        let distance = abs(range.midFraction - thumbFraction)
        if distance < 0.02 { return 1.6 }
        if distance < 0.05 { return 1.3 }
        if distance < 0.1 { return 1.1 }
        return 1.0
    }

    /// Space labels with a minimum gap, using forward+backward pass.
    private func spacedLabelFractions(height: CGFloat) -> [CGFloat] {
        let ranges = bookRanges
        let minGapPts: CGFloat = 20
        let minGapFraction = height > 0 ? minGapPts / height : 0

        var fractions = ranges.map { $0.midFraction }

        // Forward pass: push down overlapping labels
        for i in 1..<fractions.count {
            let minY = fractions[i - 1] + minGapFraction
            if fractions[i] < minY {
                fractions[i] = minY
            }
        }

        // Backward pass: push up if we exceeded bounds
        if let last = fractions.last, last > 1 {
            fractions[fractions.count - 1] = 1
        }
        for i in stride(from: fractions.count - 2, through: 0, by: -1) {
            let maxY = fractions[i + 1] - minGapFraction
            if fractions[i] > maxY {
                fractions[i] = maxY
            }
        }

        return fractions
    }
}
