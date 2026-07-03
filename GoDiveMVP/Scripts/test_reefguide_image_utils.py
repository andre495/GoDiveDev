"""Tests for reefguide.org image search helpers."""

from __future__ import annotations

import unittest

from reefguide_image_utils import (
    ReefGuideGalleryPhoto,
    build_reefguide_attribution,
    parse_cat_sci_html,
    parse_photo_page_image_url,
    parse_species_gallery,
    pick_best_gallery_photo,
    reefguide_full_image_url_from_thumb,
    score_reefguide_photo,
)

CAT_SCI_SNIPPET = """
<a class="tocnamesci" href="sergeantmajor.html">Abudefduf saxatilis</a><br>
<a class="tocnamesci" href="nightsergeant.html">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;taurus</a><br>
<a class="tocnamesci" href="queenangel.html">Holacanthus ciliaris</a><br>
"""

GALLERY_SNIPPET = """
<a class="pixsel" href="pixhtml/queenangel24.html"><img class="selframe" src="../pix/thumb2/queenangel24.jpg" alt="Queen Angelfish - Holacanthus ciliaris - Cozumel, Mexico" title="Queen Angelfish"></a>
 <div class="main2">Cozumel, Mexico</div>
 <div class="main3">&nbsp;</div>
<div class="galleryspan">
<a class="pixsel" href="pixhtml/queenangel22.html"><img class="selframe" src="../pix/thumb2/queenangel22.jpg" alt="Queen Angelfish - Holacanthus ciliaris - Cozumel, Mexico"></a>
 <div class="main2">Cozumel, Mexico</div>
 <div class="main3">Juvenile&nbsp;</div>
</div>
"""

PHOTO_PAGE_SNIPPET = """
<img class="selframe" src="../../pix/queenangel24.jpg" alt="Queen Angelfish - Holacanthus ciliaris">
"""


class ReefGuideImageUtilsTests(unittest.TestCase):
    def test_parse_cat_sci_html_builds_genus_epithet_entries(self) -> None:
        catalog = parse_cat_sci_html(CAT_SCI_SNIPPET, region="carib")
        self.assertIn("abudefduf saxatilis", catalog)
        self.assertIn("abudefduf taurus", catalog)
        self.assertIn("holacanthus ciliaris", catalog)
        self.assertEqual(catalog["holacanthus ciliaris"].species_page_path, "queenangel.html")

    def test_parse_species_gallery_extracts_photos(self) -> None:
        photos = parse_species_gallery(GALLERY_SNIPPET)
        self.assertEqual(len(photos), 2)
        self.assertEqual(photos[0].location, "Cozumel, Mexico")
        self.assertTrue(photos[1].is_juvenile)

    def test_pick_best_gallery_photo_prefers_adult(self) -> None:
        photos = parse_species_gallery(GALLERY_SNIPPET)
        best = pick_best_gallery_photo(photos)
        self.assertIsNotNone(best)
        assert best is not None
        self.assertFalse(best.is_juvenile)
        self.assertEqual(best.pixhtml_path, "pixhtml/queenangel24.html")

    def test_score_reefguide_photo_penalizes_juvenile(self) -> None:
        adult = ReefGuideGalleryPhoto("a", "b", "Queen Angelfish", "Bonaire", "")
        juvenile = ReefGuideGalleryPhoto("a", "b", "Queen Angelfish juvenile", "Bonaire", "Juvenile")
        self.assertGreater(score_reefguide_photo(adult), score_reefguide_photo(juvenile))

    def test_parse_photo_page_image_url(self) -> None:
        url = parse_photo_page_image_url(
            PHOTO_PAGE_SNIPPET,
            page_url="https://reefguide.org/carib/pixhtml/queenangel24.html",
        )
        self.assertEqual(url, "https://reefguide.org/pix/queenangel24.jpg")

    def test_reefguide_full_image_url_from_thumb(self) -> None:
        url = reefguide_full_image_url_from_thumb("../pix/thumb2/queenangel24.jpg")
        self.assertEqual(url, "https://reefguide.org/pix/queenangel24.jpg")

    def test_build_reefguide_attribution(self) -> None:
        text = build_reefguide_attribution(
            common_name="Queen Angelfish",
            scientific_name="Holacanthus ciliaris",
            location="Bonaire",
        )
        self.assertIn("Florent Charpin", text)
        self.assertIn("Holacanthus ciliaris", text)


if __name__ == "__main__":
    unittest.main()
