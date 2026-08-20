"""Shared plumbing for the generators that read structure from the ESV API.

Only indices and editorial headings are ever written out — see the individual
generators for what each produces.
"""

import json
import os
import re
import sys
import time
from pathlib import Path

import requests

MAX_ATTEMPTS = 5

# When the API throttles it names the wait in the response body rather than in a
# Retry-After header, e.g. {"detail": "Request was throttled. Try again in 1537 seconds."}
THROTTLE_WAIT = re.compile(r"Try again in (\d+) seconds")


class Throttled(Exception):
    """The API asked us to wait longer than this run is willing to."""

    def __init__(self, seconds):
        self.seconds = seconds
        super().__init__(f"throttled for {seconds:.0f}s ({seconds / 60:.0f} min)")


def retry_delay(response):
    """How long the API wants us to wait, or None if it did not say."""
    header = response.headers.get("Retry-After")
    if header:
        try:
            return float(header)
        except ValueError:
            pass
    match = THROTTLE_WAIT.search(response.text or "")
    return float(match.group(1)) if match else None


def api_key_or_exit():
    key = os.environ.get("ESV_API_KEY")
    if not key:
        sys.exit("ESV_API_KEY is not set. Run under: doppler run -p personal -c prd_bible --")
    return key


def passage_reference(book, chapter, chapter_count):
    """The query string for one chapter.

    For a one-chapter book the API reads "Jude 1" as verse 1, not chapter 1, and
    hands back a single verse. Those books have to be asked for by name alone.
    """
    if chapter_count == 1:
        return book
    return f"{book} {chapter}"


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


def fetch_passage(session, url, api_key, reference, params, limiter, max_wait=300):
    """Fetch one chapter, backing off when the API asks us to."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        limiter.wait()
        response = session.get(
            url,
            params={"q": reference, **params},
            headers={"Authorization": f"Token {api_key}"},
            timeout=30,
        )
        if response.status_code == 200:
            payload = response.json()
            passages = payload.get("passages") or []
            if not passages:
                raise RuntimeError(f"{reference}: the API returned no passage")
            return passages[0], payload

        retryable = response.status_code == 429 or response.status_code >= 500
        if not retryable or attempt == MAX_ATTEMPTS:
            raise RuntimeError(f"{reference}: HTTP {response.status_code} {response.text[:200]}")

        # Wait as long as the API asks; back off on our own when it does not say.
        asked = retry_delay(response)
        if asked is not None and asked > max_wait:
            raise Throttled(asked)
        pause = asked if asked is not None else 2 ** attempt
        print(f"  {reference}: HTTP {response.status_code}, retrying in {pause:.0f}s", file=sys.stderr)
        time.sleep(pause)


def books_from(text_dir):
    """Book name, chapter numbers, and each chapter's last verse with text."""
    books = []
    for path in sorted(Path(text_dir).glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "chapters" not in data or "name" not in data:
            continue  # red_letter_ranges.json and friends
        # The ESV omits a few verses as later additions, and so does the API.
        last_verse = {
            c["number"]: max((v["number"] for v in c["verses"] if v["text"]), default=0)
            for c in data["chapters"]
        }
        books.append((data["name"], [c["number"] for c in data["chapters"]], last_verse))
    return books


def select_books(books, wanted):
    if not wanted:
        return books
    wanted = set(wanted)
    chosen = [b for b in books if b[0] in wanted]
    missing = wanted - {b[0] for b in chosen}
    if missing:
        sys.exit(f"No scripture data for: {', '.join(sorted(missing))}")
    return chosen


def write_json(path, data):
    path.write_text(json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n",
                    encoding="utf-8")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
