#!/usr/bin/env python3
"""Validate the greeter media catalog.

Checks:
  1. Every file in media/manifests/ and media/candidates/ is valid JSON
     with all schema-required fields, acceptable license values, sane
     numeric ranges, and a well-formed review block.
  2. Ship policy: media/manifests/ may only contain review.status of
     own-work, reviewed, or written-permission. Anything parked
     (license-review-needed / review-pending) must stay in
     media/candidates/.
  3. Shipped manifests must carry the original SHA256 (no nulls).
  4. No video binaries in git: fails on any video file found in the repo.
  5. Runtime zero-network guard: fails on http:// or https:// inside
     runtime paths (QML, components, theme config), ignoring GPL
     license-header boilerplate. Source-side metadata
     (media/manifests, media/candidates, docs) is exempt on purpose:
     manifests must record source page and license URLs. Legacy
     playlists/*.m3u (upstream Apple streams, owned by the Qt6 port
     track) are reported as a warning, not an error.

Stdlib only. Exit 0 when everything passes, 1 otherwise.
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MANIFESTS = REPO / "media" / "manifests"
CANDIDATES = REPO / "media" / "candidates"

LICENSES = {"CC0-1.0", "CC-BY-3.0", "CC-BY-4.0", "CC-BY-SA-3.0", "CC-BY-SA-4.0"}
SHIPPABLE = {"own-work", "reviewed", "written-permission"}
PARKED = {"license-review-needed", "review-pending"}
DAYPARTS = {"day", "night"}
AUDIO = {"strip", "none"}
CONTAINERS = {"webm", "ogv"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SOURCE_PAGE = re.compile(r"^https://commons\.wikimedia\.org/wiki/File:.+")
LICENSE_URL = re.compile(
    r"^https://creativecommons\.org/(publicdomain/zero/1\.0|licenses/(by|by-sa)/[34]\.0)"
)

REQUIRED_TOP = [
    "id", "title", "location", "creator", "source", "license",
    "review", "original", "dayparts", "edit", "notes",
]

VIDEO_EXTENSIONS = {
    ".webm", ".mp4", ".m4v", ".ogv", ".ogg", ".ogm",
    ".mov", ".mkv", ".avi", ".flv", ".wmv",
}

# Runtime paths: QML and theme config. metadata.desktop is excluded: its
# upstream Website/Email fields are desktop-entry metadata, not network
# calls made at runtime. playlists/*.m3u are excluded too: they are legacy
# upstream Apple-stream references owned by the Qt6 port track, which
# replaces them with local files transcoded from media/manifests/ (see
# MEDIA_ROADMAP.md). The exemption is reported as a warning, not silence.
RUNTIME_SCAN = (
    ["Main.qml", "theme.conf", "theme.conf.user"]
    + sorted(str(p) for p in (REPO / "components").glob("*.qml"))
)
# License-notice URLs (GPL header boilerplate) are not network calls.
LICENSE_NOTICE = re.compile(r"gnu\.org/licenses")
URL_PATTERN = re.compile(r"https?://")


def fail(errors, message):
    errors.append(message)


def check_manifest(path, errors, shippable_dir):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(errors, f"{path.name}: unreadable JSON ({exc})")
        return
    for key in REQUIRED_TOP:
        if key not in data:
            fail(errors, f"{path.name}: missing field '{key}'")
    if any(k not in data for k in REQUIRED_TOP):
        return

    if not re.match(r"^ar-[a-z0-9-]+$", data["id"]):
        fail(errors, f"{path.name}: bad id '{data['id']}'")
    loc = data["location"]
    for key in ("place", "province", "region", "country"):
        if not loc.get(key):
            fail(errors, f"{path.name}: location.{key} is empty")
    if loc.get("country") != "Argentina":
        fail(errors, f"{path.name}: location.country must be 'Argentina'")
    if not data.get("creator"):
        fail(errors, f"{path.name}: creator is empty")

    src = data["source"]
    if not SOURCE_PAGE.match(src.get("page", "")):
        fail(errors, f"{path.name}: source.page must be a Commons File: page")
    if not src.get("file"):
        fail(errors, f"{path.name}: source.file is empty")

    lic = data["license"]
    if lic.get("short") not in LICENSES:
        fail(errors, f"{path.name}: license.short '{lic.get('short')}' not allowed")
    if not LICENSE_URL.match(lic.get("url", "")):
        fail(errors, f"{path.name}: license.url '{lic.get('url')}' not canonical")

    status = data["review"].get("status")
    if not data["review"].get("evidence"):
        fail(errors, f"{path.name}: review.evidence is empty")
    if shippable_dir and status not in SHIPPABLE:
        fail(errors, f"{path.name}: status '{status}' must not ship in manifests/")
    if not shippable_dir and status not in PARKED:
        fail(errors, f"{path.name}: candidates must stay parked ('{status}')")

    orig = data["original"]
    if not isinstance(orig.get("bytes"), int) or orig["bytes"] < 1:
        fail(errors, f"{path.name}: original.bytes must be a positive int")
    sha = orig.get("sha256")
    if shippable_dir:
        if not (isinstance(sha, str) and SHA256.match(sha)):
            fail(errors, f"{path.name}: shipped manifests need original.sha256")
    elif sha is not None and not SHA256.match(sha):
        fail(errors, f"{path.name}: original.sha256 malformed")
    if not (isinstance(orig.get("duration_s"), (int, float)) and orig["duration_s"] > 0):
        fail(errors, f"{path.name}: original.duration_s must be positive")
    for dim in ("width", "height"):
        if not isinstance(orig.get(dim), int) or orig[dim] < 1:
            fail(errors, f"{path.name}: original.{dim} must be a positive int")
    if orig.get("container") not in CONTAINERS:
        fail(errors, f"{path.name}: original.container '{orig.get('container')}'")

    if not data["dayparts"] or any(d not in DAYPARTS for d in data["dayparts"]):
        fail(errors, f"{path.name}: dayparts must be non-empty day/night list")

    edit = data["edit"]
    if not (isinstance(edit.get("trim_start_s"), (int, float)) and edit["trim_start_s"] >= 0):
        fail(errors, f"{path.name}: edit.trim_start_s must be >= 0")
    if not (isinstance(edit.get("trim_end_s"), (int, float)) and edit["trim_end_s"] > 0):
        fail(errors, f"{path.name}: edit.trim_end_s must be > 0")
    if edit["trim_end_s"] <= edit["trim_start_s"]:
        fail(errors, f"{path.name}: edit.trim_end_s must exceed trim_start_s")
    if edit["trim_end_s"] > orig.get("duration_s", 0):
        fail(errors, f"{path.name}: edit.trim_end_s exceeds original duration")
    if not edit.get("crop"):
        fail(errors, f"{path.name}: edit.crop is empty")
    if not edit.get("scale"):
        fail(errors, f"{path.name}: edit.scale is empty")
    if edit.get("audio") not in AUDIO:
        fail(errors, f"{path.name}: edit.audio must be strip or none")


def main():
    errors = []

    manifests = sorted(MANIFESTS.glob("*.json")) if MANIFESTS.is_dir() else []
    candidates = sorted(CANDIDATES.glob("*.json")) if CANDIDATES.is_dir() else []
    if not manifests:
        fail(errors, "media/manifests/ holds no manifests")
    for path in manifests:
        check_manifest(path, errors, True)
    for path in candidates:
        check_manifest(path, errors, False)

    ids = [json.loads(p.read_text(encoding="utf-8"))["id"]
           for p in manifests + candidates
           if "id" in json.loads(p.read_text(encoding="utf-8"))]
    if len(ids) != len(set(ids)):
        fail(errors, "duplicate manifest ids")

    for path in sorted(REPO.rglob("*")):
        if ".git/" in path.parts:
            continue
        if path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS:
            fail(errors, f"video binary in git: {path.relative_to(REPO)}")

    for rel in RUNTIME_SCAN:
        path = REPO / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="strict")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if URL_PATTERN.search(line) and not LICENSE_NOTICE.search(line):
                fail(errors, f"runtime network URL: {rel}:{lineno}")

    warnings = []
    playlists = sorted((REPO / "playlists").glob("*.m3u"))
    if any(
        URL_PATTERN.search(line)
        for pl in playlists
        for line in pl.read_text(encoding="utf-8", errors="replace").splitlines()
    ):
        warnings.append(
            "playlists/*.m3u still reference upstream Apple streams; "
            "the Qt6 port track replaces them with local files from "
            "media/manifests/ (see MEDIA_ROADMAP.md transcode queue)."
        )

    if errors:
        print("media catalog validation FAILED:")
        for message in errors:
            print(f"  - {message}")
        return 1
    print(
        f"media catalog OK: {len(manifests)} shipped manifests, "
        f"{len(candidates)} parked candidates, no binaries, no runtime URLs."
    )
    for message in warnings:
        print(f"warning: {message}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
