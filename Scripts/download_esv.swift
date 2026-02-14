#!/usr/bin/env swift

import Foundation

// MARK: - Models

struct BibleData: Codable {
    var books: [Book]
}

struct Book: Codable {
    let name: String
    var chapters: [Chapter]
}

struct Chapter: Codable {
    let number: Int
    var verses: [Verse]
}

struct Verse: Codable {
    let number: Int
    let text: String
}

// MARK: - ESV API Response

struct ESVResponse: Codable {
    let passages: [String]
}

// MARK: - Book Definitions

let books: [(name: String, chapters: Int)] = [
    ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36),
    ("Deuteronomy", 34), ("Joshua", 24), ("Judges", 21), ("Ruth", 4),
    ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
    ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10), ("Nehemiah", 13),
    ("Esther", 10), ("Job", 42), ("Psalms", 150), ("Proverbs", 31),
    ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66),
    ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12),
    ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1), ("Jonah", 4),
    ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3),
    ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4),
    ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21),
    ("Acts", 28), ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13),
    ("Galatians", 6), ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4),
    ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
    ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13),
    ("James", 5), ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5),
    ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22)
]

// MARK: - Verse Parsing

/// Parse the passage text from the ESV API into individual verses.
/// The text contains verse markers like [1], [2], etc.
func parseVerses(from text: String) -> [Verse] {
    let pattern = "\\[(\\d+)\\]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return []
    }

    let nsText = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

    var verses: [Verse] = []

    for (index, match) in matches.enumerated() {
        // Extract the verse number from the capture group
        let numberRange = match.range(at: 1)
        guard let verseNumber = Int(nsText.substring(with: numberRange)) else {
            continue
        }

        // Determine the text range: from end of this marker to start of next marker (or end of string)
        let markerEnd = match.range.location + match.range.length
        let textEnd: Int
        if index + 1 < matches.count {
            textEnd = matches[index + 1].range.location
        } else {
            textEnd = nsText.length
        }

        let verseText = nsText.substring(with: NSRange(location: markerEnd, length: textEnd - markerEnd))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !verseText.isEmpty {
            verses.append(Verse(number: verseNumber, text: verseText))
        }
    }

    return verses
}

// MARK: - API Fetching

/// Download a single chapter from the ESV API synchronously.
func downloadChapter(book: String, chapter: Int, apiKey: String) -> [Verse]? {
    let query = "\(book)+\(chapter)"
    var components = URLComponents(string: "https://api.esv.org/v3/passage/text/")!
    components.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "include-passage-references", value: "false"),
        URLQueryItem(name: "include-verse-numbers", value: "true"),
        URLQueryItem(name: "include-footnotes", value: "false"),
        URLQueryItem(name: "include-footnote-body", value: "false"),
        URLQueryItem(name: "include-headings", value: "false"),
        URLQueryItem(name: "include-short-copyright", value: "false"),
        URLQueryItem(name: "include-copyright", value: "false"),
        URLQueryItem(name: "indent-paragraphs", value: "0"),
        URLQueryItem(name: "indent-poetry", value: "false"),
        URLQueryItem(name: "indent-declares", value: "0"),
        URLQueryItem(name: "indent-psalm-doxology", value: "0"),
    ]

    var request = URLRequest(url: components.url!)
    request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

    let semaphore = DispatchSemaphore(value: 0)
    var resultVerses: [Verse]?
    var requestError: Error?

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }

        if let error = error {
            requestError = error
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            fputs("Error: No HTTP response for \(book) \(chapter)\n", stderr)
            return
        }

        guard httpResponse.statusCode == 200 else {
            fputs("Error: HTTP \(httpResponse.statusCode) for \(book) \(chapter)\n", stderr)
            return
        }

        guard let data = data else {
            fputs("Error: No data for \(book) \(chapter)\n", stderr)
            return
        }

        do {
            let esvResponse = try JSONDecoder().decode(ESVResponse.self, from: data)
            if let passageText = esvResponse.passages.first {
                resultVerses = parseVerses(from: passageText)
            }
        } catch {
            fputs("Error decoding response for \(book) \(chapter): \(error)\n", stderr)
        }
    }

    task.resume()
    semaphore.wait()

    if let error = requestError {
        fputs("Error downloading \(book) \(chapter): \(error.localizedDescription)\n", stderr)
    }

    return resultVerses
}

// MARK: - Main

func main() {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        fputs("Usage: download_esv.swift <API_KEY> [--test]\n", stderr)
        fputs("  API_KEY: Your ESV API key\n", stderr)
        fputs("  --test:  Only download Genesis 1 for testing\n", stderr)
        exit(1)
    }

    let apiKey = args[1]
    let testMode = args.count >= 3 && args[2] == "--test"

    if testMode {
        print("Running in TEST mode - only downloading Genesis 1")
    }

    // Determine which books/chapters to download
    let booksToDownload: [(name: String, chapters: Int)]
    if testMode {
        booksToDownload = [("Genesis", 1)]
    } else {
        booksToDownload = books
    }

    var bibleBooks: [Book] = []

    let totalChapters = booksToDownload.reduce(0) { $0 + $1.chapters }
    var completedChapters = 0

    for (bookName, chapterCount) in booksToDownload {
        var chapters: [Chapter] = []

        for chapterNum in 1...chapterCount {
            completedChapters += 1
            print("Downloading \(bookName) \(chapterNum)... (\(completedChapters)/\(totalChapters))")

            guard let verses = downloadChapter(book: bookName, chapter: chapterNum, apiKey: apiKey) else {
                fputs("Failed to download \(bookName) \(chapterNum). Aborting.\n", stderr)
                exit(1)
            }

            chapters.append(Chapter(number: chapterNum, verses: verses))

            // Respect rate limits
            if completedChapters < totalChapters {
                Thread.sleep(forTimeInterval: 0.3)
            }
        }

        bibleBooks.append(Book(name: bookName, chapters: chapters))
        print("Completed \(bookName)")
    }

    let bibleData = BibleData(books: bibleBooks)

    // Determine output path relative to the script location
    let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
    let outputURL = scriptDir
        .deletingLastPathComponent()
        .appendingPathComponent("ESVBible")
        .appendingPathComponent("Resources")
        .appendingPathComponent("bible.json")

    // Ensure the output directory exists
    let outputDir = outputURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bibleData)
        try data.write(to: outputURL)
        print("\nBible data written to \(outputURL.path)")
        print("Total books: \(bibleBooks.count)")
        let totalVerses = bibleBooks.flatMap(\.chapters).flatMap(\.verses).count
        print("Total verses: \(totalVerses)")
    } catch {
        fputs("Error writing output: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
