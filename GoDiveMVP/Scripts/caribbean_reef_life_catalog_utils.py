"""Helpers for Caribbean Reef Life (Mickey Charteris) species cross-reference."""

from __future__ import annotations

import re
import zipfile
from pathlib import Path
from typing import Any, Iterable

from fishbase_catalog_utils import normalize_scientific_name_for_match

INDEX_PAGE_PATTERN = re.compile(r",\s*\d+\s*$")
SPECIES_CONTINUATION = re.compile(
    r"^\s*([a-z][a-z-]+(?:\s+var\.\s+[a-z]+)?)\.?\s*,\s*\d+\s*$",
)
SUBGENUS_BINOMIAL = re.compile(
    r"^\s*([A-Z][a-z]+)\s+\(([A-Za-z]+)\)\s+"
    r"([a-z][a-z-]+(?:\s+var\.\s+[a-z]+)?)\.?\s*,\s*\d+\s*$"
)
FULL_BINOMIAL = re.compile(
    r"^\s*(?:([A-Z][a-z]+(?:\s*\([A-Za-z]+\))?)\s+)?([A-Z][a-z]+)\s+"
    r"([a-z][a-z-]+(?:\s+var\.\s+[a-z]+)?)\.?\s*,\s*\d+\s*$"
)
TAXON_RANK_SUFFIX = re.compile(
    r"(idae|inae|oidea|acea|ales|iformes|ii|phyta|mycota|poda)$",
    re.IGNORECASE,
)
SCIENTIFIC_LINE = re.compile(
    r"\(\s*([A-Z][a-z]+(?:\s*\([A-Za-z]+\))?)\s+([a-z][a-z-]+)\s*\)"
)
SPAN_CLASS_TEXT = re.compile(r'class="(CharOverride-\d+)"[^>]*>([^<]*)</span>')
CRL_SECTION_TO_TAXONOMY: dict[str, tuple[str, str]] = {
    "MARINE PLANTS": ("corals", "corals"),
    "SPONGES": ("sponges", "sponges"),
    "CORALS": ("corals", "corals"),
    "OCTOCORALS": ("corals", "corals"),
    "INVERTEBRATES": ("", ""),
    "FISHES": ("fish", ""),
    "SEA TURTLES": ("marine_reptiles", "turtles"),
    "MARINE MAMMALS": ("marine_mammals", "dolphins-and-whales"),
}
SECTION_HEADER = re.compile(
    r"^(MARINE PLANTS|SPONGES|CORALS|OCTOCORALS|INVERTEBRATES|FISHES|"
    r"SEA TURTLES|MARINE MAMMALS|SCIENTIFIC NAME INDEX|COMMON NAME INDEX)\s*:?\s*$",
    re.IGNORECASE,
)
BODY_BINOMIAL = re.compile(
    r"\b([A-Z][a-z]+(?:\s*\([A-Za-z]+\))?)\s+([a-z][a-z-]+(?:\s+var\.\s+[a-z]+)?)\b"
)
EPUB_PAGE_FILE = re.compile(r"REEF_LIFE_4_Ebook_copy_3-(\d+)\.xhtml$", re.IGNORECASE)
P_TAG = re.compile(r"<p\b[^>]*>(.*?)</p>", re.DOTALL | re.IGNORECASE)
HTML_TAG = re.compile(r"<[^>]+>")
WHITESPACE = re.compile(r"\s+")
INDEX_PAGE_NUM = re.compile(r",\s*(\d+)\s*$")
TOC_LINK = re.compile(r'href="REEF_LIFE_4_Ebook_copy_3-(\d+)\.xhtml">([^<]+)</a>')
SCIENTIFIC_INDEX_FIRST_PAGE = 450
COMMON_NAME_INDEX_FIRST_PAGE = 464


def slugify_category_id(title: str) -> str:
    normalized = title.strip().lower().replace("&", "and")
    normalized = re.sub(r"[^a-z0-9]+", "_", normalized).strip("_")
    return normalized or "unknown"


def slugify_subcategory_id(title: str) -> str:
    normalized = title.strip().lower().replace("&", "and")
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")
    return normalized or "general"


