"""theme.conf contract: dayparts, new Qt6 keys, value ranges."""
import configparser
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent


def read_conf(name):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


def test_required_keys_present():
    conf = read_conf("theme.conf")
    for key in (
        "dayTimeStart", "dayTimeEnd", "bgImgDay", "bgImgNight",
        "videoEnabled", "crossfadeDuration", "testMode",
    ):
        assert key in conf, f"missing theme.conf key: {key}"


def test_daypart_window_valid():
    conf = read_conf("theme.conf")
    start, end = int(conf["dayTimeStart"]), int(conf["dayTimeEnd"])
    assert 0 <= start <= 23 and 0 <= end <= 23
    assert start < end


def test_golden_hour_window_valid_and_inside_day():
    conf = read_conf("theme.conf")
    gs, ge = int(conf["goldenHourStart"]), int(conf["goldenHourEnd"])
    start, end = int(conf["dayTimeStart"]), int(conf["dayTimeEnd"])
    assert 0 <= gs <= 23 and 0 <= ge <= 23
    assert gs <= ge
    # Golden-hour is an evening mood overlapping the tail of the day window.
    assert gs <= end and ge >= start


def test_crossfade_within_supported_range():
    conf = read_conf("theme.conf")
    assert 2000 <= int(conf["crossfadeDuration"]) <= 4000


def test_boolean_flags():
    conf = read_conf("theme.conf")
    assert conf["videoEnabled"] in ("true", "false")
    assert conf["testMode"] in ("true", "false")


def test_generated_catalog_present_and_in_sync():
    # The runtime catalog is generated, never fetched: Qt disables GET on
    # local files, so an XHR-loaded catalog would silently never arrive.
    import subprocess

    generated = REPO_ROOT / "media" / "catalog.js"
    assert generated.is_file()
    proc = subprocess.run(
        [sys.executable, str(REPO_ROOT / "scripts" / "media" / "build-catalog"), "--check"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr


def test_fallback_images_are_local_and_exist():
    conf = read_conf("theme.conf")
    for key in ("bgImgDay", "bgImgNight"):
        assert not conf[key].startswith(("http://", "https://"))
        assert (REPO_ROOT / conf[key]).is_file()


def test_no_remote_playlist_references():
    for name in ("theme.conf", "theme.conf.user"):
        text = (REPO_ROOT / name).read_text(encoding="utf-8")
        assert "http://" not in text and "https://" not in text
        assert "playlists/" not in text


def test_user_override_uses_new_schema():
    conf = read_conf("theme.conf.user")
    assert "mediaManifest" not in conf
    assert "bgVidDay" not in conf and "bgVidNight" not in conf
