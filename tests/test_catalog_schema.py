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
    assert set(catalog["dayparts"]) == {"day", "night"}
    assert isinstance(catalog["dayparts"]["day"], list)
    assert isinstance(catalog["dayparts"]["night"], list)


def test_entries_have_unique_ids_and_valid_shape(catalog):
    seen = set()
    for part in ("day", "night"):
        for entry in catalog["dayparts"][part]:
            assert isinstance(entry["id"], str) and entry["id"]
            assert entry["id"] not in seen, f"duplicate id {entry['id']}"
            seen.add(entry["id"])
            assert entry["daypart"] in ("day", "night", "any")
            assert entry["kind"] == "video"


def test_no_remote_urls_anywhere_in_catalog(catalog):
    text = json.dumps(catalog)
    assert "http://" not in text and "https://" not in text


def test_referenced_files_exist_and_are_local(catalog):
    for part in ("day", "night"):
        for entry in catalog["dayparts"][part]:
            assert not entry["file"].startswith(("http://", "https://", "/", "~"))
            assert (REPO_ROOT / entry["file"]).is_file(), entry["file"]
