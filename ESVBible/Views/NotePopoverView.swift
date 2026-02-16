import SwiftUI

struct NotePopoverView: View {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let existingNote: Note?
    let onSave: (Data) -> Void
    let onDelete: (() -> Void)?

    @State private var rtfData: Data
    @Environment(\.dismiss) private var dismiss

    init(book: String, chapter: Int, verseStart: Int, verseEnd: Int, existingNote: Note?, onSave: @escaping (Data) -> Void, onDelete: (() -> Void)?) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
        self.existingNote = existingNote
        self.onSave = onSave
        self.onDelete = onDelete
        self._rtfData = State(initialValue: existingNote?.rtfData ?? Data())
    }

    private var referenceText: String {
        if verseStart == verseEnd {
            return "\(book) \(chapter):\(verseStart)"
        }
        return "\(book) \(chapter):\(verseStart)-\(verseEnd)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(referenceText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()

                HStack(spacing: 4) {
                    Button {
                        NSApp.sendAction(NSSelectorFromString("toggleBoldface:"), to: nil, from: nil)
                    } label: {
                        Image(systemName: "bold")
                    }
                    .buttonStyle(.plain)
                    .help("Bold")

                    Button {
                        NSApp.sendAction(NSSelectorFromString("toggleItalics:"), to: nil, from: nil)
                    } label: {
                        Image(systemName: "italic")
                    }
                    .buttonStyle(.plain)
                    .help("Italic")

                    Button {
                        NSApp.sendAction(#selector(NSText.underline(_:)), to: nil, from: nil)
                    } label: {
                        Image(systemName: "underline")
                    }
                    .buttonStyle(.plain)
                    .help("Underline")
                }
            }

            NoteEditorView(rtfData: $rtfData)
                .frame(minHeight: 100, maxHeight: 200)

            HStack {
                if onDelete != nil {
                    Button("Delete", role: .destructive) {
                        onDelete?()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Save") {
                    onSave(rtfData)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(rtfData.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
