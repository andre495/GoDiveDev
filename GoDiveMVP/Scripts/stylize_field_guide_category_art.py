#!/usr/bin/env python3
"""Batch-stylize Field Guide category PNGs: thicker minimalist white outlines on black.

Run from repo root:
  python3 GoDiveMVP/Scripts/stylize_field_guide_category_art.py
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageFilter, ImageOps
except ImportError:
    print("Requires Pillow: pip3 install pillow", file=sys.stderr)
    sys.exit(1)

# Tune stroke extraction + weight (applied to every FieldGuideCategory*.png in xcassets).
LINE_THRESHOLD = 118
DILATE_SIZE = 13
DILATE_PASSES = 3
OPEN_SIZE = 3


def repo_assets_dir() -> Path:
    script = Path(__file__).resolve()
    return script.parent.parent / "Assets.xcassets"


def discover_targets(assets_dir: Path) -> list[Path]:
    paths = sorted(assets_dir.glob("FieldGuideCategory*.imageset/*.png"))
    if not paths:
        raise SystemExit(f"No FieldGuideCategory*.png under {assets_dir}")
    return paths


def extract_line_mask(gray: Image.Image) -> Image.Image:
    """Bright strokes only, drop gray shading / interior fill."""
    boosted = ImageOps.autocontrast(gray, cutoff=1)
    mask = boosted.point(lambda p: 255 if p >= LINE_THRESHOLD else 0, mode="L")
    mask = mask.filter(ImageFilter.MinFilter(OPEN_SIZE))
    mask = mask.point(lambda p: 255 if p >= 128 else 0, mode="L")
    for _ in range(DILATE_PASSES):
        mask = mask.filter(ImageFilter.MaxFilter(DILATE_SIZE))
    mask = mask.filter(ImageFilter.GaussianBlur(radius=0.5))
    mask = mask.point(lambda p: 255 if p >= 96 else 0, mode="L")
    mask = mask.filter(ImageFilter.MaxFilter(9))
    return mask


def compose_black_and_white(mask: Image.Image) -> Image.Image:
    width, height = mask.size
    out = Image.new("RGB", (width, height), (0, 0, 0))
    white = Image.new("L", (width, height), 255)
    out.paste(white, mask=mask)
    return out


def process_file(path: Path) -> None:
    gray = Image.open(path).convert("L")
    mask = extract_line_mask(gray)
    out = compose_black_and_white(mask)
    out.save(path, format="PNG", optimize=True)
    print(f"OK {path.name} ({out.size[0]}x{out.size[1]})")


def main() -> None:
    assets_dir = repo_assets_dir()
    for path in discover_targets(assets_dir):
        process_file(path)
    print(f"Processed {len(list(discover_targets(assets_dir)))} images.")


if __name__ == "__main__":
    main()
