#!/usr/bin/env python3
"""Verify cached originals against their manifests (no downloads).

Checks per media/manifests/*.json: cache file exists, byte size and
SHA256 match, and ffprobe reports the manifested duration/dimensions/
container within tolerance. Audio presence is reported, not failed:
the build step always strips audio.

    python3 scripts/media/verify.py [--id <clip-id>]

Stdlib + ffprobe only.
"""

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CACHE_DIR, ffprobe_json, load_manifests  # noqa: E402

DURATION_TOL_S = 1.0


def sha256_of(path, chunk=1 << 20):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            block = handle.read(chunk)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def verify_one(data):
    errors = []
    manifest_id = data["id"]
    container = data["original"]["container"]
    cached = CACHE_DIR / f"{manifest_id}.{container}"
    if not cached.is_file():
        return [f"{manifest_id}: missing cache file {cached} (run fetch.py)"]
    if cached.stat().st_size != data["original"]["bytes"]:
        errors.append(f"{manifest_id}: byte size {cached.stat().st_size} "
                      f"!= manifest {data['original']['bytes']}")
    if sha256_of(cached) != data["original"]["sha256"]:
        errors.append(f"{manifest_id}: SHA256 mismatch")
    try:
        info = ffprobe_json(cached)
    except RuntimeError as exc:
        return errors + [f"{manifest_id}: {exc}"]
    fmt = info.get("format", {})
    try:
        duration = float(fmt.get("duration", -1))
    except (TypeError, ValueError):
        duration = -1
    if duration < 0 or abs(duration - data["original"]["duration_s"]) > DURATION_TOL_S:
        errors.append(f"{manifest_id}: duration {duration:.2f}s != "
                      f"manifest {data['original']['duration_s']}s")
    video = next((s for s in info.get("streams", [])
                  if s.get("codec_type") == "video"), None)
    if video is None:
        errors.append(f"{manifest_id}: no video stream")
    else:
        if video.get("width") != data["original"]["width"]:
            errors.append(f"{manifest_id}: width {video.get('width')} != "
                          f"manifest {data['original']['width']}")
        if video.get("height") != data["original"]["height"]:
            errors.append(f"{manifest_id}: height {video.get('height')} != "
                          f"manifest {data['original']['height']}")
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description="verify cached originals")
    parser.add_argument("--id", help="verify one manifest id")
    args = parser.parse_args(argv)
    manifests = load_manifests()
    if args.id:
        manifests = [(p, d) for p, d in manifests if d["id"] == args.id]
        if not manifests:
            print(f"unknown manifest id: {args.id}", file=sys.stderr)
            return 2
    errors = []
    audio_notes = 0
    for _, data in manifests:
        errors.extend(verify_one(data))
    # Audio report (informational): count cached files carrying audio.
    for _, data in manifests:
        cached = CACHE_DIR / f"{data['id']}.{data['original']['container']}"
        if cached.is_file():
            try:
                info = ffprobe_json(cached)
                if any(s.get("codec_type") == "audio"
                       for s in info.get("streams", [])):
                    print(f"note: {data['id']} carries audio (stripped at build)")
                    audio_notes += 1
            except RuntimeError:
                pass
    if errors:
        print("verify FAILED:")
        for message in errors:
            print(f"  - {message}")
        return 1
    print(f"verify OK: {len(manifests)} manifest(s)"
          + (f", {audio_notes} with audio (stripped at build)" if audio_notes else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
