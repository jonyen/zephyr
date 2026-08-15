import SwiftUI

struct KeybindingsSettingsView: View {
    @AppStorage("keybinding_search") private var searchKey = "k"
    @AppStorage("keybinding_prevChapter") private var prevChapterKey = "["
    @AppStorage("keybinding_nextChapter") private var nextChapterKey = "]"
    @AppStorage("keybinding_history") private var historyKey = "y"
    @AppStorage("keybinding_notes") private var notesKey = "n"
    @AppStorage("keybinding_bookmark") private var bookmarkKey = "b"

    var body: some View {
        Form {
            Section("Search") {
                KeybindingRow(action: "Search for Passage", modifierLabel: "⌘", key: $searchKey, defaultKey: "k")
            }

            Section("Navigation") {
                KeybindingRow(action: "Previous Chapter", modifierLabel: "⌘", key: $prevChapterKey, defaultKey: "[")
                KeybindingRow(action: "Next Chapter", modifierLabel: "⌘", key: $nextChapterKey, defaultKey: "]")
            }

            Section("Panels") {
                KeybindingRow(action: "Toggle History", modifierLabel: "⌘", key: $historyKey, defaultKey: "y")
                KeybindingRow(action: "Toggle Notes", modifierLabel: "⇧⌘", key: $notesKey, defaultKey: "n")
                KeybindingRow(action: "Toggle Bookmark", modifierLabel: "⌘", key: $bookmarkKey, defaultKey: "b")
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(.vertical, 8)
    }
}

private struct KeybindingRow: View {
    let action: String
    let modifierLabel: String
    @Binding var key: String
    let defaultKey: String

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            if key != defaultKey {
                Button("Reset") { key = defaultKey }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                Text(isRecording ? "Type a key…" : "\(modifierLabel)\(key.uppercased())")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    }
                    .animation(.easeInOut(duration: 0.15), value: isRecording)
            }
            .buttonStyle(.plain)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels
                stopRecording()
                return nil
            }
            guard let chars = event.charactersIgnoringModifiers,
                  let first = chars.first,
                  isAcceptable(first) else { return event }
            key = String(first).lowercased()
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func isAcceptable(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || "[].,;'/\\=-`".contains(char)
    }
}

#Preview {
    KeybindingsSettingsView()
}
