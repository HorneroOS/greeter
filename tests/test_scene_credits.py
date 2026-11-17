"""On-screen scene credits come only from rights-reviewed manifests.

The bottom rail names the scene on screen with its creator and licence
(CC BY-SA requires attribution). build-catalog derives CREDITS from the
manifests of clips wired into media/catalog.json and from the shipped
stills; nothing else (candidates, rights-pending manifests) may appear.
"""
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEDIA = REPO_ROOT / "media"
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")


def _credits():
    text = (MEDIA / "catalog.js").read_text(encoding="utf-8")
    match = re.search(r"var CREDITS = (\{.*?\});", text, re.DOTALL)
    assert match, "CREDITS block missing from media/catalog.js"
    return json.loads(match.group(1))


def _wired_ids():
    doc = json.loads((MEDIA / "catalog.json").read_text(encoding="utf-8"))
    return {entry["id"] for entries in doc["dayparts"].values() for entry in entries}


def test_credits_cover_exactly_wired_clips_and_shipped_stills():
    # The designed gradient fallbacks are original art and carry no credit.
    assert set(_credits()) == _wired_ids()


def test_credits_match_manifests():
    manifests = {}
    for path in (MEDIA / "manifests").glob("*.json"):
        doc = json.loads(path.read_text(encoding="utf-8"))
        manifests[doc["id"]] = doc
    for scene_id, credit in _credits().items():
        manifest = manifests[scene_id]
        assert credit["title"] == manifest["title"]
        assert credit["creator"] == manifest["creator"]
        assert credit["place"] == manifest["location"]["place"]
        assert credit["license"].replace(" ", "-") == manifest["license"]["short"]


def test_credits_carry_no_urls():
    assert "http" not in json.dumps(_credits())


def test_rail_shows_the_scene_on_screen():
    assert "CatalogData.CREDITS[container.sceneId]" in MAIN
    assert "container.sceneId = deck.currentId" in MAIN
    assert "container.sceneId = container.stillId" in MAIN