def subcategory_slug_matches_category(category_id: str, subcategory_id: str) -> bool:
    """True when a subcategory slug is just the category name repeated."""
    category_slug = category_id.replace("_", "-")
    subcategory_slug = subcategory_id.replace("_", "-")
    return category_slug == subcategory_slug


def _line_has_following_nested_ol(lines: list[str], line_index: int) -> bool:
    if "<ol>" in lines[line_index]:
        return True
    for follow in lines[line_index + 1 : min(line_index + 6, len(lines))]:
        if "</li>" in follow:
            break
        if "<ol>" in follow:
            return True
    return False


def extract_crl_toc_html(epub_path: Path) -> str:
    oebps = resolve_epub_oebps_dir(epub_path)
    if oebps.suffix.lower() == ".epub":
        target = f"zip://{oebps}!OEBPS/toc.xhtml"
    else:
        target = oebps / "toc.xhtml"
    return read_epub_xhtml(epub_path, target)


def parse_crl_bookmark_sections(toc_html: str) -> list[dict[str, str | int]]:
    """Parse EPUB bookmark TOC into page-ordered category/subcategory sections."""
    nav_match = re.search(r'<nav id="toc"[^>]*>.*?</nav>', toc_html, re.DOTALL | re.IGNORECASE)
    if not nav_match:
        return []

    sections: list[dict[str, str | int]] = []
    category_title = ""
    order = 0
    ol_depth = 0
    lines = nav_match.group(0).splitlines()

    for line_index, line in enumerate(lines):
        ol_depth += line.count("<ol")
        ol_depth -= line.count("</ol")

        match = TOC_LINK.search(line)
        if not match:
            continue

        page = int(match.group(1))
        title = match.group(2).strip()
        if page >= SCIENTIFIC_INDEX_FIRST_PAGE or title in {"Cover", "Find it Fast", "Search by Image"}:
            continue

        order += 1
        has_nested_list = _line_has_following_nested_ol(lines, line_index)

        if ol_depth <= 1 and has_nested_list:
            category_title = title
            continue

        if ol_depth <= 1:
            category_title = title
            sections.append(
                {
                    "categoryTitle": title,
                    "subcategoryTitle": title,
                    "startPage": page,
                    "tocOrder": order,
                }
            )
            continue

        if category_title:
            sections.append(
                {
                    "categoryTitle": category_title,
                    "subcategoryTitle": title,
                    "startPage": page,
                    "tocOrder": order,
                }
            )

    return sections


def build_crl_taxonomy_from_toc(toc_html: str) -> dict[str, Any]:
    sections = parse_crl_bookmark_sections(toc_html)
    if not sections:
        return {"categories": [], "pageSections": []}

    page_sections: list[dict[str, str | int]] = []
    for section in sections:
        category_id = slugify_category_id(str(section["categoryTitle"]))
        subcategory_id = slugify_subcategory_id(str(section["subcategoryTitle"]))
        page_sections.append(
            {
                "startPage": int(section["startPage"]),
                "tocOrder": int(section["tocOrder"]),
                "category": category_id,
                "subCategory": subcategory_id,
                "categoryTitle": str(section["categoryTitle"]),
                "subcategoryTitle": str(section["subcategoryTitle"]),
            }
        )

    page_sections.sort(key=lambda item: (item["startPage"], item["tocOrder"]))

    subcategory_ids_by_category: dict[str, set[str]] = {}
    for section in page_sections:
        category_id = str(section["category"])
        subcategory_id = str(section["subCategory"])
        if subcategory_slug_matches_category(category_id, subcategory_id):
            continue
        subcategory_ids_by_category.setdefault(category_id, set()).add(subcategory_id)

    categories: list[dict[str, Any]] = []
    seen_categories: set[str] = set()
    subcategories_by_category: dict[str, list[dict[str, str]]] = {}
    category_titles: dict[str, str] = {}

    for section in page_sections:
        category_id = str(section["category"])
        category_titles.setdefault(category_id, str(section["categoryTitle"]))
        if category_id not in seen_categories:
            seen_categories.add(category_id)
            categories.append({"id": category_id, "title": str(section["categoryTitle"]), "subcategories": []})
            subcategories_by_category[category_id] = []

    for section in page_sections:
        category_id = str(section["category"])
        subcategory_id = str(section["subCategory"])
        if subcategory_slug_matches_category(category_id, subcategory_id):
            continue

        subs = subcategories_by_category[category_id]
        if not any(sub["id"] == subcategory_id for sub in subs):
            subs.append({"id": subcategory_id, "title": str(section["subcategoryTitle"])})

    for category in categories:
        category["title"] = category_titles.get(category["id"], category["title"])
        category["subcategories"] = subcategories_by_category.get(category["id"], [])

    filtered_page_sections: list[dict[str, str | int]] = []
    for section in page_sections:
        category_id = str(section["category"])
        subcategory_id = str(section["subCategory"])
        if subcategory_slug_matches_category(category_id, subcategory_id):
            if subcategory_ids_by_category.get(category_id):
                continue
            section = dict(section)
            section["subCategory"] = ""
        filtered_page_sections.append(section)

    return {"categories": categories, "pageSections": filtered_page_sections}


