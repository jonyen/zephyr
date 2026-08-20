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
import json
import os
import sys
import time
from pathlib import Path

import requests

from esv_paragraphs import parse_paragraph_starts, passage_reference, verse_markers

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

MAX_ATTEMPTS = 5


class RateLimiter:
    """Keep at least `delay` seconds between the starts of two requests."""

    def __init__(self, delay):
        self.delay = delay
        self._last = 0.0

    def wait(self):
        gap = self.delay - (time.monotonic() - self._last)
        if gap > 0:
            time.sleep(gap)
        self._last = time.monotonic()


def fetch_passage(session, api_key, reference, limiter):
    """Fetch one chapter, backing off when the API asks us to."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        limiter.wait()
        response = session.get(
            API_URL,
            params={"q": reference, **PASSAGE_PARAMS},
            headers={"Authorization": f"Token {api_key}"},
            timeout=30,
        )
        if response.status_code == 200:
            return response.json()

        retryable = response.status_code == 429 or response.status_code >= 500
        if not retryable or attempt == MAX_ATTEMPTS:
            raise RuntimeError(
                f"{reference}: HTTP {response.status_code} {response.text[:200]}"
            )

        # Honor Retry-After when the API sends one; otherwise back off.
        pause = float(response.headers.get("Retry-After") or 2 ** attempt)
        print(f"  {reference}: HTTP {response.status_code}, retrying in {pause:.0f}s",
              file=sys.stderr)
        time.sleep(pause)


def chapters_from(text_dir):
    """Book name and chapter numbers, read from the scripture data we ship."""
    books = []
    for path in sorted(Path(text_dir).glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "chapters" not in data or "name" not in data:
            continue  # red_letter_ranges.json and friends
        # The last verse the chapter actually has text for. The ESV omits a
        # few verses as later additions, and the API omits them too.
        last_verse = {
            c["number"]: max((v["number"] for v in c["verses"] if v["text"]), default=0)
            for c in data["chapters"]
        }
        books.append((data["name"], [c["number"] for c in data["chapters"]], last_verse))
    return books


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text-dir", default="ESVBible/Resources",
                        help="where the per-book scripture JSON lives")
    parser.add_argument("--out", default="paragraph_starts.json",
                        help="output file; existing entries are kept and skipped")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="minimum seconds between requests (default: 1.0)")
    parser.add_argument("--books", nargs="*",
                        help="limit to these book names (default: all)")
    args = parser.parse_args()

    api_key = os.environ.get("ESV_API_KEY")
    if not api_key:
        sys.exit("ESV_API_KEY is not set. Run under: doppler run -p personal -c prd_bible --")

    out_path = Path(args.out)
    result = json.loads(out_path.read_text(encoding="utf-8")) if out_path.exists() else {}

    books = chapters_from(args.text_dir)
    if args.books:
        wanted = set(args.books)
        books = [b for b in books if b[0] in wanted]
        missing = wanted - {b[0] for b in books}
        if missing:
            sys.exit(f"No scripture data for: {', '.join(sorted(missing))}")
    if not books:
        sys.exit(f"No book data under {args.text_dir}. Run Scripts/fetch-text.sh first.")

    limiter = RateLimiter(args.delay)
    session = requests.Session()
    fetched = skipped = 0

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
            payload = fetch_passage(session, api_key, reference, limiter)
            passages = payload.get("passages") or []
            if not passages:
                raise RuntimeError(f"{reference}: the API returned no passage")

            # Check we were handed the whole chapter before trusting its
            # paragraphs. A reference the API reads differently than we meant
            # comes back short rather than empty, so length is the tell.
            markers = verse_markers(passages[0])
            expected = last_verse[number]
            if not markers or max(markers) != expected:
                raise RuntimeError(
                    f"{reference}: expected the chapter to run to verse {expected}, "
                    f"got {max(markers) if markers else 'none'} "
                    f"(API read the reference as {payload.get('canonical')!r})"
                )

            book_result[str(number)] = parse_paragraph_starts(passages[0])
            fetched += 1

        # Write after each book so an interrupted run keeps its progress.
        out_path.write_text(json.dumps(result, indent=1, sort_keys=True,
                                       ensure_ascii=False) + "\n", encoding="utf-8")

    out_path.write_text(json.dumps(result, indent=1, sort_keys=True,
                                   ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\n{fetched} chapters fetched, {skipped} already present -> {out_path}")


if __name__ == "__main__":
    main()
