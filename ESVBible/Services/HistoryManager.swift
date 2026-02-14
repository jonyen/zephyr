import Foundation

@Observable
class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    private let storageURL: URL
    private let maxEntries = 100

    init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("Spark", isDirectory: true)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.storageURL = appDir.appendingPathComponent("history.json")
        }
        load()
    }

    func addEntry(for ref: BibleReference) {
        let entry = HistoryEntry(
            reference: ref.displayString,
            bookName: ref.book,
            chapter: ref.chapter,
            verseStart: ref.verseStart,
            verseEnd: ref.verseEnd,
            timestamp: Date()
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func clearHistory() {
        entries.removeAll()
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }
}
