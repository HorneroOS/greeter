#!/usr/bin/env python3
"""Create small, muted browser previews from approved runtime media.

Requires the desktop media pack to have been built first. Outputs are web
derivatives only; never used by the offline SDDM runtime.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path, help="website public/media/greeter directory")
    args = parser.parse_args(argv)
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("ffmpeg and ffprobe are required", file=sys.stderr)
        return 2

    catalog = json.loads((ROOT / "media/catalog.json").read_text(encoding="utf-8"))
    still_records = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "media/stills").glob("*.json"))]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "components/resources/hornero-symbolic.svg", output / "hornero-symbolic.svg")

    for entries in catalog["dayparts"].values():
        for entry in entries:
            source = ROOT / "build" / entry["file"]
            if not source.is_file():
                raise SystemExit(f"missing built runtime clip: {source}; run scripts/media/build.py first")
            preview = output / f"{entry['id']}.mp4"
            poster = output / f"{entry['id']}.webp"
            run(["ffmpeg", "-y", "-v", "error", "-i", str(source), "-t", "10",
                 "-vf", "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,format=yuv420p",
                 "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "27",
                 "-profile:v", "main", "-movflags", "+faststart", "-map_metadata", "-1", str(preview)])
            run(["ffmpeg", "-y", "-v", "error", "-ss", "3", "-i", str(preview), "-frames:v", "1",
                 "-vf", "scale=1280:720:force_original_aspect_ratio=decrease",
                 "-c:v", "libwebp", "-quality", "76", "-an", str(poster)])
            print(f"{entry['id']}: {preview.stat().st_size} video bytes, {poster.stat().st_size} poster bytes")

    for record in still_records:
        source = ROOT / "media/stills" / record["derivative"]["file"]
        target = output / f"{record['id']}.webp"
        run(["ffmpeg", "-y", "-v", "error", "-i", str(source), "-vf", "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720",
             "-frames:v", "1", "-c:v", "libwebp", "-quality", "76", "-an", str(target)])
        print(f"{record['id']}: {target.stat().st_size} poster bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
