#!/usr/bin/env swift

import Foundation

// MARK: - Models
// These models match the structure in ESVBible/Models/BibleModels.swift

struct Bible: Codable {
    var books: [Book]
}

struct Book: Codable, Equatable {
    let name: String
    var chapters: [Chapter]
    
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.name == rhs.name
    }
}

struct Chapter: Codable, Comparable {
    let number: Int
    var verses: [Verse]
    
    static func < (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.number < rhs.number
    }
    
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.number == rhs.number
    }
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

let CANONICAL_BOOKS: [(name: String, chapters: Int)] = [
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

func parseVerses(from text: String) -> [Verse] {
    let cleanedText = text.replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression)
    let pattern = "\\[(\\d+)\\]([^\\[]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return []
    }

    let nsText = cleanedText as NSString
    let matches = regex.matches(in: cleanedText, range: NSRange(location: 0, length: nsText.length))

    return matches.compactMap { match in
        guard match.numberOfRanges == 3,
              let verseNumber = Int(nsText.substring(with: match.range(at: 1)))
        else { return nil }

        let verseText = nsText.substring(with: match.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return verseText.isEmpty ? nil : Verse(number: verseNumber, text: verseText)
    }
}

// MARK: - API Fetching

func downloadChapter(book: String, chapter: Int, apiKey: String) -> [Verse]? {
    let query = "\(book)+\(chapter)"
    var components = URLComponents(string: "https://api.esv.org/v3/passage/text/")!
    components.queryItems = [
        "q": query, "include-passage-references": "false", "include-verse-numbers": "true",
        "include-footnotes": "false", "include-footnote-body": "false", "include-headings": "false",
        "include-short-copyright": "false", "include-copyright": "false", "indent-paragraphs": "0",
        "indent-poetry": "false", "indent-declares": "0", "indent-psalm-doxology": "0",
        "wrapping-div": "false"
    ].map { URLQueryItem(name: $0.key, value: $0.value) }

    var request = URLRequest(url: components.url!)
    request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

    var retries = 3
    while retries > 0 {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[Verse], Error>?
        var shouldRetry = false
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                result = .failure(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"]))
                return
            }

            if httpResponse.statusCode == 429 {
                shouldRetry = true
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                fputs("Rate limited. ", stderr)

                let pattern = "Try again in (\\d+) seconds"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: body, range: NSRange(location: 0, length: body.utf16.count)),
                   match.numberOfRanges == 2,
                   let range = Range(match.range(at: 1), in: body),
                   let seconds = Int(body[range])
                {
                    fputs("Waiting for \(seconds + 1) seconds as requested by API.\n", stderr)
                    Thread.sleep(forTimeInterval: TimeInterval(seconds + 1))
                } else {
                    fputs("Waiting for 60 seconds before retrying.\n", stderr)
                    Thread.sleep(forTimeInterval: 60)
                }
                return // End this request, the outer loop will retry
            }

            guard httpResponse.statusCode == 200 else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                result = .failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode): \(body)"]))
                return
            }

            guard let data = data else {
                result = .failure(NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            do {
                let esvResponse = try JSONDecoder().decode(ESVResponse.self, from: data)
                let verses = esvResponse.passages.first.map(parseVerses) ?? []
                result = .success(verses)
            } catch {
                result = .failure(error)
            }
        }.resume()

        semaphore.wait()
        
        if shouldRetry {
            retries -= 1
            fputs("Retrying... (\(retries) attempts left)\n", stderr)
            continue
        }

        switch result {
        case .success(let verses):
            return verses
        case .failure(let error):
            fputs("Error downloading \(book) \(chapter): \(error.localizedDescription)\n", stderr)
            return nil
        case .none:
            // This case should not be reached if shouldRetry is handled correctly
            fputs("Error: Unknown issue downloading \(book) \(chapter).\n", stderr)
            return nil
        }
    }

    fputs("Error: Exceeded max retries for \(book) \(chapter).\n", stderr)
    return nil
}

// MARK: - File I/O & Progress

func getBibleOutputPath() -> URL {
    let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
    return scriptDir
        .deletingLastPathComponent()
        .appendingPathComponent("ESVBible")
        .appendingPathComponent("Resources")
        .appendingPathComponent("bible.json")
}

