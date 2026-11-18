"""The greeter bundles no third-party photos or videos (user decision,
2026-11-18): the background is generated in code, and a picture or video
is only ever the administrator's own opt-in content."""
import re
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
FIELD = (REPO_ROOT / "components" / "HorizonField.qml").read_text(encoding="utf-8")
PKGBUILD = (REPO_ROOT / "packaging/arch/hornero-greeter/PKGBUILD").read_text(encoding="utf-8")

MEDIA_EXT = re.compile(r"\.(jpe?g|png|gif|webp|avif|bmp|tiff?|mp4|webm|mkv|mov|m4v|ogv|avi)$", re.IGNORECASE)
# Original renders of this theme (scripts/render-matrix.sh) are the only
# raster files allowed in the tree, and never at runtime.
ALLOWED_RASTER_DIRS = ("screens/",)


def tracked_files():
    out = subprocess.run(["git", "ls-files"], cwd=REPO_ROOT, capture_output=True, text=True, check=True)
    return [line for line in out.stdout.splitlines() if line]


def test_no_media_files_outside_screens():
    offenders = [
        f for f in tracked_files()
        if MEDIA_EXT.search(f) and not f.startswith(ALLOWED_RASTER_DIRS)
    ]
    assert offenders == [], offenders


def test_screens_are_documented_original_renders():
    readme = (REPO_ROOT / "screens" / "README.md").read_text(encoding="utf-8")
    assert "render-matrix.sh" in readme
    for f in tracked_files():
        if f.startswith("screens/") and MEDIA_EXT.search(f):
            assert Path(f).name in readme, f


def test_media_pipeline_and_pack_are_gone():
    for path in (
        "media", "scripts/media", "packaging/arch/hornero-greeter-media-base",
        "background.jpg", ".github/workflows/aur-publish-media.yml",
        "docs/PEXELS_PERMISSION_REQUEST.md", "MEDIA_ROADMAP.md", "CONTRIBUTING_MEDIA.md",
    ):
        assert not (REPO_ROOT / path).exists(), path


def test_runtime_references_no_bundled_media():
    runtime = [REPO_ROOT / "Main.qml", REPO_ROOT / "theme.conf", *sorted((REPO_ROOT / "components").glob("*.*"))]
    for path in runtime:
        text = path.read_text(encoding="utf-8")
        for token in ("media/", "catalog.js", "pexels", "wikimedia", "background.jpg", "stills/"):
            assert token.lower() not in text.lower(), (path.name, token)


def test_package_installs_no_media():
    # Only the theme's own preview render (metadata.desktop Screenshot).
    installed = re.findall(r'"\$src/([^"]+)"', PKGBUILD)
    rasters = [p for p in installed if MEDIA_EXT.search(p)]
    assert rasters == ["screens/screenshot.png"], rasters
    assert "media" not in PKGBUILD.split("package()", 1)[1]


def test_background_is_generated_in_code():
    # HorizonField paints with a Canvas and loads no file.
    assert "Canvas {" in FIELD
    for token in ("Image {", "AnimatedImage", "source:", "loadImage"):
        assert token not in FIELD, token
    assert "HorizonField {" in MAIN


def test_user_media_is_opt_in_only():
    # The only image/video sources in Main.qml come from backgroundImage.
    sources = re.findall(r"source:\s*([^\n]+)", MAIN)
    for value in sources:
        assert ("backdropPath" in value or "UserVideo.qml" in value
                or "brandingLogo" in value), value
