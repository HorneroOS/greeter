"""Shared helpers for the greeter media pipeline (stdlib only)."""

import json
import re
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
MANIFESTS_DIR = REPO / "media" / "manifests"
CANDIDATES_DIR = REPO / "media" / "candidates"

CACHE_DIR = REPO / ".cache" / "media-originals"
BUILD_BASE_DIR = REPO / "build" / "media" / "base"
DIST_DIR = REPO / "dist"

PACK_NAME = "hornero-greeter-media-base"
PACK_VERSION = "1.0.0"

# Deterministic runtime profile (see docs/media-codec.md for the
# H.264-vs-VP9 decision record):
#   container/codec: MP4 / H.264, yuv420p, <=1080p, <=30fps, no audio.
VIDEO_CODEC = "h264"
PIX_FMT = "yuv420p"
MAX_HEIGHT = 1080
MAX_FPS = 30.0
CRF = "25"
PRESET = "slow"
# Reproducibility: fixed mtime + sorted entries in package.py.
REPRO_MTIME = 0

# Provider identity is separate from license. Absent source.provider means
# wikimedia-commons, so every pre-existing manifest keeps its meaning.
PROVIDERS = {"wikimedia-commons", "pexels"}
DEFAULT_PROVIDER = "wikimedia-commons"
# CC licenses accepted for Commons sources (the original ship policy).
ALLOWED_LICENSES = {"CC0-1.0", "CC-BY-3.0", "CC-BY-4.0", "CC-BY-SA-3.0", "CC-BY-SA-4.0"}
# Every license the manifest model can represent. "Pexels" is the Pexels
# License (https://www.pexels.com/license/) -- not a CC license -- and is
# representable so candidates can be recorded honestly; it is shippable
# only with explicit distribution approval (see is_shippable).
KNOWN_LICENSES = ALLOWED_LICENSES | {"Pexels"}
LICENSES_BY_PROVIDER = {
    "wikimedia-commons": ALLOWED_LICENSES,
    "pexels": {"Pexels"},
}
SHIPPABLE_REVIEW = {"own-work", "reviewed", "written-permission"}
PARKED_REVIEW = {"license-review-needed", "review-pending"}
DISTRIBUTION_STATES = {"approved", "pending", "not-approved"}
DAYPARTS = {"day", "golden-hour", "night"}
CONTAINERS = {"webm", "ogv", "mp4"}


def provider_of(data):
    """Explicit source.provider, defaulting to wikimedia-commons."""
    return data.get("source", {}).get("provider") or DEFAULT_PROVIDER


def distribution_approved(data):
    """Fail-closed distribution approval for binary redistribution.

    An explicit review.distribution wins: only "approved" approves.
    Legacy manifests carry no such field; for them (and only them) a
    Commons CC source with a shippable review status is the recorded
    approval, preserving the exact pre-provider behaviour. Any other
    provider/license without explicit approval is not approved.
    """
    review = data.get("review", {})
    explicit = review.get("distribution")
    if explicit is not None:
        return explicit == "approved"
    return (provider_of(data) == DEFAULT_PROVIDER
            and data.get("license", {}).get("short") in ALLOWED_LICENSES
            and review.get("status") in SHIPPABLE_REVIEW)


def is_shippable(data):
    """True only when review, provider/license coherence, and recorded
    distribution approval all pass. This is the single publishable-set
    computation used by load_manifests, the validator, and audit."""
    if data.get("review", {}).get("status") not in SHIPPABLE_REVIEW:
        return False
    allowed = LICENSES_BY_PROVIDER.get(provider_of(data), set())
    if data.get("license", {}).get("short") not in allowed:
        return False
    return distribution_approved(data)

CENTER_CROP_RE = re.compile(r"center-crop\s+(\d+)\s*x\s*(\d+)", re.IGNORECASE)


def load_manifests(shipped_only=True):
    """Return [(path, data)] sorted by id for media/manifests/."""
    out = []
    for path in sorted(MANIFESTS_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        out.append((path, data))
    if shipped_only:
        out = [(p, d) for p, d in out if is_shippable(d)]
    return out


def cache_path_for(manifest_id, container):
    return CACHE_DIR / f"{manifest_id}.{container}"


def output_path_for(manifest_id):
    return BUILD_BASE_DIR / f"{manifest_id}.mp4"


def commons_file_url(filename):
    """Direct download URL for a Commons-hosted filename."""
    from urllib.parse import quote
    return "https://commons.wikimedia.org/wiki/Special:FilePath/" + quote(filename)


def ffprobe_json(path):
    """Return ffprobe stream/format JSON for *path* (raises on failure)."""
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-print_format", "json",
         "-show_format", "-show_streams", str(path)],
        capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"ffprobe failed for {path}: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def video_stream(info):
    for stream in info.get("streams", []):
        if stream.get("codec_type") == "video":
            return stream
    raise RuntimeError("no video stream found")


def has_audio_stream(info):
    return any(s.get("codec_type") == "audio" for s in info.get("streams", []))


def fps_of(stream):
    """Parse r_frame_rate / avg_frame_rate like '30/1' to float."""
    for key in ("avg_frame_rate", "r_frame_rate"):
        raw = stream.get(key, "")
        if raw and "/" in raw:
            num, den = raw.split("/", 1)
            try:
                if float(den):
                    return float(num) / float(den)
            except ValueError:
                continue
    return 0.0


def parse_center_crop(crop_text):
    """Return (w, h) when the manifest crop note names a center-crop box."""
    match = CENTER_CROP_RE.search(crop_text or "")
    if match:
        return int(match.group(1)), int(match.group(2))
    return None
