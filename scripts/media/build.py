#!/usr/bin/env python3
"""Transcode cached originals to the deterministic runtime profile.

Profile (see docs/media-codec.md): MP4 / H.264, yuv420p, <=1080p,
<=30fps, no audio, faststart. Per manifest: apply the trim window,
apply a center-crop only when the manifest names an explicit WxH
center-crop box (today: the SD Bariloche slot), never upscale SD
sources, downscale anything taller than 1080p, halve the frame rate
only when the source exceeds 30fps, and always strip audio.

Inputs:  .cache/media-originals/<id>.<webm|ogv>  (see fetch.py)
Outputs: build/media/base/<id>.mp4 + <id>.sha256, plus generated
         catalog.json, catalog.csv, MEDIA_LICENSES.md, ATTRIBUTION.md.

    python3 scripts/media/build.py [--id <clip-id>] [--fixture]

--fixture builds one synthetic clip (ffmpeg testsrc, no downloads) so
CI and reviewers can exercise the whole pipeline offline.

Requires ffmpeg + ffprobe. Stdlib otherwise.
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD_BASE_DIR, CACHE_DIR, CRF, MAX_FPS, MAX_HEIGHT,  # noqa: E402
                    PIX_FMT, PRESET, ffprobe_json, fps_of, load_manifests,
                    output_path_for, parse_center_crop, video_stream)

FIXTURE_ID = "ar-example-sample"
DURATION_TOL_S = 0.6


def run(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {proc.stderr.strip()[-2000:]}")
    return proc


def build_filter_chain(src_w, src_h, src_fps, crop_box):
    """Return the -vf chain for one clip. Never upscales."""
    filters = []
    if crop_box:
        crop_w, crop_h = crop_box
        crop_w = min(crop_w, src_w)
        crop_h = min(crop_h, src_h)
        filters.append(f"crop={crop_w}:{crop_h}")
        src_w, src_h = crop_w, crop_h
    if src_h > MAX_HEIGHT:
        filters.append(
            "scale=trunc(min(1\\,min(1920/iw\\,1080/ih))*iw/2)*2:"
            "trunc(min(1\\,min(1920/iw\\,1080/ih))*ih/2)*2")
    if src_fps > MAX_FPS + 0.01:
        filters.append("fps=30")
    filters.append("format=yuv420p")
    return ",".join(filters)


def transcode(src, dest, start, end, vf_chain):
    duration = end - start
    cmd = ["ffmpeg", "-y", "-v", "error",
           "-ss", str(start), "-i", str(src),
           "-t", str(duration)]
    if vf_chain:
        cmd += ["-vf", vf_chain]
    cmd += ["-an", "-c:v", "libx264", "-preset", PRESET, "-crf", CRF,
            "-pix_fmt", PIX_FMT, "-profile:v", "high", "-level", "4.0",
            "-movflags", "+faststart", "-map_metadata", "-1",
            str(dest)]
    run(cmd)


def ffprobe_validate(path, expect_duration):
    info = ffprobe_json(path)
    stream = video_stream(info)
    problems = []
    if stream.get("codec_name") != "h264":
        problems.append(f"codec {stream.get('codec_name')} != h264")
    if stream.get("pix_fmt") != PIX_FMT:
        problems.append(f"pix_fmt {stream.get('pix_fmt')} != {PIX_FMT}")
    if int(stream.get("height", 0)) > MAX_HEIGHT:
        problems.append(f"height {stream.get('height')} > {MAX_HEIGHT}")
    fps = fps_of(stream)
    if fps > MAX_FPS + 0.5:
        problems.append(f"fps {fps:.2f} > {MAX_FPS}")
    if any(s.get("codec_type") == "audio" for s in info.get("streams", [])):
        problems.append("audio stream present")
    try:
        got = float(info.get("format", {}).get("duration", -1))
    except (TypeError, ValueError):
        got = -1
    if got < 0 or abs(got - expect_duration) > DURATION_TOL_S:
        problems.append(f"duration {got:.2f}s != expected {expect_duration:.2f}s")
    return problems


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def build_one(data):
    manifest_id = data["id"]
    container = data["original"]["container"]
    src = CACHE_DIR / f"{manifest_id}.{container}"
    if not src.is_file():
        raise RuntimeError(f"missing cache file {src} (run fetch.py)")
    info = ffprobe_json(src)
    stream = video_stream(info)
    src_w, src_h = int(stream["width"]), int(stream["height"])
    src_fps = fps_of(stream) or 30.0
    crop_box = parse_center_crop(data["edit"].get("crop", ""))
    vf_chain = build_filter_chain(src_w, src_h, src_fps, crop_box)
    start = float(data["edit"]["trim_start_s"])
    end = float(data["edit"]["trim_end_s"])
    BUILD_BASE_DIR.mkdir(parents=True, exist_ok=True)
    dest = output_path_for(manifest_id)
    transcode(src, dest, start, end, vf_chain)
    problems = ffprobe_validate(dest, end - start)
    if problems:
        raise RuntimeError(f"{manifest_id}: " + "; ".join(problems))
    digest = sha256_file(dest)
    (dest.with_suffix(".sha256")).write_text(f"{digest}  {dest.name}\n")
    dest.chmod(0o644)
    return {"id": manifest_id, "file": dest.name, "sha256": digest,
            "vf": vf_chain or "(passthrough scale)"}


def build_fixture():
    """Offline fixture: 4 s synthetic 720p30, same profile + validators."""
    BUILD_BASE_DIR.mkdir(parents=True, exist_ok=True)
    dest = BUILD_BASE_DIR / f"{FIXTURE_ID}.mp4"
    run(["ffmpeg", "-y", "-v", "error",
         "-f", "lavfi", "-i", "testsrc=size=1280x720:rate=30:duration=4",
         "-f", "lavfi", "-i", "sine=frequency=440:duration=4",
         "-t", "4", "-an",
         "-c:v", "libx264", "-preset", PRESET, "-crf", CRF,
         "-pix_fmt", PIX_FMT, "-profile:v", "high", "-level", "4.0",
         "-movflags", "+faststart", "-map_metadata", "-1",
         str(dest)])
    problems = ffprobe_validate(dest, 4.0)
    if problems:
        raise RuntimeError(f"{FIXTURE_ID}: " + "; ".join(problems))
    digest = sha256_file(dest)
    (dest.with_suffix(".sha256")).write_text(f"{digest}  {dest.name}\n")
    dest.chmod(0o644)
    return dest


def write_generated(manifests):
    """catalog.json / catalog.csv / MEDIA_LICENSES.md / ATTRIBUTION.md."""
    entries = []
    for _, data in manifests:
        manifest_id = data["id"]
        sidecar = BUILD_BASE_DIR / f"{manifest_id}.sha256"
        digest = sidecar.read_text().split()[0] if sidecar.is_file() else None
        entries.append({
            "id": manifest_id,
            "file": f"{manifest_id}.mp4",
            "sha256": digest,
            "title": data["title"],
            "place": data["location"]["place"],
            "province": data["location"]["province"],
            "region": data["location"]["region"],
            "creator": data["creator"],
            "license": data["license"]["short"],
            "license_url": data["license"]["url"],
            "dayparts": data["dayparts"],
            "source_page": data["source"]["page"],
        })
    catalog = {"version": 1, "pack": "base", "profile": "mp4/h264/yuv420p/<=1080p/<=30fps/no-audio",
               "fallbackImage": "background.jpg", "clips": entries}
    (BUILD_BASE_DIR / "catalog.json").write_text(
        json.dumps(catalog, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    lines = ["id,file,sha256,title,place,province,region,creator,license,dayparts"]
    for entry in entries:
        lines.append(",".join(
            f'"{entry[k]}"' for k in
            ("id", "file", "sha256", "title", "place", "province",
             "region", "creator", "license")) + f',"{ "|".join(entry["dayparts"])}"')
    (BUILD_BASE_DIR / "catalog.csv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    lic_lines = ["# Media licenses (hornero-greeter-media-base)", "",
                 "Generated at build time from media/manifests/.",
                 "Full provenance per clip lives in the source manifests.", ""]
    for entry in entries:
        lic_lines += [f"## {entry['id']} - {entry['title']}",
                      f"- Creator: {entry['creator']}",
                      f"- License: {entry['license']} ({entry['license_url']})",
                      f"- Source: {entry['source_page']}",
                      f"- Derivative: {entry['file']} (SHA256 {entry['sha256']})", ""]
    (BUILD_BASE_DIR / "MEDIA_LICENSES.md").write_text(
        "\n".join(lic_lines), encoding="utf-8")
    attr_lines = ["HorneroOS greeter media attribution (base pack)", ""]
    for entry in entries:
        attr_lines.append(f"- {entry['title']} - {entry['creator']} - {entry['license']}")
    attr_lines.append("")
    (BUILD_BASE_DIR / "ATTRIBUTION.md").write_text(
        "\n".join(attr_lines), encoding="utf-8")
    for name in ("catalog.json", "catalog.csv", "MEDIA_LICENSES.md", "ATTRIBUTION.md"):
        (BUILD_BASE_DIR / name).chmod(0o644)


def main(argv=None):
    parser = argparse.ArgumentParser(description="transcode cached originals")
    parser.add_argument("--id", help="build one manifest id")
    parser.add_argument("--fixture", action="store_true",
                        help="build synthetic offline fixture instead")
    args = parser.parse_args(argv)
    for tool in ("ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            print(f"missing required tool: {tool}", file=sys.stderr)
            return 2
    if args.fixture:
        dest = build_fixture()
        print(f"fixture OK: {dest.name}")
        return 0
    manifests = load_manifests()
    if args.id:
        manifests = [(p, d) for p, d in manifests if d["id"] == args.id]
        if not manifests:
            print(f"unknown manifest id: {args.id}", file=sys.stderr)
            return 2
    built = []
    for _, data in manifests:
        try:
            result = build_one(data)
            built.append(result)
            print(f"built {result['id']} ({result['vf']})")
        except RuntimeError as exc:
            print(f"FAILED: {exc}", file=sys.stderr)
            return 1
    write_generated(manifests)
    print(f"build OK: {len(built)} clip(s) + catalog.json/csv + licenses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
