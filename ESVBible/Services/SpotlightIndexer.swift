import CoreSpotlight
import UniformTypeIdentifiers

struct SpotlightIndexer {
    private static let indexedVersionKey = "SpotlightIndexVersion"
    private static let currentVersion = 7

    /// Index all Bible chapters and verses in Core Spotlight if not already done.
    static func indexIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: indexedVersionKey)
        guard stored < currentVersion else { return }

        Task.detached(priority: .utility) {
            await reindex()
            await MainActor.run {
                UserDefaults.standard.set(currentVersion, forKey: indexedVersionKey)
            }
        }
    }

    /// Delete existing items and re-index everything.
    static func reindex() async {
        let index = CSSearchableIndex.default()
        try? await index.deleteAllSearchableItems()

        let store = BibleStore()
        var items: [CSSearchableItem] = []

        for bookName in BibleStore.bookNames {
            guard let book = store.loadBook(named: bookName) else { continue }

            let abbrevs = BibleStore.abbreviations(for: bookName)

            for chapter in book.chapters {
                let chapterID = "spark-bible:\(bookName):\(chapter.number)"
                let chapterTitle = "\(bookName) \(chapter.number)"

                let preview = chapter.verses
                    .prefix(3)
                    .map { "\($0.number) \($0.text)" }
                    .joined(separator: " ")
                let trimmedPreview = String(preview.prefix(200))

                // Build searchable text with all name variants
                let chapterAltNames = abbrevs.flatMap { abbr in
                    ["\(abbr) \(chapter.number)", "\(abbr.capitalized) \(chapter.number)"]
                }

                let chapterAttrs = CSSearchableItemAttributeSet(contentType: .text)
                chapterAttrs.title = chapterTitle
                chapterAttrs.contentDescription = trimmedPreview
                chapterAttrs.textContent = ([chapterTitle] + chapterAltNames).joined(separator: "\n")

                items.append(CSSearchableItem(
                    uniqueIdentifier: chapterID,
                    domainIdentifier: "com.spark.bible",
                    attributeSet: chapterAttrs
                ))

                // Index each verse
                for verse in chapter.verses {
                    let verseID = "spark-bible:\(bookName):\(chapter.number):\(verse.number)"
                    let verseTitle = "\(bookName) \(chapter.number):\(verse.number)"
                    let verseRef = "\(chapter.number):\(verse.number)"

                    let verseAltNames = abbrevs.flatMap { abbr in
                        ["\(abbr) \(verseRef)", "\(abbr.capitalized) \(verseRef)"]
                    }

                    let verseAttrs = CSSearchableItemAttributeSet(contentType: .text)
                    verseAttrs.title = verseTitle
                    verseAttrs.contentDescription = verse.text
                    verseAttrs.textContent = ([verseTitle] + verseAltNames).joined(separator: "\n")

                    items.append(CSSearchableItem(
                        uniqueIdentifier: verseID,
                        domainIdentifier: "com.spark.bible",
                        attributeSet: verseAttrs
                    ))
                }
            }

            // Index in batches to avoid memory pressure
            if items.count >= 5000 {
                try? await index.indexSearchableItems(items)
                items.removeAll(keepingCapacity: true)
            }
        }

        if !items.isEmpty {
            try? await index.indexSearchableItems(items)
        }
    }

    /// Parse a Spotlight identifier back into components.
    /// Format: "spark-bible:{Book}:{Chapter}" or "spark-bible:{Book}:{Chapter}:{Verse}"
    static func parseIdentifier(_ identifier: String) -> (book: String, chapter: Int, verse: Int?)? {
        let parts = identifier.split(separator: ":", maxSplits: 3).map(String.init)
        guard parts.count >= 3, parts[0] == "spark-bible" else { return nil }

        let book = parts[1]
        guard let chapter = Int(parts[2]) else { return nil }
        let verse = parts.count > 3 ? Int(parts[3]) : nil
        return (book, chapter, verse)
    }
}
