#!/usr/bin/env python3
"""Record the ESV's section headings, and the psalm superscriptions, per chapter.

The scripture data is stored verse by verse and carries neither, so the readers
show a chapter with no editorial structure and Psalms with no superscription.

Unlike paragraph_starts.json this output contains ESV *text*, so it belongs in
the private text repository rather than here.

Usage:
    doppler run -p personal -c prd_bible -- \
        python3 Scripts/generate_headings.py --out <path>

The run is resumable: chapters already present in the output file are skipped.
"""

import argparse
import sys
from pathlib import Path

import requests

from esv_api import (RateLimiter, Throttled, api_key_or_exit, books_from, fetch_passage,
                     load_json, passage_reference, select_books, write_json)
from esv_headings import parse_headings, verse_numbers

API_URL = "https://api.esv.org/v3/passage/html/"

# The HTML endpoint tags headings and psalm superscriptions distinctly, which
# the text endpoint does not — there both render as blocks with no verse number.
PASSAGE_PARAMS = {
    "include-passage-references": "false",
    "include-footnotes": "false",
    "include-headings": "true",
    "include-short-copyright": "false",
    "include-audio-link": "false",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text-dir", default="ESVBible/Resources",
                        help="where the per-book scripture JSON lives")
    parser.add_argument("--out", default="headings.json",
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

                # A reference the API reads differently than we meant comes back
                # short rather than empty, so check the chapter arrived whole.
                numbers = verse_numbers(passage)
                expected = last_verse[number]
                if not numbers or max(numbers) != expected:
                    raise RuntimeError(
                        f"{reference}: expected the chapter to run to verse {expected}, "
                        f"got {max(numbers) if numbers else 'none'} "
                        f"(API read the reference as {payload.get('canonical')!r})"
                    )

                parsed = parse_headings(passage)
                entry = {"headings": parsed["headings"]}
                if parsed["title"]:
                    entry["title"] = parsed["title"]
                book_result[str(number)] = entry
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
