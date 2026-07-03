"""Download, center-crop (4:3), and resize marine life hero JPEGs for the app bundle."""

from __future__ import annotations

import hashlib
import io
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from marine_life_image_utils import (
    USER_AGENT,
    resolve_commons_file_page_url,
    wikimedia_thumbnail_url,
)

try:
    from PIL import Image, UnidentifiedImageError
except ImportError:  # pragma: no cover - optional until Pillow is installed
    Image = None  # type: ignore[misc, assignment]

    class UnidentifiedImageError(Exception):
        """Raised when Pillow is unavailable or cannot decode image bytes."""

MOSAIC_ASPECT_RATIO = 4 / 3
DEFAULT_OUTPUT_WIDTH = 960
DEFAULT_OUTPUT_HEIGHT = 720
DEFAULT_JPEG_QUALITY = 82
BUNDLE_PHOTOS_SUBDIRECTORIES = ("Resources/MarineLifePhotos", "MarineLifePhotos")
REEFGUIDE_BASE_URL = "https://reefguide.org"


@dataclass(frozen=True)
class CenterCropRect:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top


def center_crop_rect(width: int, height: int, *, aspect_ratio: float = MOSAIC_ASPECT_RATIO) -> CenterCropRect:
    """Return pixel bounds for a center crop matching Field Guide mosaic aspect."""
    if width <= 0 or height <= 0:
        raise ValueError("Image dimensions must be positive")

    current_ratio = width / height
    if current_ratio > aspect_ratio:
        crop_width = int(round(height * aspect_ratio))
        left = (width - crop_width) // 2
        return CenterCropRect(left=left, top=0, right=left + crop_width, bottom=height)

    crop_height = int(round(width / aspect_ratio))
    top = (height - crop_height) // 2
    return CenterCropRect(left=0, top=top, right=width, bottom=top + crop_height)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def wikimedia_full_image_url(url: str) -> str | None:
    """Strip `/thumb/.../NNNpx-` from a Commons URL to fetch the original file."""
    match = re.match(
        r"(https://upload\.wikimedia\.org/wikipedia/commons/)thumb/"
        r"([a-f0-9]/[a-f0-9]{2}/)(.+?)/\d+px-.+$",
        url.strip(),
        flags=re.IGNORECASE,
    )
    if not match:
        return None
    return f"{match.group(1)}{match.group(2)}{match.group(3)}"


def response_looks_like_html(data: bytes) -> bool:
    prefix = data[:512].lstrip().lower()
    return prefix.startswith(b"<!doctype html") or prefix.startswith(b"<html") or prefix.startswith(b"<!")


def image_download_failure_message(source_url: str, data: bytes | None = None) -> str:
    if data and response_looks_like_html(data):
        return (
            "URL returned an HTML page, not an image file. "
            "Use a direct image link starting with https://upload.wikimedia.org/… "
            "(on Commons: open the file page, right-click the image, choose “Open image in new tab”)."
        )
    return (
        "Downloaded bytes are not a supported image (JPEG/PNG/WebP). "
        "Paste a direct file URL, not a gallery or search page."
    )


def download_url_candidates(source_url: str) -> list[str]:
    """Try the staging URL, then Commons originals / valid thumb sizes."""
    ordered: list[str] = []

    def add(candidate: str) -> None:
        cleaned = candidate.strip()
        if cleaned and cleaned not in ordered:
            ordered.append(cleaned)

    add(source_url)
    resolved_commons_page = resolve_commons_file_page_url(source_url)
    if resolved_commons_page:
        add(resolved_commons_page)
    full_url = wikimedia_full_image_url(source_url) or resolved_commons_page
    if full_url:
        add(full_url)
        add(wikimedia_thumbnail_url(full_url, 640))
    return ordered


def download_request_headers(url: str) -> dict[str, str]:
    headers = {"User-Agent": USER_AGENT}
    if "reefguide.org" in url.lower():
        headers["Referer"] = REEFGUIDE_BASE_URL + "/"
    return headers


def download_image_bytes(
    url: str,
    *,
    timeout_seconds: float = 45.0,
    max_attempts: int = 4,
    retry_sleep_seconds: float = 2.0,
) -> bytes:
    last_error: Exception | None = None
    for attempt in range(1, max_attempts + 1):
        try:
            request = urllib.request.Request(url, headers=download_request_headers(url))
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code == 429 and attempt < max_attempts:
                time.sleep(retry_sleep_seconds * attempt)
                continue
            raise
        except urllib.error.URLError as error:
            last_error = error
            if attempt < max_attempts:
                time.sleep(retry_sleep_seconds)
                continue
            raise
    if last_error:
        raise last_error
    raise RuntimeError("download_image_bytes failed without an exception")


def process_image_bytes(
    data: bytes,
    *,
    output_width: int = DEFAULT_OUTPUT_WIDTH,
    output_height: int = DEFAULT_OUTPUT_HEIGHT,
    jpeg_quality: int = DEFAULT_JPEG_QUALITY,
) -> bytes:
    if Image is None:
        raise UnidentifiedImageError(
            "Pillow is required for image processing. Install with: pip install Pillow"
        )

    with Image.open(io.BytesIO(data)) as image:
        rgb = image.convert("RGB")
        crop = center_crop_rect(rgb.width, rgb.height)
        cropped = rgb.crop((crop.left, crop.top, crop.right, crop.bottom))
        resized = cropped.resize((output_width, output_height), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        resized.save(buffer, format="JPEG", quality=jpeg_quality, optimize=True)
        return buffer.getvalue()


def bundle_photo_filename(uuid: str) -> str:
    cleaned = uuid.strip()
    if not cleaned:
        raise ValueError("uuid is required for bundled photo filename")
    return f"{cleaned}.jpg"


def bundle_resource_name(uuid: str) -> str:
    """Resource name without extension (matches `{uuid}.jpg` on disk)."""
    return uuid.strip()


def write_bundle_photo(
    output_dir: Path,
    uuid: str,
    jpeg_bytes: bytes,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / bundle_photo_filename(uuid)
    destination.write_bytes(jpeg_bytes)
    return destination


def download_and_process_species_photo(
    source_url: str,
    *,
    output_width: int = DEFAULT_OUTPUT_WIDTH,
    output_height: int = DEFAULT_OUTPUT_HEIGHT,
    jpeg_quality: int = DEFAULT_JPEG_QUALITY,
) -> tuple[bytes, str]:
    last_error: Exception | None = None
    last_raw: bytes | None = None
    for candidate_url in download_url_candidates(source_url):
        try:
            raw = download_image_bytes(candidate_url)
            last_raw = raw
            if response_looks_like_html(raw):
                raise RuntimeError(image_download_failure_message(candidate_url, raw))
            processed = process_image_bytes(
                raw,
                output_width=output_width,
                output_height=output_height,
                jpeg_quality=jpeg_quality,
            )
            return processed, sha256_hex(processed)
        except UnidentifiedImageError:
            last_error = RuntimeError(image_download_failure_message(candidate_url, last_raw))
            continue
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as error:
            last_error = error
            continue
    if last_error:
        raise last_error
    raise RuntimeError(f"Could not download image for {source_url}")
