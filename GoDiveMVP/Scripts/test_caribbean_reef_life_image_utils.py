"""Tests for Caribbean Reef Life EPUB image → staging row matching helpers."""

from __future__ import annotations

import unittest

from caribbean_reef_life_image_utils import (
    CRL_IMAGE_LICENSE,
    build_epub_image_index,
    candidate_species_name_from_filename,
    is_species_image_filename,
    match_image_for_row,
    normalize_common_name,
    provenance_marker,
)

SAMPLE_FILENAMES = [
    "Agelas_spectrum_cmyk.jpg",       # scientific binomial
    "African_pompano_cmyk.jpg",       # common name
    "Agelas_sventres.jpg",            # scientific, no _cmyk
    "3_coneys_2.jpg",                 # descriptive, count-prefixed + variant
    "ocean_surgeonfish.jpg",          # common name
    "1.png",                          # spacer image (skipped)
]


class CaribbeanReefLifeImageUtilsTests(unittest.TestCase):
    def test_is_species_image_filename_skips_non_jpeg(self) -> None:
        self.assertTrue(is_species_image_filename("Agelas_spectrum_cmyk.jpg"))
        self.assertTrue(is_species_image_filename("photo.JPEG"))
        self.assertFalse(is_species_image_filename("1.png"))
        self.assertFalse(is_species_image_filename("styles.css"))

    def test_candidate_species_name_strips_cmyk_variant_and_count(self) -> None:
        self.assertEqual(
            candidate_species_name_from_filename("Agelas_spectrum_cmyk.jpg"),
            "agelas spectrum",
        )
        self.assertEqual(
            candidate_species_name_from_filename("African_pompano_cmyk.jpg"),
            "african pompano",
        )
        # Leading count prefix and trailing variant suffix both drop out.
        self.assertEqual(candidate_species_name_from_filename("3_coneys_2.jpg"), "coneys")

    def test_normalize_common_name(self) -> None:
        self.assertEqual(normalize_common_name("Dwarf Spinyhead blenny"), "dwarf spinyhead blenny")
        self.assertEqual(normalize_common_name("Sergeant-major!"), "sergeant major")

    def test_match_prefers_scientific_over_common(self) -> None:
        index = build_epub_image_index(SAMPLE_FILENAMES)
        # 5 jpg files indexed, the .png skipped.
        self.assertEqual(index.count, 5)

        # Scientific-name hit.
        match = match_image_for_row("Agelas spectrum", "Orange lumpy sponge", index)
        assert match is not None
        self.assertEqual(match.filename, "Agelas_spectrum_cmyk.jpg")
        self.assertEqual(match.match_kind, "scientific")

        # Common-name hit when the scientific name isn't a filename.
        match = match_image_for_row("Alectis ciliaris", "African pompano", index)
        assert match is not None
        self.assertEqual(match.filename, "African_pompano_cmyk.jpg")
        self.assertEqual(match.match_kind, "common")

    def test_match_returns_none_when_no_key(self) -> None:
        index = build_epub_image_index(SAMPLE_FILENAMES)
        self.assertIsNone(match_image_for_row("Nonexistus fakus", "Imaginary fish", index))

    def test_scientific_precedence_when_both_present(self) -> None:
        # A file that could match by common name too, but scientific wins.
        index = build_epub_image_index(["Acanthurus_tractus_cmyk.jpg", "ocean_surgeonfish.jpg"])
        match = match_image_for_row("Acanthurus tractus", "ocean surgeonfish", index)
        assert match is not None
        self.assertEqual(match.match_kind, "scientific")
        self.assertEqual(match.filename, "Acanthurus_tractus_cmyk.jpg")

    def test_provenance_marker_and_license_constant(self) -> None:
        self.assertEqual(
            provenance_marker("Agelas_sventres.jpg"),
            "caribbean-reef-life-4:OEBPS/image/Agelas_sventres.jpg",
        )
        self.assertIn("Mickey Charteris", CRL_IMAGE_LICENSE)


if __name__ == "__main__":
    unittest.main()
