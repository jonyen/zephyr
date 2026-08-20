import unittest

from esv_paragraphs import parse_paragraph_starts, passage_reference, verse_markers

# Verbatim /v3/passage/text/ output, trimmed to the shapes that matter.

MATTHEW_7 = """  [1] “Judge not, that you be not judged. [2] For with the judgment you pronounce you will be judged.

  [6] “Do not give dogs what is holy.

  [7] “Ask, and it will be given to you. [8] For everyone who asks receives.

  [12] “So whatever you wish that others would do to you.

  [28] And when Jesus finished these sayings, [29] for he was teaching them as one who had authority.

"""

# Stanza separators inside poetry carry the poetry indent, so they are
# whitespace rather than empty.
PSALM_23 = """A Psalm of David.

    [1] The LORD is my shepherd; I shall not want.
    [2]     He makes me lie down in green pastures.
    He leads me beside still waters.
    [3]     He restores my soul.
    
    
    [4] Even though I walk through the valley of the shadow of death,
        I will fear no evil,
    
    
    [5] You prepare a table before me
        in the presence of my enemies;
    [6] Surely goodness and mercy shall follow me
        forever.
    

"""

# The prayer block continues verse 9, so it carries no verse number of its own.
MATTHEW_6 = """  [5] “And when you pray, you must not be like the hypocrites. [6] But when you pray, go into your room.

  [7] “And when you pray, do not heap up empty phrases. [8] Do not be like them. [9] Pray then like this:

    “Our Father in heaven,
    hallowed be your name.
    [10] Your kingdom come,
    your will be done,
        on earth as it is in heaven.
    [11] Give us this day our daily bread,
    
    
      [14] For if you forgive others their trespasses, [15] but if you do not forgive others.

"""


class ParseParagraphStartsTests(unittest.TestCase):

    def test_finds_every_prose_paragraph(self):
        self.assertEqual(parse_paragraph_starts(MATTHEW_7), [1, 6, 7, 12, 28])

    def test_treats_whitespace_only_lines_as_stanza_breaks(self):
        self.assertEqual(parse_paragraph_starts(PSALM_23), [1, 4, 5])

    def test_skips_a_psalm_superscription(self):
        self.assertNotIn(0, parse_paragraph_starts(PSALM_23))

    def test_skips_a_block_that_opens_mid_verse(self):
        # The prayer continues verse 9; verse 10 is the first marker in that
        # block but does not begin it, so 10 must not be recorded.
        self.assertEqual(parse_paragraph_starts(MATTHEW_6), [5, 7, 14])

    def test_records_only_the_first_verse_of_a_paragraph(self):
        self.assertNotIn(2, parse_paragraph_starts(MATTHEW_7))
        self.assertNotIn(8, parse_paragraph_starts(MATTHEW_7))

    def test_handles_an_empty_passage(self):
        self.assertEqual(parse_paragraph_starts(""), [])

    def test_handles_a_passage_with_no_verse_markers(self):
        self.assertEqual(parse_paragraph_starts("A Psalm of David.\n\n"), [])

    def test_keeps_paragraph_starts_in_order(self):
        starts = parse_paragraph_starts(MATTHEW_7)
        self.assertEqual(starts, sorted(starts))



class PassageReferenceTests(unittest.TestCase):

    def test_multi_chapter_book_is_asked_for_by_chapter(self):
        self.assertEqual(passage_reference("Matthew", 7, 28), "Matthew 7")

    def test_single_chapter_book_is_asked_for_by_name_alone(self):
        # "Jude 1" reads as Jude verse 1 and returns a single verse.
        self.assertEqual(passage_reference("Jude", 1, 1), "Jude")
        self.assertEqual(passage_reference("Obadiah", 1, 1), "Obadiah")


class VerseMarkerTests(unittest.TestCase):

    def test_collects_every_verse_number_in_order(self):
        self.assertEqual(verse_markers(MATTHEW_7), [1, 2, 6, 7, 8, 12, 28, 29])

    def test_is_empty_when_the_passage_marks_no_verses(self):
        self.assertEqual(verse_markers("A Psalm of David."), [])

if __name__ == "__main__":
    unittest.main()
