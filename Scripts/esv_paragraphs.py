"""Parse ESV API passage text into the verses that begin a paragraph.

The `/v3/passage/text/` endpoint separates paragraphs with blank lines and
marks verses as `[N]`. Poetry stanzas are separated the same way, except the
"blank" lines carry the poetry indent, so they are whitespace rather than empty.

A block that opens mid-verse — the Lord's Prayer, which continues Matthew 6:9 —
has no verse number of its own and starts no paragraph we can record, since the
readers break at verse boundaries.
"""

import re

VERSE_MARKER = re.compile(r"\[(\d+)\]")


def verse_markers(passage):
    """Every verse number the passage marks, in order of appearance."""
    return [int(n) for n in VERSE_MARKER.findall(passage)]


def blocks(passage):
    """Split a passage on blank lines, treating whitespace-only as blank."""
    current = []
    for line in passage.split("\n"):
        if line.strip():
            current.append(line)
        elif current:
            yield "\n".join(current)
            current = []
    if current:
        yield "\n".join(current)


def parse_paragraph_starts(passage):
    """Verse numbers that begin a paragraph, in order."""
    starts = []
    for block in blocks(passage):
        marker = VERSE_MARKER.search(block)
        if marker is None:
            continue  # a psalm superscription, or any block with no verse
        if block[: marker.start()].strip():
            continue  # opens mid-verse, so it starts no verse-aligned paragraph
        starts.append(int(marker.group(1)))
    return starts