def taxonomy_for_book_page(page: int | str | None, taxonomy: dict[str, Any]) -> tuple[str, str]:
    if page in (None, ""):
        return "", ""

    try:
        page_num = int(page)
    except (TypeError, ValueError):
        return "", ""

    page_sections = taxonomy.get("pageSections") or []
    match: dict[str, Any] | None = None
    for section in page_sections:
        if int(section["startPage"]) <= page_num:
            match = section
        else:
            break

    if not match:
        return "", ""
    return str(match["category"]), str(match["subCategory"])


def extract_crl_taxonomy_from_epub(epub_path: Path) -> dict[str, Any]:
    return build_crl_taxonomy_from_toc(extract_crl_toc_html(epub_path))


def clean_scientific_phrase(genus: str, species: str) -> str:
    genus = re.sub(r"\s+", " ", genus.strip())
    species = re.sub(r"\s+", " ", species.strip().rstrip("."))
    if species.lower() in {"sp", "spp", "forma"}:
        return ""
    if is_taxonomic_rank_label(species) or is_taxonomic_rank_label(genus):
        return ""
    return f"{genus} {species}".strip()


def is_taxonomic_rank_label(word: str) -> bool:
    token = (word or "").strip().rstrip(".")
    if not token:
        return True
    return bool(TAXON_RANK_SUFFIX.search(token))


def parse_crl_index_line(line: str, current_genus: str) -> tuple[str, str, str, str] | None:
    """Parse one scientific-name index line; returns (full_name, genus, match_key, book_page)."""
    text = line.strip()
    if not text or SECTION_HEADER.match(text):
        return None
    if not INDEX_PAGE_PATTERN.search(text):
        return None

    page_match = INDEX_PAGE_NUM.search(text)
    book_page = page_match.group(1) if page_match else ""

    subgenus_match = SUBGENUS_BINOMIAL.match(text)
    if subgenus_match:
        genus, _subgenus, species = subgenus_match.groups()
        full = clean_scientific_phrase(genus, species)
        if not full:
            return None
        key = normalize_scientific_name_for_match(full)
        return (full, genus, key, book_page) if key else None

    match = FULL_BINOMIAL.match(text)
    if match:
        subgenus, genus, species = match.groups()
        genus_part = subgenus or genus
        full = clean_scientific_phrase(genus_part, species)
        if not full:
            return None
        genus_name = genus_part.split("(")[0].strip()
        key = normalize_scientific_name_for_match(full)
        return (full, genus_name, key, book_page) if key else None

    continuation = SPECIES_CONTINUATION.match(text)
    if continuation and current_genus:
        full = clean_scientific_phrase(current_genus, continuation.group(1))
        if not full:
            return None
        key = normalize_scientific_name_for_match(full)
        return (full, current_genus, key, book_page) if key else None

    return None


