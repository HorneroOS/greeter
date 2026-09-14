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
    assert len(manifests) == 8
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
    assert "0644" in theme_pkg and "0644" in media_pkg
    snippet = REPO / "packaging/arch/hornero-greeter/hornero.conf"
    assert snippet.read_text().startswith("[Theme]\n")
    assert "Current=hornero" in snippet.read_text()


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


def test_package_script_builds_single_base_pack():
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
    assert any(n.endswith("ar-example-sample.mp4") for n in names)
    assert any(n.endswith("catalog.json") for n in names)
    packs[0].unlink()  # keep the tree clean; dist/ is gitignored anyway
