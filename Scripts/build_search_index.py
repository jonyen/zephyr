#!/usr/bin/env python3
"""Build an inverted search index from ESV Bible JSON book files.

Reads all 66 book JSON files from ESVBible/Resources/, normalizes verse text,
and produces a compact inverted index mapping words to verse references.

Output: ESVBible/Resources/search_index.json
"""

import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
RESOURCES_DIR = os.path.join(PROJECT_ROOT, "ESVBible", "Resources")

# All 66 book filenames (without .json extension), in canonical order
BOOK_FILES = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1Samuel", "2Samuel",
    "1Kings", "2Kings", "1Chronicles", "2Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Proverbs",
    "Ecclesiastes", "SongOfSolomon",
    "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
    "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
    "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts",
    "Romans", "1Corinthians", "2Corinthians",
    "Galatians", "Ephesians", "Philippians", "Colossians",
    "1Thessalonians", "2Thessalonians",
    "1Timothy", "2Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1Peter", "2Peter",
    "1John", "2John", "3John", "Jude", "Revelation",
]

# Regex to strip punctuation (keeps letters, digits, spaces, and hyphens within words)
PUNCTUATION_RE = re.compile(r"[^\w\s-]", re.UNICODE)
WHITESPACE_RE = re.compile(r"\s+")


def normalize_text(text: str) -> str:
    """Lowercase and strip punctuation from text."""
    text = text.lower()
    text = PUNCTUATION_RE.sub(" ", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    return text


def build_index() -> dict:
    """Build the inverted index from all book files."""
    index: dict[str, list] = {}
    books_processed = 0
    total_verses = 0

    for book_file in BOOK_FILES:
        filepath = os.path.join(RESOURCES_DIR, f"{book_file}.json")
        if not os.path.exists(filepath):
            print(f"WARNING: Missing file: {filepath}", file=sys.stderr)
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            book_data = json.load(f)

        book_name = book_data["name"]
        books_processed += 1

        for chapter in book_data["chapters"]:
            chapter_num = chapter["number"]
            for verse in chapter["verses"]:
                verse_num = verse["number"]
                original_text = verse["text"]
                total_verses += 1

                normalized = normalize_text(original_text)
                words = set(normalized.split())

                entry = {
                    "book": book_name,
                    "chapter": chapter_num,
                    "verse": verse_num,
                }

                for word in words:
                    # Filter out words shorter than 2 characters
                    if len(word) < 2:
                        continue
                    if word not in index:
                        index[word] = []
                    index[word].append(entry)

    print(f"Processed {books_processed} books, {total_verses} verses")
    return index


def main():
    print("Building search index...")
    index = build_index()

    # Sort keys for deterministic output
    sorted_index = dict(sorted(index.items()))

    output_path = os.path.join(RESOURCES_DIR, "search_index.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(sorted_index, f, separators=(",", ":"), ensure_ascii=False)

    word_count = len(sorted_index)
    file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"Index written to: {output_path}")
    print(f"Unique words: {word_count}")
    print(f"File size: {file_size_mb:.1f} MB")


if __name__ == "__main__":
    main()
