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
import json
import shutil
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (CACHE_DIR, CANDIDATES_DIR, commons_file_url, load_manifests,  # noqa: E402
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
        url, headers={"User-Agent": "HorneroOS-greeter-media-pipeline/1.0 (https://github.com/HorneroOS/greeter; media pipeline, low volume)"})
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


def evaluate_candidate(candidate_id):
    """Fetch a parked Commons candidate so its integrity record can be
    written. Never used for shipping: promotion re-verifies via --id."""
    path = CANDIDATES_DIR / f"{candidate_id}.json"
    if not path.is_file():
        print(f"unknown candidate id: {candidate_id}", file=sys.stderr)
        return 2
    data = json.loads(path.read_text(encoding="utf-8"))
    try:
        ensure_fetchable(data)
    except RuntimeError as exc:
        print(f"FAILED {candidate_id}: {exc}", file=sys.stderr)
        return 1
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    dest = CACHE_DIR / f"{candidate_id}.{data['original']['container']}"
    tmp = dest.with_suffix(dest.suffix + ".part")
    request = urllib.request.Request(
        commons_file_url(data["source"]["file"]),
        headers={"User-Agent": "HorneroOS-greeter-media-pipeline/1.0 (https://github.com/HorneroOS/greeter; media pipeline, low volume)"})
    with urllib.request.urlopen(request, timeout=300) as response, \
            open(tmp, "wb") as handle:
        shutil.copyfileobj(response, handle, 1 << 20)
    tmp.replace(dest)
    print(json.dumps({"id": candidate_id, "bytes": dest.stat().st_size,
                      "sha256": sha256_of(dest)}))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--all", action="store_true", help="fetch every manifest")
    group.add_argument("--id", help="fetch one manifest id")
    group.add_argument("--evaluate", metavar="ID",
                       help="download a parked Commons CANDIDATE original into the "
                            "cache and print its bytes/SHA256 for the integrity "
                            "record (no verification possible before promotion)")
    args = parser.parse_args(argv)

    if args.evaluate:
        return evaluate_candidate(args.evaluate)
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
