#!/usr/bin/env python3
"""
Generate red_letter_ranges.json from red_letter_verses.json and the Bible text.

Output format:
{
  "John": {
    "13": {
      "8": [[71, 121]]   // list of [start, end) character ranges within verse.text
    }
  }
}

Ranges are 0-indexed into the verse text string (not including the verse separator).
End is exclusive (Python slice convention).

Algorithm per verse:
  1. Check manual_corrections table first (44 hand-reviewed edge cases).
  2. No opening curly-quote → whole verse is red (continuation of prior speech).
  3. One opening curly-quote → from that quote to end of verse.
  4. Multiple opening curly-quotes, and "Jesus" appears in the attribution text
     between the first closing quote and the last opening quote → only from the
     last opening quote to end (someone else speaks first, Jesus responds last).
  5. Otherwise → from the first opening quote to end (includes cases like nested
     OT quotations within Jesus's speech, Aramaic + translation pairs, etc.).
"""

import json
import os

OPEN  = '\u201C'   # "
CLOSE = '\u201D'   # "

RESOURCES = os.path.join(os.path.dirname(__file__), '..', 'ESVBible', 'Resources')

# ---------------------------------------------------------------------------
# Manual corrections for verses where auto-detection produces wrong results.
# Format: (book, chapter_int, verse_int) → [[start, end], ...]
# ---------------------------------------------------------------------------
# CASE 1 – Jesus speaks first, another person answers last.
#           Only the first (Jesus) quote should be red.
# CASE 2 – Another person speaks first, Jesus responds last, but the word
#           "Jesus" does not appear between the quotes so auto-detection
#           would fall back to firstIndex (wrong).
# MULTI  – Three or more speakers / interleaved dialogue.
# ---------------------------------------------------------------------------
MANUAL = {
    # CASE 1 -----------------------------------------------------------------
    ('Matthew',  9, 28): [[78, 121]],    # "Do you believe…?" / "Yes, Lord."
    ('Matthew', 13, 51): [[0,  39]],     # "Have you understood…?" / "Yes."
    ('Matthew', 15, 34): [[24, 54]],     # "How many loaves…?" / "Seven…"
    ('Matthew', 20, 21): [[20, 39]],     # "What do you want?" / "Say that…"
    ('Matthew', 20, 22): [[16, 104]],    # "You do not know…" / "We are able."
    ('Matthew', 22, 42): [[8,  62]],     # "What do you think…?" / "Son of David."
    ('Mark',     5,  9): [[21, 41]],     # "What is your name?" / "My name is Legion…"
    ('Mark',     6, 37): [[22, 55]],     # "You give them…" / "Shall we go…?"
    ('Mark',     6, 38): [[21, 63]],     # "How many loaves…?" / "Five, and two fish."
    ('Mark',     8,  5): [[19, 49]],     # "How many loaves…?" / "Seven."
    ('Mark',     8, 20): [[0,  94]],     # "How many baskets…?" / "Seven."
    ('Mark',     8, 29): [[19, 50]],     # "Who do you say I am?" / "You are the Christ."
    ('Mark',     9, 21): [[28, 70]],     # "How long has this…?" / "From childhood."
    ('Mark',    10, 49): [[28, 39]],     # "Call him." / "Take heart…"
    ('Mark',    10, 51): [[23, 59]],     # "What do you want…?" / "Rabbi, let me recover…"
    ('Mark',    12, 16): [[43, 84]],     # "Whose likeness…?" / "Caesar's."
    ('Luke',     7, 40): [[33, 73]],     # "Simon, I have something…" / "Say it, Teacher."
    ('Luke',     8, 25): [[17, 39]],     # "Where is your faith?" / "Who then is this…?"
    ('Luke',     8, 30): [[22, 42]],     # "What is your name?" / "Legion,"
    ('Luke',     8, 45): [[16, 45]],     # "Who touched me?" / "Master, the crowds…"
    ('Luke',     9, 13): [[21, 54]],     # "You give them…" / "We have no more…"
    ('Luke',     9, 20): [[22, 53]],     # "Who do you say I am?" / "The Christ of God."
    ('Luke',     9, 59): [[20, 32]],     # "Follow me." / "Lord, let me first…"
    ('Luke',    18, 41): [[0,  36]],     # "What do you want…?" / "Lord, let me recover…"
    ('Luke',    22, 35): [[21, 106]],    # "Did you lack anything?" / "Nothing."
    ('Luke',    24, 19): [[21, 35]],     # "What things?" / "Concerning Jesus…"
    ('John',     1, 38): [[54, 77]],     # "What are you seeking?" / "Rabbi…where…?"
    ('John',    11, 34): [[13, 39]],     # "Where have you laid him?" / "Lord, come and see."
    ('John',    18,  7): [[24, 43]],     # "Whom do you seek?" / "Jesus of Nazareth."
    ('John',    20, 15): [[19, 70]],     # "Why are you weeping?…" / "Sir, if you…"
    ('John',    20, 16): [[19, 26]],     # "Mary." / "Rabboni!"
    ('John',    21,  5): [[20, 53]],     # "Do you have any fish?" / "No."
    ('John',    21, 12): [[20, 46]],     # "Come and have breakfast." / "Who are you?"
    ('Acts',     9, 10): [[86, 96]],     # Lord: "Ananias." / Ananias: "Here I am, Lord."

    # CASE 2 -----------------------------------------------------------------
    # Another person speaks first; Jesus responds last; no "Jesus" keyword
    # in the attribution text between the two speeches.
    ('Matthew', 21, 27): [[63, 124]],   # "We do not know." / "Neither will I tell you…"
    ('Matthew', 22, 21): [[45, 141]],   # "Caesar's." / "Therefore render to Caesar…"
    ('Matthew', 26, 25): [[73, 92]],    # Judas: "Is it I, Rabbi?" / Jesus: "You have said so."
    ('Mark',    15,  2): [[75, 94]],    # Pilate: "Are you the King…?" / Jesus: "You have said so."
    ('Luke',     7, 43): [[97, 123]],   # Simon: "The one…" / Jesus: "You have judged rightly."
    ('Luke',    17, 37): [[54, 108]],   # "Where, Lord?" / "Where the corpse is…"
    ('Luke',    22, 38): [[71, 86]],    # "Look, here are two swords." / "It is enough."
    ('Luke',    22, 67): [[55, 92]],    # "If you are the Christ…" / "If I tell you…"
    ('Luke',    22, 70): [[71, 91]],    # "Are you the Son of God?" / "You say that I am."
    ('Acts',     9,  5): [[47, 85]],    # Saul: "Who are you, Lord?" / Jesus: "I am Jesus…"

    # MULTI ------------------------------------------------------------------
    # Interleaved dialogue where both the first and a later speech are Jesus's.
    # Matthew 21:31: verse begins mid-question (continuation from v.30), then
    #   others answer "The first.", then Jesus says "Truly, I say to you…"
    ('Matthew', 21, 31): [[0, 45], [90, 189]],

    # John 21:15-17 – the tripled "do you love me?" exchange
    ('John',    21, 15): [[61, 114], [186, 202]],  # Jesus Q + "Feed my lambs"
    ('John',    21, 16): [[30,  67], [139, 155]],  # Jesus Q + "Tend my sheep"
    ('John',    21, 17): [[31,  68], [126, 143], [238, 253]],  # Q + Q + "Feed my sheep"
}


