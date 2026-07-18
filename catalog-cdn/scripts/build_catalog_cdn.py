#!/usr/bin/env python3
"""Build Hosting catalog payloads + Firebase Storage asset URLs for GoDive Phase 4b."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
PUBLIC_V1 = ROOT / "public" / "catalog" / "v1"
PHOTOS_DIR = REPO / "GoDiveMVP" / "Resources" / "MarineLifePhotos"
MODELS_DIR = REPO / "GoDiveMVP" / "Resources" / "MarineLife3D"
ML_SOURCE = REPO / "GoDiveMVP" / "MockData" / "marine_life_sample.json"
ODM_SOURCE = REPO / "GoDiveMVP" / "MockData" / "opendivemap_dive_sites_reference.json"
FIREBASE_TOOLS_CONFIG = Path.home() / ".config" / "configstore" / "firebase-tools.json"

DEFAULT_BUCKET = "godive-1cff8.firebasestorage.app"
STORAGE_PREFIX = "catalog/v1/marine_life"

# Public Firebase CLI OAuth client (same as firebase-tools).
FIREBASE_CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
FIREBASE_CLI_CLIENT_SECRET = "jEQSvWwnqJM9uTKhW2KlBbkP"


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def storage_download_url(bucket: str, object_path: str) -> str:
    encoded = urllib.parse.quote(object_path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded}?alt=media"


def compact_json(obj) -> bytes:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def build_marine_life(bucket: str) -> tuple[list, bytes]:
    rows = json.loads(ML_SOURCE.read_text(encoding="utf-8"))
    photo_stems = {p.stem for p in PHOTOS_DIR.glob("*.jpg")}
    model_stems = {p.stem for p in MODELS_DIR.glob("*.usdz")}

    for row in rows:
        resource = (row.get("feature_image_resource") or "").strip()
        if resource and resource in photo_stems:
            object_path = f"{STORAGE_PREFIX}/photos/{resource}.jpg"
            row["feature_image"] = storage_download_url(bucket, object_path)

        model = (row.get("feature_model") or "").strip()
        if model and model in model_stems:
            object_path = f"{STORAGE_PREFIX}/models/{model}.usdz"
            row["feature_model_url"] = storage_download_url(bucket, object_path)

    payload = compact_json(rows)
    return rows, payload


def write_payloads(bucket: str, catalog_version: int) -> dict:
    PUBLIC_V1.mkdir(parents=True, exist_ok=True)

    odm = json.loads(ODM_SOURCE.read_text(encoding="utf-8"))
    sites_bytes = compact_json(odm)
    (PUBLIC_V1 / "dive_sites.json").write_bytes(sites_bytes)

    rows, ml_bytes = build_marine_life(bucket)
    (PUBLIC_V1 / "marine_life.json").write_bytes(ml_bytes)

    manifest = {
        "schemaVersion": 1,
        "catalogVersion": catalog_version,
        "minimumAppVersion": "1.0",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "marineLife": {
            "format": "full",
            "path": "catalog/v1/marine_life.json",
            "sha256": sha256_hex(ml_bytes),
            "itemCount": len(rows),
        },
        "diveSites": {
            "format": "full",
            "path": "catalog/v1/dive_sites.json",
            "sha256": sha256_hex(sites_bytes),
            "itemCount": len(odm),
        },
    }
    (PUBLIC_V1 / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def firebase_access_token() -> str:
    if not FIREBASE_TOOLS_CONFIG.exists():
        raise SystemExit("firebase-tools login required (missing configstore)")
    data = json.loads(FIREBASE_TOOLS_CONFIG.read_text())
    tokens = data.get("tokens") or {}
    access = tokens.get("access_token")
    refresh = tokens.get("refresh_token")
    if access:
        return access
    if not refresh:
        raise SystemExit("No Firebase access token — run `npx firebase-tools login`")

    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": FIREBASE_CLI_CLIENT_ID,
            "client_secret": FIREBASE_CLI_CLIENT_SECRET,
        }
    ).encode()
    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=body,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            refreshed = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise SystemExit(
            "Firebase token refresh failed. Re-run `npx firebase-tools login`, then retry --upload.\n"
            f"HTTP {exc.code}: {detail}"
        ) from exc
    access = refreshed["access_token"]
    tokens["access_token"] = access
    if "expires_in" in refreshed:
        tokens["expires_in"] = refreshed["expires_in"]
    data["tokens"] = tokens
    FIREBASE_TOOLS_CONFIG.write_text(json.dumps(data))
    return access


def upload_object(bucket: str, local: Path, object_path: str, token: str) -> None:
    content_type = "image/jpeg" if local.suffix.lower() == ".jpg" else "model/vnd.usdz+zip"
    query = urllib.parse.urlencode({"uploadType": "media", "name": object_path})
    url = f"https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o?{query}"
    data = local.read_bytes()
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": content_type,
            "Content-Length": str(len(data)),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise SystemExit(f"Upload failed {object_path}: HTTP {exc.code} {detail}") from exc


def upload_assets(bucket: str, dry_run: bool) -> None:
    uploads: list[tuple[Path, str]] = []
    for path in sorted(PHOTOS_DIR.glob("*.jpg")):
        uploads.append((path, f"{STORAGE_PREFIX}/photos/{path.name}"))
    for path in sorted(MODELS_DIR.glob("*.usdz")):
        uploads.append((path, f"{STORAGE_PREFIX}/models/{path.name}"))

    print(f"Asset uploads: {len(uploads)} files")
    if dry_run:
        for local, remote in uploads[:5]:
            print(f"  dry-run {local.name} -> gs://{bucket}/{remote}")
        if len(uploads) > 5:
            print(f"  ... and {len(uploads) - 5} more")
        return

    token = firebase_access_token()
    for index, (local, object_path) in enumerate(uploads, start=1):
        upload_object(bucket, local, object_path, token)
        if index % 25 == 0 or index == len(uploads):
            print(f"  uploaded {index}/{len(uploads)}")
        if index % 200 == 0:
            token = firebase_access_token()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument("--catalog-version", type=int, default=2)
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    manifest = write_payloads(args.bucket, args.catalog_version)
    print("Wrote Hosting payloads:")
    print(json.dumps(manifest, indent=2))

    if args.upload or args.dry_run:
        upload_assets(args.bucket, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
