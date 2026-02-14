import SwiftUI

struct HistorySidebarView: View {
    let entries: [HistoryEntry]
    let onSelect: (HistoryEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !entries.isEmpty {
                    Button("Clear") {
                        onClear()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if entries.isEmpty {
                Text("No history yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                List(entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.reference)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
    }
}
