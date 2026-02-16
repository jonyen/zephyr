import SwiftUI

struct NotesSidebarView: View {
    let notes: [Note]
    let onSelect: (Note) -> Void
    let onDelete: (UUID) -> Void

    private var groupedNotes: [(String, [Note])] {
        let grouped = Dictionary(grouping: notes) { "\($0.book) \($0.chapter)" }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.verseStart < $1.verseStart }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(notes.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                List {
                    ForEach(groupedNotes, id: \.0) { group, groupNotes in
                        Section(group) {
                            ForEach(groupNotes) { note in
                                Button {
                                    onSelect(note)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(noteReference(note))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(notePlainText(note))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                        Text(note.updatedAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        onDelete(note.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func noteReference(_ note: Note) -> String {
        if note.verseStart == note.verseEnd {
            return "\(note.book) \(note.chapter):\(note.verseStart)"
        }
        return "\(note.book) \(note.chapter):\(note.verseStart)-\(note.verseEnd)"
    }

    private func notePlainText(_ note: Note) -> String {
        guard let attrStr = NSAttributedString(rtf: note.rtfData, documentAttributes: nil) else {
            return ""
        }
        return attrStr.string
    }
}
