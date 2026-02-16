import SwiftUI
import AppKit

struct NoteEditorView: NSViewRepresentable {
    @Binding var rtfData: Data
    var isEditable: Bool = true

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Load initial content
        if !rtfData.isEmpty {
            if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrStr)
            }
        }

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard !context.coordinator.isEditing else { return }
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if !rtfData.isEmpty {
            if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrStr)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rtfData: $rtfData)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var rtfData: Binding<Data>
        var isEditing = false

        init(rtfData: Binding<Data>) {
            self.rtfData = rtfData
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }
            isEditing = true
            let range = NSRange(location: 0, length: textStorage.length)
            if let data = try? textStorage.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                rtfData.wrappedValue = data
            }
            isEditing = false
        }
    }
}
