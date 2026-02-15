import SwiftUI
import AppKit

// MARK: - Floating label panel

private class LabelPanelState: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show(content: AnyView, screenOrigin: CGPoint, height: CGFloat) {
        let panelWidth: CGFloat = 140

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
            hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
            p.contentView = hosting

            self.panel = p
            self.hostingView = hosting
        } else {
            hostingView?.rootView = content
        }

        let frame = NSRect(x: screenOrigin.x, y: screenOrigin.y, width: panelWidth, height: height)
        panel?.setFrame(frame, display: true)
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
    let trackInset: CGFloat
    let currentFraction: CGFloat
    let hoveredBookIndex: Int?
    let onHoverBook: (Int?) -> Void
    let onTapBook: (String) -> Void
    let labelScaleFn: (Int, CGFloat) -> CGFloat

    var body: some View {
        VStack(spacing: 1) {
            Spacer().frame(height: trackInset)

            ForEach(Array(bookRanges.enumerated()), id: \.offset) { index, range in
                let scale = labelScaleFn(index, currentFraction)

                Text(range.name)
                    .font(.system(size: 8 * scale, weight: scale > 1.3 ? .medium : .regular))
                    .foregroundStyle(scale > 1.3 ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: Capsule())
                    .contentShape(Capsule())
                    .onHover { hovering in
                        onHoverBook(hovering ? index : nil)
                    }
                    .onTapGesture {
                        onTapBook(range.name)
                    }
            }

            Spacer().frame(height: trackInset)
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

    @State private var isDragging = false
    @State private var isHovered = false
    @State private var hoveredBookIndex: Int? = nil
    @State private var dragFraction: CGFloat = 0
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

                    let thumbSize: CGFloat = 8
                    let thumbRect = CGRect(
                        x: trackX - thumbSize / 2,
                        y: thumbY - thumbSize / 2,
                        width: thumbSize,
                        height: thumbSize
                    )
                    context.fill(Path(ellipseIn: thumbRect), with: .color(.accentColor))
                }
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let fraction = clampedFraction(y: value.location.y, trackTop: trackTop, trackHeight: trackHeight)
                                dragFraction = fraction
                                let globalIndex = Int(round(fraction * CGFloat(BibleStore.totalChapters - 1)))
                                let pos = BibleStore.chapterPosition(forGlobalIndex: globalIndex)
                                onNavigate(pos)
                            }
                            .onEnded { _ in
                                isDragging = false
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
                                showPanel(proxy: proxy, height: height)
                            } else {
                                panelState.hide()
                            }
                        }
                        .onChange(of: currentFraction) { _, _ in
                            if showLabels {
                                showPanel(proxy: proxy, height: height)
                            }
                        }
                        .onChange(of: hoveredBookIndex) { _, _ in
                            if showLabels {
                                showPanel(proxy: proxy, height: height)
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

    private func showPanel(proxy: GeometryProxy, height: CGFloat) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }

        let windowOrigin = window.frame.origin
        let contentRect = window.contentLayoutRect

        let panelX = window.frame.maxX + 4
        let panelTop = windowOrigin.y + contentRect.origin.y

        let ranges = bookRanges
        let fraction = currentFraction
        let hovered = hoveredBookIndex

        let content = LabelPanelContent(
            bookRanges: ranges,
            trackInset: trackInset,
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
            screenOrigin: CGPoint(x: panelX, y: panelTop),
            height: height
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
}
