import Foundation

/// Poetic layout for a chapter.
///
/// The scripture data encodes poetry inside the verse text itself: a newline
/// starts a new poetic line, and leading spaces (4 per level) set its indent.
/// Nothing marks where a *verse* begins a poetic line, so we infer it — a verse
/// is laid out as poetry when it carries a line break, or when it sits between
/// verses that do.
///
/// Verse text is never modified here, and separators stay one character wide,
/// so the character offsets that red-letter ranges and highlights are keyed on
/// survive untouched.
enum PoetryLayout {

    private static let spacesPerIndent = 4

    struct Line {
        let text: String    // the line with its indent spaces removed
        let range: NSRange  // the raw line, indent spaces included, within the verse text
        let indent: Int     // indent level, 0 = flush left
    }

    struct Entry {
        let verse: Verse
        let isPoetry: Bool
        let lines: [Line]
        let separator: String  // what follows this verse: "\n", " ", or "" at the end
    }

    /// A verse is poetry when it carries an internal line break.
    static func isPoetry(_ text: String) -> Bool {
        text.contains("\n")
    }

    /// Split verse text on newlines, measuring each line's indent.
    static func lines(in text: String) -> [Line] {
        var result: [Line] = []
        var location = 0
        for raw in (text as NSString).components(separatedBy: "\n") {
            let rawLine = raw as NSString
            var spaces = 0
            while spaces < rawLine.length && rawLine.character(at: spaces) == 32 { spaces += 1 }
            result.append(Line(
                text: rawLine.substring(from: spaces),
                range: NSRange(location: location, length: rawLine.length),
                indent: spaces / spacesPerIndent
            ))
            location += rawLine.length + 1 // + the newline we split on
        }
        return result
    }

    static func layout(_ verses: [Verse]) -> [Entry] {
        // The ESV omits a handful of verses (Mark 9:44, Acts 8:37, …) as later
        // manuscript additions. They carry no text, so they get no line at all.
        let present = verses.filter { !$0.text.isEmpty }
        let broken = present.map { isPoetry($0.text) }

        return present.enumerated().map { index, verse in
            let nextIsBroken = index + 1 < broken.count && broken[index + 1]
            // A lone unbroken verse surrounded by broken ones belongs to the poem.
            let poetry = broken[index] || ((index == 0 || broken[index - 1]) && nextIsBroken)

            let separator: String
            if index == present.count - 1 {
                separator = ""                              // nothing trails the last verse
            } else if broken[index] || nextIsBroken {
                separator = "\n"                            // a poem starts or ends here
            } else {
                separator = " "                             // prose keeps flowing
            }

            return Entry(verse: verse, isPoetry: poetry, lines: lines(in: verse.text), separator: separator)
        }
    }
}
