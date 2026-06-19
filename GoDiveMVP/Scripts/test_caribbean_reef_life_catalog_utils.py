"""Tests for Caribbean Reef Life index parsing."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from caribbean_reef_life_catalog_utils import (
    extract_crl_reference_from_epub,
    extract_crl_reference_from_pdf,
    extract_crl_species_profiles_from_xhtml,
    extract_crl_taxonomy_from_epub,
    extract_paragraph_texts_from_xhtml,
    parse_crl_index_line,
    parse_crl_index_text,
    subcategory_slug_matches_category,
)


SAMPLE_INDEX = """
SCIENTIFIC NAME INDEX
MARINE PLANTS:
Acetabularia calyculus, 16
crenulata, 16
Amphiroa brasiliana, 33
fragilissima, 33
SPONGES:
Aplysina fistularis, 58
fulva, 48
Ircinia campana, 67
COMMON NAME INDEX
French Angelfish, 360
"""


class CaribbeanReefLifeCatalogUtilsTests(unittest.TestCase):
    def test_parse_crl_index_line_full_and_continuation(self) -> None:
        parsed = parse_crl_index_line("Acetabularia calyculus, 16", "")
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed[0], "Acetabularia calyculus")
        self.assertEqual(parsed[2], "acetabularia calyculus")

        cont = parse_crl_index_line("crenulata, 16", "Acetabularia")
        self.assertIsNotNone(cont)
        self.assertEqual(cont[0], "Acetabularia crenulata")

    def test_parse_crl_index_text(self) -> None:
        rows = parse_crl_index_text(SAMPLE_INDEX)
        keys = {row["match_key"] for row in rows}
        self.assertIn("acetabularia calyculus", keys)
        self.assertIn("acetabularia crenulata", keys)
        self.assertIn("amphiroa brasiliana", keys)
        self.assertIn("aplysina fistularis", keys)
        self.assertIn("aplysina fulva", keys)
        self.assertIn("ircinia campana", keys)
        self.assertNotIn("french angelfish", keys)

    def test_extract_paragraph_texts_from_xhtml(self) -> None:
        html = """
        <p><span>Halimeda </span><span>copiosa, </span><a href="x"><span>22</span></a></p>
        <p><span> </span><span>cryptica, </span><a href="x"><span>22</span></a></p>
        """
        paragraphs = extract_paragraph_texts_from_xhtml(html)
        self.assertEqual(paragraphs[0], "Halimeda copiosa, 22")
        self.assertEqual(paragraphs[1], "cryptica, 22")

    def test_parse_crl_index_line_skips_group_page_references(self) -> None:
        parsed = parse_crl_index_line("Achelous ordwayi, 285", "")
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed[0], "Achelous ordwayi")

        group = parse_crl_index_line("Acoela, 176", "Achelous")
        self.assertIsNone(group)

    def test_extract_crl_species_profiles_from_xhtml(self) -> None:
        html = """
        <p><span class="CharOverride-29">Banded </span><span class="CharOverride-29">Butterflyfish</span></p>
        <p><span class="CharOverride-25">(</span><span class="CharOverride-30">Chaetodon </span><span class="CharOverride-30">striatus</span><span class="CharOverride-25">)</span><span class="CharOverride-25"> 20 cm / 8 in</span></p>
        <p><span class="CharOverride-31">Silvery white with thin black chevron lines.</span></p>
        """
        profiles = extract_crl_species_profiles_from_xhtml(html, 358)
        self.assertEqual(len(profiles), 1)
        self.assertEqual(profiles[0]["scientificName"], "Chaetodon striatus")
        self.assertEqual(profiles[0]["commonName"], "Banded Butterflyfish")
        self.assertIn("chevron", profiles[0]["description"])

    def test_extract_crl_reference_from_epub(self) -> None:
        epub_root = Path("/Users/andrdugas/Desktop/Caribbean Reef Life 4.epub")
        if not epub_root.is_dir():
            self.skipTest("Caribbean Reef Life EPUB folder not on Desktop")

        rows = extract_crl_reference_from_epub(epub_root)
        keys = {row["match_key"] for row in rows}
        self.assertGreaterEqual(len(keys), 1400)
        self.assertIn("chaetodon striatus", keys)
        self.assertIn("halimeda copiosa", keys)
        self.assertNotIn("achelous acoela", keys)

    def test_build_crl_taxonomy_excludes_self_named_subcategories(self) -> None:
        epub_root = Path("/Users/andrdugas/Desktop/Caribbean Reef Life 4.epub")
        if not epub_root.is_dir():
            self.skipTest("Caribbean Reef Life EPUB folder not on Desktop")

        taxonomy = extract_crl_taxonomy_from_epub(epub_root)
        for category in taxonomy["categories"]:
            for subcategory in category["subcategories"]:
                self.assertFalse(
                    subcategory_slug_matches_category(category["id"], subcategory["id"]),
                    f"{category['id']} should not include subcategory {subcategory['id']}",
                )

        fishes = next(item for item in taxonomy["categories"] if item["id"] == "fishes")
        self.assertNotIn("fishes", {sub["id"] for sub in fishes["subcategories"]})

        sea_turtles = next(item for item in taxonomy["categories"] if item["id"] == "reptiles")
        self.assertEqual(sea_turtles["subcategories"], [])
        self.assertEqual(sea_turtles["title"], "Reptiles")

    def test_extract_crl_reference_from_pdf(self) -> None:
        try:
            import fitz
        except ImportError:
            self.skipTest("PyMuPDF not installed")

        with tempfile.TemporaryDirectory() as tmp:
            pdf_path = Path(tmp) / "sample.pdf"
            doc = fitz.open()
            page = doc.new_page()
            page.insert_text((72, 72), SAMPLE_INDEX, fontsize=10)
            doc.save(pdf_path)
            doc.close()

            rows = extract_crl_reference_from_pdf(pdf_path)
            keys = {row["match_key"] for row in rows}
            self.assertIn("acetabularia calyculus", keys)
            self.assertGreaterEqual(len(keys), 6)


if __name__ == "__main__":
    unittest.main()
