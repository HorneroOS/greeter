"""Media pipeline + packaging tests (offline; fixture only, no downloads)."""

import json
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
MEDIA = REPO / "scripts" / "media"
sys.path.insert(0, str(MEDIA))

from common import (BUILD_BASE_DIR, MAX_FPS, MAX_HEIGHT, ffprobe_json,  # noqa: E402
                    fps_of, load_manifests, video_stream)


def run(*args):
    proc = subprocess.run(list(args), capture_output=True, text=True, cwd=REPO)
    assert proc.returncode == 0, f"{args} failed: {proc.stderr[-2000:]}"
    return proc


@pytest.fixture(scope="session", autouse=True)
def _clean_pipeline_artifacts():
    """build/, dist/ and .cache/ are gitignored staging areas: the suite
    must not leave video files behind (the catalog validator fails on
    any video binary in the repo), so clean before and after."""
    for name in ("build", "dist", ".cache"):
        shutil.rmtree(REPO / name, ignore_errors=True)
    yield
    for name in ("build", "dist", ".cache"):
        shutil.rmtree(REPO / name, ignore_errors=True)


def test_manifests_load_and_licenses_allowlisted():
    manifests = load_manifests()
    assert len(manifests) == 10
    allowed = {"CC0-1.0", "CC-BY-3.0", "CC-BY-4.0", "CC-BY-SA-3.0", "CC-BY-SA-4.0"}
    for _, data in manifests:
        assert data["license"]["short"] in allowed
        assert data["review"]["status"] in {
            "own-work", "reviewed", "written-permission"}


def test_packaging_layout_and_no_sddm_conf_rewrite():
    theme_pkg = (REPO / "packaging/arch/hornero-greeter/PKGBUILD").read_text()
    media_pkg = (REPO / "packaging/arch/hornero-greeter-media-base/PKGBUILD").read_text()
    assert "/usr/share/sddm/themes/hornero/" in theme_pkg
    assert "sddm.conf.d" in theme_pkg
    assert "/etc/sddm.conf rewrite" not in theme_pkg
    assert ">/etc/sddm.conf" not in theme_pkg
    assert 'etc/sddm.conf"' not in theme_pkg
    assert "/usr/share/hornero/greeter/media/base" in media_pkg
    assert "--strip-components=1 hornero-greeter-media-base/base" in media_pkg
    assert "depends=('gst-libav')" in media_pkg
    assert "0644" in theme_pkg and "0644" in media_pkg
    snippet = REPO / "packaging/arch/hornero-greeter/hornero.conf"
    assert snippet.read_text().startswith("[Theme]\n")
    assert "InputMethod=" not in snippet.read_text()
    assert "Current=hornero" in snippet.read_text()
    keyboard_example = REPO / "packaging/arch/hornero-greeter/sddm-virtual-keyboard.conf.example"
    assert "InputMethod=qtvirtualkeyboard" in keyboard_example.read_text()


def test_audit_passes_offline():
    run(sys.executable, "scripts/media/audit.py")


def test_validator_passes():
    run(sys.executable, "scripts/validate-media-manifests.py")


def test_git_size_guard_no_binaries_tracked():
    out = subprocess.run(["git", "ls-files"], capture_output=True, text=True,
                         cwd=REPO).stdout.splitlines()
    video_exts = (".webm", ".mp4", ".m4v", ".ogv", ".ogg", ".mov", ".mkv",
                  ".avi", ".flv", ".wmv")
    assert not [f for f in out if f.lower().endswith(video_exts)], \
        "video binary tracked in git"
    for path in (REPO / "media" / "manifests").glob("*.json"):
        assert path.stat().st_size <= 16 * 1024


def test_fixture_profile_no_audio_resolution_duration_permissions():
    pytest.importorskip("pytest")  # marker for clarity; stdlib otherwise
    run(sys.executable, "scripts/media/build.py", "--fixture")
    clip = BUILD_BASE_DIR / "ar-example-sample.mp4"
    assert clip.is_file()
    info = ffprobe_json(clip)
    stream = video_stream(info)
    assert stream["codec_name"] == "h264"
    assert stream["pix_fmt"] == "yuv420p"
    assert int(stream["height"]) <= MAX_HEIGHT
    assert fps_of(stream) <= MAX_FPS + 0.5
    assert not any(s.get("codec_type") == "audio" for s in info["streams"])
    duration = float(info["format"]["duration"])
    assert abs(duration - 4.0) <= 0.6
    mode = clip.stat().st_mode
    assert mode & (stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)
    assert mode & stat.S_IROTH, "sddm user must be able to read runtime files"