def parse_crl_index_text(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    seen: set[str] = set()
    current_genus = ""
    current_section = ""
    in_index = False

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if "SCIENTIFIC NAME INDEX" in line.upper():
            in_index = True
            continue
        if in_index and "COMMON NAME INDEX" in line.upper():
            break
        if not in_index:
            continue

        section_key = line.rstrip(":").strip().upper()
        if section_key in CRL_SECTION_TO_TAXONOMY:
            current_section = section_key
            continue

        parsed = parse_crl_index_line(line, current_genus)
        if not parsed:
            continue
        full_name, genus, match_key, book_page = parsed
        current_genus = genus
        if match_key in seen:
            continue
        seen.add(match_key)
        rows.append(
            {
                "scientificName": full_name,
                "match_key": match_key,
                "genus": genus,
                "indexSection": current_section,
                "bookPage": book_page,
                "source": "scientific_index",
            }
        )
    return rows


def strip_html_tags(fragment: str) -> str:
    return WHITESPACE.sub(" ", HTML_TAG.sub("", fragment)).strip()


def extract_paragraph_texts_from_xhtml(html: str) -> list[str]:
    paragraphs: list[str] = []
    for match in P_TAG.finditer(html):
        text = strip_html_tags(match.group(1))
        if text:
            paragraphs.append(text)
    return paragraphs


def epub_page_number(path: Path | str) -> int | None:
    match = EPUB_PAGE_FILE.search(str(path).replace("\\", "/"))
    if not match:
        return None
    return int(match.group(1))


def resolve_epub_oebps_dir(epub_path: Path) -> Path:
    if epub_path.is_dir():
        oebps = epub_path / "OEBPS"
        if oebps.is_dir():
            return oebps
        if (epub_path / "META-INF").is_dir():
            return epub_path
        raise FileNotFoundError(f"No OEBPS directory under unpacked epub: {epub_path}")

    if epub_path.is_file() and epub_path.suffix.lower() == ".epub":
        return epub_path

    raise FileNotFoundError(f"Not an epub file or unpacked epub directory: {epub_path}")


def iter_epub_xhtml_paths(epub_path: Path) -> Iterable[tuple[int | None, Path | str]]:
    resolved = resolve_epub_oebps_dir(epub_path)
    if resolved.suffix.lower() == ".epub":
        with zipfile.ZipFile(resolved) as archive:
            for name in sorted(archive.namelist()):
                if not name.lower().endswith(".xhtml"):
                    continue
                yield epub_page_number(name), f"zip://{resolved}!{name}"
        return

    for path in sorted(resolved.glob("*.xhtml")):
        yield epub_page_number(path.name), path


def read_epub_xhtml(epub_path: Path, target: Path | str) -> str:
    target_str = str(target)
    if target_str.startswith("zip://"):
        _, remainder = target_str.split("zip://", 1)
        archive_path, member = remainder.split("!", 1)
        with zipfile.ZipFile(archive_path) as archive:
            return archive.read(member).decode("utf-8", errors="replace")
    return Path(target).read_text(encoding="utf-8", errors="replace")


def collect_crl_index_lines_from_epub(epub_path: Path) -> list[str]:
    lines: list[str] = []
    for page_number, xhtml_target in iter_epub_xhtml_paths(epub_path):
        if page_number is None:
            continue
        if page_number < SCIENTIFIC_INDEX_FIRST_PAGE:
            continue
        if page_number >= COMMON_NAME_INDEX_FIRST_PAGE:
            break
        html = read_epub_xhtml(epub_path, xhtml_target)
        lines.extend(extract_paragraph_texts_from_xhtml(html))
    return lines


def append_crl_binomial_rows(
    rows: list[dict[str, str]],
    binomials: Iterable[tuple[str, str]],
    source: str,
    *,
    seen: set[str] | None = None,
) -> None:
    if seen is None:
        seen = {row["match_key"] for row in rows}
    for genus, species in binomials:
        full = clean_scientific_phrase(genus, species)
        key = normalize_scientific_name_for_match(full)
        if not key or key in seen:
            continue
        seen.add(key)
        rows.append(
            {
                "scientificName": full,
                "match_key": key,
                "genus": genus.split("(")[0].strip(),
                "source": source,
            }
        )


def extract_crl_binomials_from_epub_body(epub_path: Path, existing_keys: set[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    seen = set(existing_keys)
    for page_number, xhtml_target in iter_epub_xhtml_paths(epub_path):
        if page_number is not None and page_number >= SCIENTIFIC_INDEX_FIRST_PAGE:
            break
        html = read_epub_xhtml(epub_path, xhtml_target)
        text = strip_html_tags(html)
        append_crl_binomial_rows(rows, BODY_BINOMIAL.findall(text), "epub_body_scan", seen=seen)
    return rows


def paragraph_span_classes(p_html: str) -> set[str]:
    return {class_name for class_name, _text in SPAN_CLASS_TEXT.findall(p_html)}


def parse_size_from_profile_line(text: str) -> str:
    match = re.search(
        r"(\d+(?:\.\d+)?)\s*(?:cm|m)\s*/\s*(\d+(?:\.\d+)?)\s*(?:in|ft)",
        text,
        re.IGNORECASE,
    )
    if not match:
        return ""
    value, unit = match.group(1), text[match.end(1) : match.end()].lower()
    try:
        numeric = float(value)
    except ValueError:
        return ""
    if "cm" in text[match.start() : match.end()].lower():
        meters = numeric / 100.0
        return f"{meters:.4f}".rstrip("0").rstrip(".")
    if unit.startswith("m"):
        return f"{numeric:.4f}".rstrip("0").rstrip(".")
    return ""


def extract_crl_species_profiles_from_xhtml(html: str, page_number: int | None) -> list[dict[str, str]]:
    profiles: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    for match in P_TAG.finditer(html):
        p_html = match.group(1)
        classes = paragraph_span_classes(p_html)
        text = strip_html_tags(p_html)
        if not text:
            continue

        if "CharOverride-29" in classes and "CharOverride-30" not in classes:
            if current and current.get("scientificName"):
                profiles.append(current)
            current = {
                "commonName": text,
                "scientificName": "",
                "description": "",
                "maxSizeMeters": "",
                "bookPage": str(page_number or ""),
                "source": "epub_profile",
            }
            continue

        sci_match = SCIENTIFIC_LINE.search(text)
        if sci_match and current is not None:
            genus, species = sci_match.group(1), sci_match.group(2)
            full = clean_scientific_phrase(genus, species)
            if full:
                current["scientificName"] = full
                current["maxSizeMeters"] = parse_size_from_profile_line(text) or current.get("maxSizeMeters", "")
            continue

        if "CharOverride-31" in classes and current is not None and current.get("scientificName"):
            prior = current.get("description", "")
            current["description"] = f"{prior} {text}".strip() if prior else text

    if current and current.get("scientificName"):
        profiles.append(current)

    for profile in profiles:
        profile["match_key"] = normalize_scientific_name_for_match(profile["scientificName"])
        profile["commonName"] = " ".join(profile["commonName"].split())
        profile["description"] = " ".join(profile.get("description", "").split())
    return [profile for profile in profiles if profile.get("match_key")]


def extract_crl_species_profiles_from_epub(epub_path: Path) -> list[dict[str, str]]:
    profiles_by_key: dict[str, dict[str, str]] = {}
    for page_number, xhtml_target in iter_epub_xhtml_paths(epub_path):
        if page_number is not None and page_number >= SCIENTIFIC_INDEX_FIRST_PAGE:
            break
        if page_number is not None and page_number < 1:
            continue
        html = read_epub_xhtml(epub_path, xhtml_target)
        for profile in extract_crl_species_profiles_from_xhtml(html, page_number):
            key = profile["match_key"]
            existing = profiles_by_key.get(key)
            if not existing or len(profile.get("description", "")) > len(existing.get("description", "")):
                profiles_by_key[key] = profile
    return list(profiles_by_key.values())


def merge_crl_species_records(
    index_rows: list[dict[str, str]],
    profile_rows: list[dict[str, str]],
    taxonomy: dict[str, Any] | None = None,
) -> list[dict[str, str]]:
    merged: dict[str, dict[str, str]] = {}
    for row in index_rows:
        key = row.get("match_key", "")
        if key:
            merged[key] = dict(row)
    for row in profile_rows:
        key = row.get("match_key", "")
        if not key:
            continue
        base = merged.get(key, {})
        base.update({k: v for k, v in row.items() if v})
        if not base.get("scientificName"):
            base["scientificName"] = row.get("scientificName", "")
        if not base.get("source"):
            base["source"] = row.get("source", "epub_profile")
        elif row.get("source") == "epub_profile":
            base["source"] = "scientific_index+epub_profile" if base.get("source") == "scientific_index" else base["source"]
        merged[key] = base

    if taxonomy:
        for key, base in merged.items():
            page = base.get("bookPage") or ""
            category, subcategory = taxonomy_for_book_page(page, taxonomy)
            if category:
                base["category"] = category
            base["subCategory"] = subcategory

    return sorted(merged.values(), key=lambda item: item.get("scientificName", "").lower())


def extract_crl_master_species_from_epub(epub_path: Path) -> list[dict[str, str]]:
    taxonomy = extract_crl_taxonomy_from_epub(epub_path)
    index_lines = collect_crl_index_lines_from_epub(epub_path)
    if not index_lines:
        raise RuntimeError(
            f"No scientific index pages found in {epub_path}. "
            f"Expected XHTML pages {SCIENTIFIC_INDEX_FIRST_PAGE}-{COMMON_NAME_INDEX_FIRST_PAGE - 1}."
        )
    prefixed = "SCIENTIFIC NAME INDEX\n" + "\n".join(index_lines)
    index_rows = parse_crl_index_text(prefixed)
    profile_rows = extract_crl_species_profiles_from_epub(epub_path)
    return merge_crl_species_records(index_rows, profile_rows, taxonomy)


def extract_crl_reference_from_epub(epub_path: Path) -> list[dict[str, str]]:
    index_lines = collect_crl_index_lines_from_epub(epub_path)
    if not index_lines:
        raise RuntimeError(
            f"No scientific index pages found in {epub_path}. "
            f"Expected XHTML pages {SCIENTIFIC_INDEX_FIRST_PAGE}-{COMMON_NAME_INDEX_FIRST_PAGE - 1}."
        )

    rows = extract_crl_master_species_from_epub(epub_path)
    if len(rows) < 200:
        extra = extract_crl_binomials_from_epub_body(epub_path, {row["match_key"] for row in rows})
        rows = merge_crl_species_records(rows, extra)
    return rows


def extract_crl_reference_from_pdf(pdf_path: Path) -> list[dict[str, str]]:
    try:
        import fitz  # PyMuPDF
    except ImportError as exc:
        raise RuntimeError("PyMuPDF is required. Install with: pip install pymupdf") from exc

    doc = fitz.open(pdf_path)
    index_text_parts: list[str] = []
    index_started = False

    for page in doc:
        text = page.get_text()
        upper = text.upper()
        if "SCIENTIFIC NAME INDEX" in upper:
            index_started = True
        if index_started:
            index_text_parts.append(text)
            if "COMMON NAME INDEX" in upper and len(index_text_parts) > 1:
                break

    rows = parse_crl_index_text("\n".join(index_text_parts))

    if len(rows) < 200:
        extra = extract_crl_binomials_from_pdf_body(doc, existing_keys={row["match_key"] for row in rows})
        rows.extend(extra)

    if not rows:
        rows = extract_crl_binomials_from_pdf_body(doc, existing_keys=set())

    doc.close()
    return rows


def extract_crl_binomials_from_pdf_body(doc: Any, existing_keys: set[str]) -> list[dict[str, str]]:
    """Fallback: collect binomials from species profile pages when index text is sparse."""
    rows: list[dict[str, str]] = []
    seen = set(existing_keys)

    for page in doc:
        text = page.get_text()
        if "SCIENTIFIC NAME INDEX" in text.upper():
            break
        for genus, species in BODY_BINOMIAL.findall(text):
            full = clean_scientific_phrase(genus, species)
            key = normalize_scientific_name_for_match(full)
            if not key or key in seen:
                continue
            seen.add(key)
            rows.append(
                {
                    "scientificName": full,
                    "match_key": key,
                    "genus": genus.split("(")[0].strip(),
                    "source": "pdf_body_scan",
                }
            )
    return rows
