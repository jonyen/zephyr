#!/usr/bin/env python3
"""Record which verses begin a paragraph, for every chapter of the Bible.

The scripture data is stored verse by verse and carries no paragraph
information, so the readers render a chapter as one unbroken block. The ESV API
knows where the paragraphs are; this asks it, and writes out the verse indices.

Only indices are written — no scripture text.

Usage:
    doppler run -p personal -c prd_bible -- \
        python3 Scripts/generate_paragraph_starts.py --out <path>

The run is resumable: chapters already present in the output file are skipped,
so an interrupted run picks up where it left off.
"""

import argparse
import sys
from pathlib import Path

import requests

from esv_api import (RateLimiter, Throttled, api_key_or_exit, books_from, fetch_passage,
                     load_json, passage_reference, select_books, write_json)
from esv_paragraphs import parse_paragraph_starts, verse_markers

API_URL = "https://api.esv.org/v3/passage/text/"

# Strip everything that is not the passage itself, so the only structure left
# in the response is the paragraph and poetry layout we are here to read.
PASSAGE_PARAMS = {
    "include-passage-references": "false",
    "include-verse-numbers": "true",
    "include-first-verse-numbers": "true",
    "include-footnotes": "false",
    "include-headings": "false",
    "include-short-copyright": "false",
    "indent-paragraphs": "2",
    "indent-poetry": "true",
    "indent-poetry-lines": "4",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text-dir", default="ESVBible/Resources",
                        help="where the per-book scripture JSON lives")
    parser.add_argument("--out", default="paragraph_starts.json",
                        help="output file; existing entries are kept and skipped")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="minimum seconds between requests (default: 1.0)")
    parser.add_argument("--books", nargs="*", help="limit to these book names (default: all)")
    parser.add_argument("--max-wait", type=float, default=300,
                        help="give up rather than sleep longer than this on a throttle")
    args = parser.parse_args()

    api_key = api_key_or_exit()
    out_path = Path(args.out)
    result = load_json(out_path)

    books = select_books(books_from(args.text_dir), args.books)
    if not books:
        raise SystemExit(f"No book data under {args.text_dir}. Run Scripts/fetch-text.sh first.")

    limiter = RateLimiter(args.delay)
    session = requests.Session()
    fetched = skipped = 0

    try:
        for name, chapter_numbers, last_verse in books:
            book_result = result.setdefault(name, {})
            todo = [n for n in chapter_numbers if str(n) not in book_result]
            if not todo:
                skipped += len(chapter_numbers)
                print(f"{name}: already complete")
                continue

            print(f"{name}: {len(todo)} chapters to fetch")
            for number in todo:
                reference = passage_reference(name, number, len(chapter_numbers))
                passage, payload = fetch_passage(session, API_URL, api_key, reference,
                                                 PASSAGE_PARAMS, limiter, args.max_wait)

                # Check we were handed the whole chapter before trusting its
                # paragraphs. A reference the API reads differently than we meant
                # comes back short rather than empty, so length is the tell.
                markers = verse_markers(passage)
                expected = last_verse[number]
                if not markers or max(markers) != expected:
                    raise RuntimeError(
                        f"{reference}: expected the chapter to run to verse {expected}, "
                        f"got {max(markers) if markers else 'none'} "
                        f"(API read the reference as {payload.get('canonical')!r})"
                    )

                book_result[str(number)] = parse_paragraph_starts(passage)
                fetched += 1

            # Write after each book so an interrupted run keeps its progress.
            write_json(out_path, result)
    except Throttled as throttle:
        write_json(out_path, result)
        print(f"\n{fetched} chapters fetched before the API throttled us.", file=sys.stderr)
        print(f"Wait {throttle.seconds / 60:.0f} minutes and run again — it resumes where it "
              f"stopped.", file=sys.stderr)
        raise SystemExit(1)

    write_json(out_path, result)
    print(f"\n{fetched} chapters fetched, {skipped} already present -> {out_path}")


if __name__ == "__main__":
    main()
