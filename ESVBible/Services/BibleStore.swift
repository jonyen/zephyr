import Foundation

@Observable
class BibleStore {
    // A cache to hold books that have already been loaded from disk.
    private var bookCache: [String: Book] = [:]
    
    // A static list of all book names in canonical order.
    static let bookNames: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel",
        "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
        "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel",
        "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
        "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians",
        "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
        "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
        "1 John", "2 John", "3 John", "Jude", "Revelation"
    ]
    
    private let abbreviations: [String: String]

    init() {
        // The initializer is now much simpler. It just builds the abbreviations map.
        self.abbreviations = Self.buildAbbreviations()
    }

    /// Test-only initializer that accepts a pre-built Bible and populates the book cache.
    init(bible: Bible) {
        self.abbreviations = Self.buildAbbreviations()
        for book in bible.books {
            self.bookCache[book.name] = book
        }
    }
    
    /// Loads a single book from its JSON file.
    /// - Parameter bookName: The canonical name of the book (e.g., "Genesis").
    /// - Returns: A `Book` object or `nil` if the file can't be found or parsed.
    func loadBook(named bookName: String) -> Book? {
        // 1. Return from cache if the book has already been loaded.
        if let cachedBook = bookCache[bookName] {
            return cachedBook
        }
        
        // 2. Construct the filename (e.g., "Song of Solomon" -> "SongOfSolomon.json")
        let fileNameOverrides = ["Psalms": "Psalm"]
        let fileName = fileNameOverrides[bookName] ?? bookName
            .components(separatedBy: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()

        // 3. Find the file in the app's bundle and decode it.
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            // This would happen if a book's JSON file is missing from the project.
            print("Error: Could not load or parse \(fileName).json from the app bundle.")
            return nil
        }
        
        // 4. Add the newly loaded book to the cache for next time.
        bookCache[bookName] = book
        return book
    }

    /// Finds a book by its full name or abbreviation and loads it.
    func findBook(_ query: String) -> Book? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Try to find a canonical name for the given query.
        let canonicalName: String?
        if let name = Self.bookNames.first(where: { $0.lowercased() == normalizedQuery }) {
            // Direct match (e.g., "genesis" -> "Genesis")
            canonicalName = name
        } else if let fullName = abbreviations[normalizedQuery] {
            // Abbreviation match (e.g., "gen" -> "Genesis")
            canonicalName = fullName
        } else {
            // Prefix match (e.g., "gen" -> "Genesis")
            canonicalName = Self.bookNames.first { $0.lowercased().hasPrefix(normalizedQuery) }
        }
        
        // If we found a valid book name, try to load it.
        if let name = canonicalName {
            return loadBook(named: name)
        }
        
        return nil
    }

    func getChapter(bookName: String, chapter: Int) -> Chapter? {
        guard let book = findBook(bookName) else { return nil }
        return book.chapters.first(where: { $0.number == chapter })
    }

    func getVerses(bookName: String, chapter: Int, start: Int, end: Int) -> [Verse] {
        guard let ch = getChapter(bookName: bookName, chapter: chapter) else { return [] }
        return ch.verses.filter { $0.number >= start && $0.number <= end }
    }
    
    /// Returns all abbreviations that map to the given canonical book name.
    static func abbreviations(for bookName: String) -> [String] {
        return buildAbbreviations()
            .filter { $0.value == bookName }
            .map { $0.key }
    }

    private static func buildAbbreviations() -> [String: String] {
        return [
            "gen": "Genesis", "ex": "Exodus", "exod": "Exodus",
            "lev": "Leviticus", "num": "Numbers", "deut": "Deuteronomy",
            "josh": "Joshua", "judg": "Judges", "rth": "Ruth",
            "1 sam": "1 Samuel", "2 sam": "2 Samuel",
            "1 kgs": "1 Kings", "2 kgs": "2 Kings",
            "1 chr": "1 Chronicles", "2 chr": "2 Chronicles",
            "neh": "Nehemiah", "est": "Esther",
            "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms",
            "prov": "Proverbs", "eccl": "Ecclesiastes",
            "song": "Song of Solomon", "sos": "Song of Solomon",
            "isa": "Isaiah", "jer": "Jeremiah", "lam": "Lamentations",
            "ezek": "Ezekiel", "dan": "Daniel", "hos": "Hosea",
            "ob": "Obadiah", "mic": "Micah", "nah": "Nahum",
            "hab": "Habakkuk", "zeph": "Zephaniah", "hag": "Haggai",
            "zech": "Zechariah", "mal": "Malachi",
            "matt": "Matthew", "mk": "Mark", "lk": "Luke", "jn": "John",
            "rom": "Romans", "1 cor": "1 Corinthians", "2 cor": "2 Corinthians",
            "gal": "Galatians", "eph": "Ephesians", "phil": "Philippians",
            "col": "Colossians", "1 thess": "1 Thessalonians",
            "2 thess": "2 Thessalonians", "1 tim": "1 Timothy",
            "2 tim": "2 Timothy", "tit": "Titus", "phm": "Philemon",
            "heb": "Hebrews", "jas": "James", "1 pet": "1 Peter",
            "2 pet": "2 Peter", "1 jn": "1 John", "2 jn": "2 John",
            "3 jn": "3 John", "rev": "Revelation"
        ]
    }
}
