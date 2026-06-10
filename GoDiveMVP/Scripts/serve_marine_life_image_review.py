#!/usr/bin/env python3
"""
Local review UI for marine life hero images.

Serves a lightweight HTML page to browse bundled photos, inspect metadata,
paste replacement URLs into marine_life_caribbean_staging.csv, and optionally
re-download a single bundled JPEG.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/serve_marine_life_image_review.py
  open http://127.0.0.1:8765
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
import traceback
import urllib.error
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from download_marine_life_images import (
    DEFAULT_OUTPUT_DIR,
    DEFAULT_STAGING,
    load_staging_rows,
    write_staging_csv,
)
from fishbase_catalog_utils import PROJECT_DIR
from marine_life_bundle_image_utils import (
    bundle_resource_name,
    download_and_process_species_photo,
    write_bundle_photo,
)
from marine_life_image_review_store import (
    apply_deletion_mark,
    apply_species_image_update,
    filter_species_records,
    find_row,
    list_species_records,
    species_review_record,
)

try:
    from PIL import UnidentifiedImageError
except ImportError:  # pragma: no cover
    UnidentifiedImageError = Exception  # type: ignore[misc, assignment]

SCRIPT_DIR = Path(__file__).resolve().parent
HTML_PATH = SCRIPT_DIR / "marine_life_image_review.html"
DEFAULT_PORT = 8765
DEFAULT_MANIFEST = PROJECT_DIR / "MockData/marine_life_bundle_photos_manifest.json"


class ReviewServerState:
    def __init__(
        self,
        *,
        staging_path: Path,
        photos_dir: Path,
        manifest_path: Path,
    ) -> None:
        self.staging_path = staging_path
        self.photos_dir = photos_dir
        self.manifest_path = manifest_path
        self.rows = load_staging_rows(staging_path)

    def reload(self) -> None:
        self.rows = load_staging_rows(self.staging_path)

    def species_payload(self, *, query: str = "", filter_key: str = "all") -> list[dict[str, Any]]:
        records = list_species_records(self.rows, photos_dir=self.photos_dir)
        return filter_species_records(records, query=query, filter_key=filter_key)

    def update_species(
        self,
        uuid: str,
        payload: dict[str, Any],
        *,
        download_bundle: bool,
    ) -> dict[str, Any]:
        row = find_row(self.rows, uuid)
        if row is None:
            raise KeyError(f"Unknown species uuid: {uuid}")

        feature_image_url = str(payload.get("featureImageURL") or "").strip()
        if not feature_image_url:
            raise ValueError("featureImageURL is required")

        apply_species_image_update(
            row,
            feature_image_url=feature_image_url,
            image_needs_review=payload.get("imageNeedsReview"),
            image_license=payload.get("imageLicense"),
            image_attribution=payload.get("imageAttribution"),
            image_source=str(payload.get("imageSource") or "manual"),
        )

        if download_bundle:
            self._download_bundle_for_row(row, feature_image_url)

        write_staging_csv(self.staging_path, self.rows)
        return species_review_record(row, photos_dir=self.photos_dir)

    def update_deletion_mark(self, uuid: str, *, mark_for_deletion: bool) -> dict[str, Any]:
        row = find_row(self.rows, uuid)
        if row is None:
            raise KeyError(f"Unknown species uuid: {uuid}")

        apply_deletion_mark(row, mark_for_deletion=mark_for_deletion)
        write_staging_csv(self.staging_path, self.rows)
        return species_review_record(row, photos_dir=self.photos_dir)

    def _download_bundle_for_row(self, row: dict[str, str], source_url: str) -> None:
        uuid = (row.get("uuid") or "").strip()
        jpeg_bytes, digest = download_and_process_species_photo(source_url)
        destination = write_bundle_photo(self.photos_dir, uuid, jpeg_bytes)
        row["featureImageResourceName"] = bundle_resource_name(uuid)

        manifest: dict[str, Any] = {}
        if self.manifest_path.exists():
            manifest = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        manifest[uuid] = {
            "sourceURL": source_url,
            "sha256": digest,
            "bytes": len(jpeg_bytes),
            "path": str(destination.relative_to(PROJECT_DIR)),
        }
        self.manifest_path.parent.mkdir(parents=True, exist_ok=True)
        with self.manifest_path.open("w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2, ensure_ascii=False)
            handle.write("\n")


def make_handler(state: ReviewServerState):
    class ReviewRequestHandler(BaseHTTPRequestHandler):
        server_state = state

        def log_message(self, format: str, *args: Any) -> None:
            print(f"[review] {self.address_string()} {format % args}")

        def do_GET(self) -> None:
            parsed = urlparse(self.path)
            if parsed.path in {"/", "/index.html"}:
                self._serve_html()
                return
            if parsed.path == "/api/species":
                query = parse_qs(parsed.query)
                payload = self.server_state.species_payload(
                    query=(query.get("q") or [""])[0],
                    filter_key=(query.get("filter") or ["all"])[0],
                )
                self._send_json(payload)
                return
            if parsed.path.startswith("/photos/"):
                self._serve_photo(parsed.path.removeprefix("/photos/"))
                return
            self._send_error(HTTPStatus.NOT_FOUND, "Not found")

        def do_POST(self) -> None:
            parsed = urlparse(self.path)
            if not parsed.path.startswith("/api/species/"):
                self._send_error(HTTPStatus.NOT_FOUND, "Not found")
                return

            path_suffix = parsed.path.removeprefix("/api/species/").strip("/")
            path_parts = [part for part in path_suffix.split("/") if part]
            if not path_parts:
                self._send_error(HTTPStatus.BAD_REQUEST, "Missing species uuid")
                return

            uuid = path_parts[0]
            action = path_parts[1] if len(path_parts) > 1 else None

            try:
                body = self._read_json_body()
                if action == "deletion":
                    record = self.server_state.update_deletion_mark(
                        uuid,
                        mark_for_deletion=bool(body.get("markForDeletion")),
                    )
                else:
                    download_bundle = bool(body.get("downloadBundle"))
                    record = self.server_state.update_species(uuid, body, download_bundle=download_bundle)
                self._send_json({"ok": True, "species": record})
            except KeyError as error:
                self._send_error(HTTPStatus.NOT_FOUND, str(error))
            except ValueError as error:
                self._send_error(HTTPStatus.BAD_REQUEST, str(error))
            except (
                urllib.error.HTTPError,
                urllib.error.URLError,
                UnidentifiedImageError,
                RuntimeError,
            ) as error:
                message = str(error)
                if "cannot identify image file" in message.lower():
                    message = (
                        "URL is not a direct image file. Use https://upload.wikimedia.org/… "
                        "(Commons file page → right-click image → Open image in new tab)."
                    )
                self._send_error(HTTPStatus.BAD_GATEWAY, f"Could not download image: {message}")

        def _read_json_body(self) -> dict[str, Any]:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length > 0 else b"{}"
            payload = json.loads(raw.decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("Expected JSON object")
            return payload

        def _serve_html(self) -> None:
            if not HTML_PATH.exists():
                self._send_error(HTTPStatus.INTERNAL_SERVER_ERROR, f"Missing UI file: {HTML_PATH}")
                return
            content = HTML_PATH.read_bytes()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def _serve_photo(self, filename: str) -> None:
            safe_name = Path(filename).name
            photo_path = self.server_state.photos_dir / safe_name
            if not photo_path.exists():
                self._send_error(HTTPStatus.NOT_FOUND, "Photo not found")
                return
            content = photo_path.read_bytes()
            mime_type = mimetypes.guess_type(photo_path.name)[0] or "application/octet-stream"
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def _send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
            content = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def _send_error(self, status: HTTPStatus, message: str) -> None:
            self._send_json({"ok": False, "error": message}, status=status)

    return ReviewRequestHandler


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1
    if not HTML_PATH.exists():
        print(f"Review HTML not found: {HTML_PATH}", file=sys.stderr)
        return 1

    state = ReviewServerState(
        staging_path=args.staging,
        photos_dir=args.photos_dir,
        manifest_path=args.manifest,
    )
    handler = make_handler(state)
    server = ThreadingHTTPServer((args.host, args.port), handler)

    print(f"Marine life image review: http://{args.host}:{args.port}")
    print(f"Staging CSV: {args.staging}")
    print(f"Bundled photos: {args.photos_dir}")
    print("Press Ctrl+C to stop.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:  # pragma: no cover
        traceback.print_exc()
        raise SystemExit(1)
