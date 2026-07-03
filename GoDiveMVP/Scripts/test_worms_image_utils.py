"""Tests for WoRMS image search helpers."""

from __future__ import annotations

import unittest

from worms_image_utils import (
    WormsGalleryEntry,
    build_worms_attribution,
    parse_image_page_metadata,
    parse_taxon_gallery,
    resolve_aphia_id,
    score_gallery_entry,
)

TAXON_SNIPPET = """
<a href="aphia.php?p=image&pic=20293&tid=276012"><div class="photogallery_classic_item" style="display:inline;"><img class="photogallery_thumb" src="https://images.marinespecies.org/thumbs/20293_holacanthus-ciliaris.jpg?w=198" width="198" height="140" alt="Holacanthus ciliaris" title="Holacanthus ciliaris" /></div>
<a href="aphia.php?p=image&pic=31413&tid=276012"><div class="photogallery_classic_item" style="display:inline;"><img class="photogallery_thumb" src="https://images.marinespecies.org/thumbs/31413_holacanthus-ciliaris-juvenile.jpg?w=208" alt="Holacanthus ciliaris juvenile" /></div>
"""

IMAGE_PAGE_SNIPPET = """
<meta itemprop="license" content="https://creativecommons.org/licenses/by/4.0/">
<span class="photogallery_caption photogallery_author"><span class="photogallery_caption photogallery_text">Nick Hobgood</span></span>
<span class="photogallery_caption photogallery_role">Stamp</span>
<i role="button" tabindex="0" title="Item is checked" class="fa fa-star aphia_icon_link aphia_icon_link_css"></i>
"""


class WormsImageUtilsTests(unittest.TestCase):
    def test_parse_taxon_gallery_extracts_entries(self) -> None:
        entries = parse_taxon_gallery(TAXON_SNIPPET, aphia_id=276012)
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0].pic_id, "20293")
        self.assertEqual(
            entries[0].full_image_url,
            "https://images.marinespecies.org/20293_holacanthus-ciliaris.jpg",
        )

    def test_score_gallery_entry_prefers_adult(self) -> None:
        adult = WormsGalleryEntry("1", "276012", "https://images.marinespecies.org/thumbs/a.jpg", "Holacanthus ciliaris")
        juvenile = WormsGalleryEntry(
            "2",
            "276012",
            "https://images.marinespecies.org/thumbs/b.jpg",
            "Holacanthus ciliaris juvenile",
        )
        self.assertGreater(
            score_gallery_entry(adult, scientific_name="Holacanthus ciliaris"),
            score_gallery_entry(juvenile, scientific_name="Holacanthus ciliaris"),
        )

    def test_parse_image_page_metadata(self) -> None:
        license_label, license_url, author, checked = parse_image_page_metadata(IMAGE_PAGE_SNIPPET)
        self.assertIn("CC BY", license_label.upper())
        self.assertEqual(license_url, "https://creativecommons.org/licenses/by/4.0/")
        self.assertEqual(author, "Nick Hobgood")
        self.assertFalse(checked)

    def test_resolve_aphia_id(self) -> None:
        self.assertEqual(resolve_aphia_id({"AphiaID": 123, "valid_AphiaID": 456}), 456)

    def test_build_worms_attribution(self) -> None:
        text = build_worms_attribution(
            common_name="Queen Angelfish",
            scientific_name="Holacanthus ciliaris",
            author="Nick Hobgood",
            aphia_id=276012,
            pic_id=20293,
        )
        self.assertIn("WoRMS", text)
        self.assertIn("276012", text)


if __name__ == "__main__":
    unittest.main()