def compute_ranges(text):
    """
    Return the list of [start, end) red-letter ranges for a verse
    (using auto-detection; manual corrections are applied by the caller).
    """
    opens  = [i for i, c in enumerate(text) if c == OPEN]
    closes = [i for i, c in enumerate(text) if c == CLOSE]

    if not opens:
        # Continuation verse – entire text is red.
        return [[0, len(text)]]

    if len(opens) == 1:
        return [[opens[0], len(text)]]

    # Multiple opening quotes.
    # Check whether "Jesus" appears in the attribution text that lies between
    # the first closing quote and the last opening quote.
    first_close = closes[0] if closes else len(text) - 1
    last_open   = opens[-1]

    if last_open > first_close + 1:
        between = text[first_close + 1 : last_open]
        if 'Jesus' in between:
            return [[last_open, len(text)]]

    # Default: from the first opening quote to the end.
    return [[opens[0], len(text)]]


def main():
    with open(os.path.join(RESOURCES, 'red_letter_verses.json')) as f:
        rl_verses = json.load(f)

    result = {}

    for book, chapters in rl_verses.items():
        bible_path = os.path.join(RESOURCES, f'{book}.json')
        if not os.path.exists(bible_path):
            print(f'WARNING: {bible_path} not found, skipping.')
            continue

        with open(bible_path) as f:
            bible = json.load(f)

        ch_map = {c['number']: {v['number']: v for v in c['verses']}
                  for c in bible['chapters']}

        result[book] = {}
        for ch_str, verse_list in chapters.items():
            ch_num = int(ch_str)
            result[book][ch_str] = {}
            for v_num in verse_list:
                verse = ch_map.get(ch_num, {}).get(v_num)
                if verse is None:
                    print(f'WARNING: {book} {ch_num}:{v_num} not found in text.')
                    continue

                text = verse['text']
                key  = (book, ch_num, v_num)
                ranges = MANUAL.get(key) or compute_ranges(text)

                # Clamp all ranges to [0, len(text)].
                clamped = []
                for start, end in ranges:
                    s = max(0, min(start, len(text)))
                    e = max(s, min(end, len(text)))
                    if s < e:
                        clamped.append([s, e])

                if clamped:
                    result[book][ch_str][str(v_num)] = clamped

    out_path = os.path.join(RESOURCES, 'red_letter_ranges.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, separators=(',', ':'))

    print(f'Wrote {out_path}')

    # Summary
    total_verses = sum(
        len(vs) for bk in result.values() for vs in bk.values()
    )
    multi_range = sum(
        1 for bk in result.values()
          for vs in bk.values()
          for ranges in vs.values()
          if len(ranges) > 1
    )
    print(f'Total verses: {total_verses}')
    print(f'Verses with multiple ranges: {multi_range}')


if __name__ == '__main__':
    main()
