#!/usr/bin/env python3
"""Fetch original clips into the local cache with SHA256 enforcement.

Reads media/manifests/*.json, downloads each original from its provider,
and verifies byte size + SHA256 against the manifest. Cache hits (hash
matches) are skipped, so re-runs are cheap.

Providers: wikimedia-commons downloads via Special:FilePath (unchanged).
pexels is refused: no lawful fetch route exists until the distribution
rights gate (issue #39) records approval and a pinned authorized
rendition; this script never scrapes Pexels, invents download URLs, or
handles API credentials.

    python3 scripts/media/fetch.py --all
    python3 scripts/media/fetch.py --id ar-ba-buenos-aires

Cache layout (.gitignore'd, never committed):
    .cache/media-originals/<id>.<webm|ogv|mp4>

Stdlib only. Network use is build-time only; runtime ships local files.
"""

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (CACHE_DIR, commons_file_url, load_manifests,  # noqa: E402
                    provider_of)


def sha256_of(path, chunk=1 << 20):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            block = handle.read(chunk)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def ensure_fetchable(data):
    """Raise for providers with no lawful fetch route yet (fail closed)."""
    provider = provider_of(data)
    if provider == "pexels":
        raise RuntimeError(
            "pexels fetch refused: binary-package redistribution is not "
            "approved yet (rights gate, issue #39). Record written "
            "distribution approval (review.distribution=approved with "
            "evidence; see docs/PEXELS_PERMISSION_REQUEST.md) and pin an "
            "authorized rendition in the manifest before any fetch. "
            "Scraping or inventing Pexels download URLs is not supported.")
    if provider != "wikimedia-commons":
        raise RuntimeError(f"unknown provider '{provider}': no fetch route")


def fetch_one(manifest_id, filename, expected_bytes, expected_sha256, dest):
    url = commons_file_url(filename)
    tmp = dest.with_suffix(dest.suffix + ".part")
    request = urllib.request.Request(
        url, headers={"User-Agent": "HorneroOS-greeter-media-pipeline/1.0"})
    last_log = 0
    with urllib.request.urlopen(request, timeout=120) as response, \
            open(tmp, "wb") as handle:
        while True:
            block = response.read(1 << 20)
            if not block:
                break
            handle.write(block)
            last_log += len(block)
    actual_bytes = tmp.stat().st_size
    if actual_bytes != expected_bytes:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(
            f"{manifest_id}: byte size {actual_bytes} != manifest {expected_bytes}")
    actual_sha = sha256_of(tmp)
    if actual_sha != expected_sha256:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(f"{manifest_id}: SHA256 mismatch (got {actual_sha})")
    tmp.replace(dest)
    return actual_bytes


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--all", action="store_true", help="fetch every manifest")
    group.add_argument("--id", help="fetch one manifest id")
    args = parser.parse_args(argv)

    manifests = load_manifests()
    if args.id:
        manifests = [(p, d) for p, d in manifests if d["id"] == args.id]
        if not manifests:
            print(f"unknown manifest id: {args.id}", file=sys.stderr)
            return 2

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    failures = 0
    for _, data in manifests:
        manifest_id = data["id"]
        container = data["original"]["container"]
        dest = CACHE_DIR / f"{manifest_id}.{container}"
        expected_sha = data["original"]["sha256"]
        expected_bytes = data["original"]["bytes"]
        if dest.is_file() and sha256_of(dest) == expected_sha:
            print(f"cached {manifest_id} ({dest.name})")
            continue
        try:
            ensure_fetchable(data)
            fetch_one(manifest_id, data["source"]["file"],
                      expected_bytes, expected_sha, dest)
            print(f"fetched {manifest_id} ({dest.name})")
        except Exception as exc:  # noqa: BLE001 - report per-clip, keep going
            print(f"FAILED {manifest_id}: {exc}", file=sys.stderr)
            failures += 1
    if failures:
        print(f"{failures} fetch(es) failed", file=sys.stderr)
        return 1
    print(f"fetch OK: {len(manifests)} manifest(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