def test_package_script_builds_single_base_pack(tmp_path):
    run(sys.executable, "scripts/media/build.py", "--fixture")
    # package.py needs generated catalog files; synthesize minimal ones
    # around the offline fixture (mirrors build --all output shape).
    digest = (BUILD_BASE_DIR / "ar-example-sample.sha256").read_text().split()[0]
    (BUILD_BASE_DIR / "catalog.json").write_text(json.dumps(
        {"version": 1, "pack": "base", "clips": [
            {"id": "ar-example-sample", "file": "ar-example-sample.mp4",
             "sha256": digest}]}) + "\n")
    for name, body in (("catalog.csv", "id,file,sha256\n"),
                       ("MEDIA_LICENSES.md", "# licenses\n"),
                       ("ATTRIBUTION.md", "# attribution\n")):
        (BUILD_BASE_DIR / name).write_text(body)
    run(sys.executable, "scripts/media/package.py", "--version", "0.0.0-test")
    packs = sorted((REPO / "dist").glob("hornero-greeter-media-base-*.tar.zst"))
    assert len(packs) == 1
    out = subprocess.run(["tar", "--zstd", "-tf", str(packs[0])],
                         capture_output=True, text=True)
    names = out.stdout.splitlines()
    expected_video = "hornero-greeter-media-base/base/ar-example-sample.mp4"
    assert expected_video in names
    assert any(n.endswith("catalog.json") for n in names)
    extracted = tmp_path / "media-extracted"
    extracted.mkdir(parents=True)
    run("tar", "--zstd", "-xf", str(packs[0]), "-C", str(extracted),
        "--strip-components=1", "hornero-greeter-media-base/base")
    assert (extracted / "base" / "ar-example-sample.mp4").is_file()
    packs[0].unlink()  # keep the tree clean; dist/ is gitignored anyway


def _load_validator():
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "validate_media_manifests", REPO / "scripts/validate-media-manifests.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_provider_allowlists_single_source_no_drift():
    from common import (CONTAINERS, DAYPARTS, DISTRIBUTION_STATES,  # noqa: E402
                        KNOWN_LICENSES, PROVIDERS)
    validator = _load_validator()
    assert validator.LICENSES == KNOWN_LICENSES
    assert validator.CONTAINERS == CONTAINERS
    assert validator.DAYPARTS == DAYPARTS
    assert validator.PROVIDERS == PROVIDERS
    assert validator.DISTRIBUTION_STATES == DISTRIBUTION_STATES
    schema = json.loads((REPO / "media/manifest.schema.json").read_text())
    props = schema["properties"]
    assert set(props["source"]["properties"]["provider"]["enum"]) == PROVIDERS
    assert set(props["license"]["properties"]["short"]["enum"]) == KNOWN_LICENSES
    assert set(props["original"]["properties"]["container"]["enum"]) == CONTAINERS
    assert set(props["dayparts"]["items"]["enum"]) == DAYPARTS
    assert set(props["review"]["properties"]["distribution"]["enum"]) == DISTRIBUTION_STATES
    assert "mp4" in CONTAINERS and "golden-hour" in DAYPARTS
    assert "Pexels" in KNOWN_LICENSES


def test_commons_regression_existing_manifests_unchanged_meaning():
    from common import is_shippable, provider_of  # noqa: E402
    manifests = load_manifests()
    assert len(manifests) == 10
    for _, data in manifests:
        assert "provider" not in data["source"]  # zero migrated files
        assert provider_of(data) == "wikimedia-commons"
        assert is_shippable(data)


def test_pexels_fixture_shape_and_fail_closed():
    from common import is_shippable, provider_of  # noqa: E402
    import copy
    fixture = json.loads(
        (REPO / "media/candidates/ar-example-pexels-fixture.json").read_text())
    assert provider_of(fixture) == "pexels"
    assert fixture["license"] == {"short": "Pexels", "name": "Pexels License",
                                   "url": "https://www.pexels.com/license/"}
    assert fixture["original"]["container"] == "mp4"
    assert fixture["dayparts"] == ["golden-hour"]
    assert not is_shippable(fixture)
    # Even a shippable review status cannot ship without recorded approval.
    promoted = copy.deepcopy(fixture)
    promoted["review"]["status"] = "written-permission"
    assert not is_shippable(promoted)
    del promoted["review"]["distribution"]  # absent != approved for pexels
    assert not is_shippable(promoted)
    # The approval path exists and is explicit.
    promoted["review"]["distribution"] = "approved"
    assert is_shippable(promoted)
    # The fixture is parked in candidates/, never in the shipped set.
    assert fixture["id"] not in {d["id"] for _, d in load_manifests()}


def test_fetch_refuses_pexels_and_commons_unchanged():
    import fetch as fetch_mod  # noqa: E402 (scripts/media on sys.path)
    fixture = json.loads(
        (REPO / "media/candidates/ar-example-pexels-fixture.json").read_text())
    with pytest.raises(RuntimeError, match="#39"):
        fetch_mod.ensure_fetchable(fixture)
    for _, data in load_manifests():
        fetch_mod.ensure_fetchable(data)  # Commons path passes the gate
