import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG = REPO_ROOT / "media" / "catalog.json"


@pytest.fixture(scope="module")
def catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def test_catalog_file_exists():
    assert CATALOG.is_file()


def test_catalog_version(catalog):
    assert catalog["version"] == 1


def test_fallback_image_is_local_and_exists(catalog):
    fallback = catalog["fallbackImage"]
    assert isinstance(fallback, str) and fallback
    assert not fallback.startswith(("http://", "https://", "/", "~"))
    assert "$HOME" not in fallback and ".." not in fallback
    assert (REPO_ROOT / fallback).is_file()


def test_daypart_arrays_present(catalog):
    assert {"day", "night"} <= set(catalog["dayparts"]) <= {"day", "golden-hour", "night"}
    assert isinstance(catalog["dayparts"]["day"], list)
    assert isinstance(catalog["dayparts"]["night"], list)
    if "golden-hour" in catalog["dayparts"]:
        assert isinstance(catalog["dayparts"]["golden-hour"], list)


def test_entries_have_unique_ids_and_valid_shape(catalog):
    seen = set()
    for part in catalog["dayparts"]:
        for entry in catalog["dayparts"][part]:
            assert isinstance(entry["id"], str) and entry["id"]
            assert entry["id"] not in seen, f"duplicate id {entry['id']}"
            seen.add(entry["id"])
            assert entry["daypart"] in ("day", "golden-hour", "night", "any")
            assert entry["kind"] == "video"


def test_no_remote_urls_anywhere_in_catalog(catalog):
    text = json.dumps(catalog)
    assert "http://" not in text and "https://" not in text


def test_referenced_files_exist_and_are_local(catalog):
    # A missing media pack is a supported runtime state (the sequencer
    # skips absent files and falls back to the static image), so this
    # test only enforces existence when the pack is actually built.
    # Typo protection for the not-built case lives in
    # test_wired_entries_match_shippable_manifests below.
    missing = []
    for part in catalog["dayparts"]:
        for entry in catalog["dayparts"][part]:
            assert not entry["file"].startswith(("http://", "https://", "/", "~"))
            if not (REPO_ROOT / entry["file"]).is_file():
                missing.append(entry["file"])
    if missing:
        pytest.skip(f"media pack not built, skipping existence check: {missing}")


def test_wired_entries_match_shippable_manifests(catalog):
    """Offline typo guard: every wired entry must name a shippable manifest.

    Runs with no built media present, so CI catches a wrong id or filename
    even though the pack itself is never downloaded per-PR.
    """
    manifests_dir = REPO_ROOT / "media" / "manifests"
    shippable = set()
    for path in sorted(manifests_dir.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("review", {}).get("status") in ("own-work", "reviewed",
                                                    "written-permission"):
            shippable.add(data["id"])
    assert shippable, "no shippable manifests found"
    for part in catalog["dayparts"]:
        for entry in catalog["dayparts"][part]:
            assert entry["id"] in shippable, f"unshippable id {entry['id']}"
            assert entry["file"] == f"media/base/{entry['id']}.mp4", entry["file"]
            # Night reuse of daylight footage is the documented interim
            # policy (MEDIA_ROADMAP.md gap 2) until native night clips ship.
            assert entry["daypart"] in ("day", "night"), entry["daypart"]
