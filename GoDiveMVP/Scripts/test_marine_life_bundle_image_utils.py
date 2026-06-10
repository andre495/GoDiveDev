"""Tests for bundled marine life photo processing helpers."""

from __future__ import annotations

import io
import unittest

from marine_life_bundle_image_utils import (
    center_crop_rect,
    download_url_candidates,
    response_looks_like_html,
    sha256_hex,
    wikimedia_full_image_url,
)
from marine_life_image_utils import commons_wiki_file_page_title

try:
    from PIL import Image

    HAS_PILLOW = True
except ImportError:  # pragma: no cover
    HAS_PILLOW = False

from marine_life_bundle_image_utils import process_image_bytes


class MarineLifeBundleImageUtilsTests(unittest.TestCase):
    def test_center_crop_rect_landscape(self) -> None:
        crop = center_crop_rect(1600, 900)
        self.assertEqual(crop.width, 1200)
        self.assertEqual(crop.height, 900)
        self.assertEqual(crop.left, 200)
        self.assertEqual(crop.top, 0)

    def test_center_crop_rect_portrait(self) -> None:
        crop = center_crop_rect(900, 1600)
        self.assertEqual(crop.width, 900)
        self.assertEqual(crop.height, 675)
        self.assertEqual(crop.left, 0)
        self.assertEqual(crop.top, 462)

    def test_wikimedia_full_image_url_strips_invalid_thumb_size(self) -> None:
        thumb = (
            "https://upload.wikimedia.org/wikipedia/commons/thumb/7/76/"
            "Alectis_ciliaris_106710346.jpg/960px-Alectis_ciliaris_106710346.jpg"
        )
        self.assertEqual(
            wikimedia_full_image_url(thumb),
            "https://upload.wikimedia.org/wikipedia/commons/7/76/Alectis_ciliaris_106710346.jpg",
        )

    def test_commons_wiki_file_page_title(self) -> None:
        page = "https://commons.wikimedia.org/wiki/File:Sphoeroides_spengleri_159601686.jpg"
        self.assertEqual(
            commons_wiki_file_page_title(page),
            "File:Sphoeroides_spengleri_159601686.jpg",
        )

    def test_response_looks_like_html(self) -> None:
        self.assertTrue(response_looks_like_html(b"<!DOCTYPE html><html>"))
        self.assertFalse(response_looks_like_html(b"\xff\xd8\xff\xe0"))

    def test_download_url_candidates_prefers_full_commons_original(self) -> None:
        thumb = (
            "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Fish.jpg/"
            "960px-Fish.jpg"
        )
        candidates = download_url_candidates(thumb)
        self.assertEqual(candidates[0], thumb)
        self.assertIn(
            "https://upload.wikimedia.org/wikipedia/commons/a/a1/Fish.jpg",
            candidates,
        )
        digest = sha256_hex(b"marine-life")
        self.assertEqual(len(digest), 64)
        self.assertTrue(all(ch in "0123456789abcdef" for ch in digest))


@unittest.skipUnless(HAS_PILLOW, "Pillow not installed")
class MarineLifeBundleImageProcessingTests(unittest.TestCase):
    def test_process_image_bytes_outputs_4_3_jpeg(self) -> None:
        image = Image.new("RGB", (2000, 1000), color=(20, 120, 200))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")

        processed = process_image_bytes(buffer.getvalue(), output_width=960, output_height=720)
        with Image.open(io.BytesIO(processed)) as result:
            self.assertEqual(result.size, (960, 720))
            self.assertEqual(result.format, "JPEG")


if __name__ == "__main__":
    unittest.main()