func loadExistingBible(from url: URL) -> Bible {
    guard let data = try? Data(contentsOf: url),
          var bible = try? JSONDecoder().decode(Bible.self, from: data)
    else {
        print("No existing bible.json found, or it's corrupted. Starting fresh.")
        return Bible(books: [])
    }
    // Ensure chapters within each book are sorted for consistent merging
    for i in 0..<bible.books.count {
        bible.books[i].chapters.sort()
    }
    print("Loaded existing bible.json with \(bible.books.count) books.")
    return bible
}

func saveBible(_ bible: Bible, to url: URL) {
    do {
        let encoder = JSONEncoder()
        if #available(macOS 10.13, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = .prettyPrinted
        }
        
        let data = try encoder.encode(bible)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    } catch {
        fputs("Fatal Error: Could not write to output file \(url.path): \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}


// MARK: - Main

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        fputs("Usage: \(args[0]) <API_KEY> [--test]\n", stderr)
        exit(1)
    }
    let apiKey = args[1]
    let testMode = args.contains("--test")

    let outputURL = getBibleOutputPath()
    var bible = loadExistingBible(from: outputURL)
    var existingChapters = Dictionary(bible.books.map { ($0.name, Set($0.chapters.map { $0.number })) }) { $1 }

    let booksToDownload = testMode ? [CANONICAL_BOOKS[0]] : CANONICAL_BOOKS
    let totalChaptersToProcess = booksToDownload.reduce(0) { $0 + $1.chapters }
    var completedChapters = 0
    
    let startTime = Date()
    print(testMode ? "Running in TEST mode - only processing Genesis" : "Starting ESV Bible download/update...")

    for (bookName, chapterCount) in booksToDownload {
        var bookChapters: [Chapter] = []
        let chaptersToDownload = (1...chapterCount).filter { !(existingChapters[bookName]?.contains($0) ?? false) }

        if chaptersToDownload.isEmpty {
            completedChapters += chapterCount
            print("[\(Int(Double(completedChapters * 100) / Double(totalChaptersToProcess)))%] Book '\(bookName)' is already complete. Skipping.")
            continue
        } else {
             completedChapters += (chapterCount - chaptersToDownload.count)
        }

        print("Processing book '\(bookName)'...")
        
        for chapterNum in chaptersToDownload {
            completedChapters += 1
            let progress = Double(completedChapters * 100) / Double(totalChaptersToProcess)
            print(String(format: "[%.0f%%] Downloading %@ %d...", progress, bookName, chapterNum))

            guard let verses = downloadChapter(book: bookName, chapter: chapterNum, apiKey: apiKey) else {
                fputs("Failed to download \(bookName) \(chapterNum). Aborting and saving progress.\n", stderr)
                saveBible(bible, to: outputURL)
                exit(1)
            }
            
            if verses.isEmpty {
                 fputs("Warning: No verses found for \(bookName) \(chapterNum). It will be skipped.\n", stderr)
                 continue
            }

            bookChapters.append(Chapter(number: chapterNum, verses: verses))

            // Respect rate limits
            if completedChapters < totalChaptersToProcess {
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        
        // Merge new chapters with existing ones
        if var existingBook = bible.books.first(where: { $0.name == bookName }) {
            existingBook.chapters.append(contentsOf: bookChapters)
            existingBook.chapters.sort() // Keep chapters in order
            if let index = bible.books.firstIndex(of: existingBook) {
                bible.books[index] = existingBook
            }
        } else {
            bible.books.append(Book(name: bookName, chapters: bookChapters))
        }

        // Update the lookup for the next run
        existingChapters[bookName, default: Set()].formUnion(bookChapters.map { $0.number })
        
        // Save progress after each book is processed
        print("Finished processing book '\(bookName)'. Saving progress...")
        saveBible(bible, to: outputURL)
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    
    print("\n--------------------")
    print("Download Complete!")
    print("--------------------")
    print("Bible data is up-to-date in: \(outputURL.path)")
    print("Total books: \(bible.books.count)")
    let totalVerses = bible.books.flatMap(\.chapters).flatMap(\.verses).count
    print("Total verses: \(totalVerses)")
    print("Total time for this run: \(String(format: "%.2f", duration)) seconds")
}

main()
