import unittest

from esv_headings import parse_headings, verse_numbers

# Verbatim /v3/passage/html/ markup, trimmed to the shapes that matter.

MATTHEW_6 = (
    '<h3 id="p40006001_01-1">Giving to the Needy</h3>'
    '<p><span class="line"><b class="chapter-num" id="v40006001-1">6:1&nbsp;</b>'
    '“Beware of practicing your righteousness.</span>'
    '<b class="verse-num inline" id="v40006002-1">2&nbsp;</b>“Thus, when you give.</p>'
    '<h3 id="p40006005_01-1">The Lord’s Prayer</h3>'
    '<p><b class="verse-num" id="v40006005-1">5&nbsp;</b>“And when you pray.</p>'
    '<h3 id="p40006016_01-1">Fasting</h3>'
    '<p><b class="verse-num" id="v40006016-1">16&nbsp;</b>“And when you fast.</p>'
)

# The heading wraps the divine name in a span, and the superscription is its
# own tag rather than a heading.
PSALM_23 = (
    '<h3 id="p19023001_01-1">The <span class="divine-name">Lord</span> Is My Shepherd</h3>'
    '<h4 id="p19023001_06-1" class="psalm-title">A Psalm of David.</h4>'
    '<p class="block-indent"><span class="line">'
    '<b class="chapter-num" id="v19023001-1">23:1&nbsp;</b>&nbsp;&nbsp;The LORD is my shepherd.</span>'
    '<span class="indent line"><b class="verse-num inline" id="v19023002-1">2&nbsp;</b>'
    '&nbsp;&nbsp;He makes me lie down.</span></p>'
)

NO_HEADING = (
    '<p><b class="chapter-num" id="v45009001-1">9:1&nbsp;</b>I am speaking the truth.</p>'
)


class ParseHeadingsTests(unittest.TestCase):

    def test_attaches_each_heading_to_the_verse_it_precedes(self):
        self.assertEqual(parse_headings(MATTHEW_6)["headings"], [
            {"verse": 1, "text": "Giving to the Needy"},
            {"verse": 5, "text": "The Lord’s Prayer"},
            {"verse": 16, "text": "Fasting"},
        ])

    def test_reads_a_chapter_opening_verse_label(self):
        # The first verse is labelled "6:1", not "1"
        self.assertEqual(parse_headings(MATTHEW_6)["headings"][0]["verse"], 1)

    def test_flattens_markup_inside_a_heading(self):
        self.assertEqual(parse_headings(PSALM_23)["headings"],
                         [{"verse": 1, "text": "The Lord Is My Shepherd"}])

    def test_reads_a_psalm_superscription_separately_from_headings(self):
        parsed = parse_headings(PSALM_23)
        self.assertEqual(parsed["title"], "A Psalm of David.")
        self.assertNotIn("A Psalm of David.", [h["text"] for h in parsed["headings"]])

    def test_has_no_title_when_the_chapter_is_not_a_psalm(self):
        self.assertIsNone(parse_headings(MATTHEW_6)["title"])

    def test_returns_nothing_for_a_chapter_with_no_heading(self):
        self.assertEqual(parse_headings(NO_HEADING), {"title": None, "headings": []})

    def test_drops_a_trailing_heading_with_no_verse_after_it(self):
        # A heading for the next chapter can trail the requested passage.
        html = NO_HEADING + '<h3 id="x">Paul at Athens</h3>'
        self.assertEqual(parse_headings(html)["headings"], [])

    def test_handles_empty_html(self):
        self.assertEqual(parse_headings(""), {"title": None, "headings": []})


class VerseNumberTests(unittest.TestCase):

    def test_collects_every_labelled_verse_in_order(self):
        self.assertEqual(verse_numbers(MATTHEW_6), [1, 2, 5, 16])

    def test_reads_the_chapter_opening_label_as_its_verse(self):
        self.assertEqual(verse_numbers(PSALM_23), [1, 2])

    def test_is_empty_when_nothing_is_labelled(self):
        self.assertEqual(verse_numbers("<h3>Fasting</h3>"), [])
