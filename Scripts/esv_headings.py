"""Pull section headings out of ESV API passage HTML.

The text endpoint renders a heading as an ordinary block with no verse number,
which makes it indistinguishable from a psalm superscription. The HTML endpoint
tags both — `<h3>` for a section heading, `<h4 class="psalm-title">` for a
superscription — so headings can be read exactly rather than guessed at.

A heading belongs to the verse that follows it, which is the verse the reader
must break before.
"""

import re
from html.parser import HTMLParser

WHITESPACE = re.compile(r"\s+")


def _clean(parts):
    """Join captured text, flattening the non-breaking spaces the API emits."""
    return WHITESPACE.sub(" ", "".join(parts).replace(" ", " ")).strip()


def _verse_number(label):
    """`6:1 ` opens a chapter, `2 ` continues one; both name a verse."""
    digits = label.strip().split(":")[-1].strip()
    return int(digits) if digits.isdigit() else None


class _Parser(HTMLParser):

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = None
        self.headings = []
        self._pending = []   # headings waiting for the verse they precede
        self._capture = None
        self._buffer = []

    def handle_starttag(self, tag, attrs):
        classes = dict(attrs).get("class", "").split()
        if tag == "h3":
            self._capture, self._buffer = "heading", []
        elif tag == "h4" and "psalm-title" in classes:
            self._capture, self._buffer = "title", []
        elif tag == "b" and ("chapter-num" in classes or "verse-num" in classes):
            self._capture, self._buffer = "verse", []

    def handle_data(self, data):
        if self._capture:
            self._buffer.append(data)

    def handle_endtag(self, tag):
        if self._capture is None:
            return
        # Ignore the inner markup a heading can carry, such as the span the API
        # wraps the divine name in.
        if tag not in ("h3", "h4", "b"):
            return

        text = _clean(self._buffer)
        if self._capture == "heading":
            if text:
                self._pending.append(text)
        elif self._capture == "title":
            self.title = text or None
        elif self._capture == "verse":
            verse = _verse_number(text)
            if verse is not None:
                for heading in self._pending:
                    self.headings.append({"verse": verse, "text": heading})
                self._pending = []
        self._capture, self._buffer = None, []


def verse_numbers(html):
    """Every verse the passage labels, in order of appearance."""
    return [int(n) for n in re.findall(
        r'<b class="(?:chapter-num|verse-num)[^"]*"[^>]*>(?:\d+:)?(\d+)', html)]


def parse_headings(html):
    """`{"title": <psalm superscription or None>, "headings": [{verse, text}]}`.

    A heading with no verse after it is dropped — it belongs to the next
    chapter, which is fetched on its own.
    """
    parser = _Parser()
    parser.feed(html)
    return {"title": parser.title, "headings": parser.headings}
