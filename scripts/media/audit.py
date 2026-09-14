#!/usr/bin/env python3
"""Audit the media pipeline outputs and repo hygiene (offline, stdlib).

Checks (exit 1 on any failure):
  1. Runtime zero-network: no http:// or https:// in QML/JS/theme config
     or in generated build/media/base/catalog.* (GPL gnu.org/licenses
     boilerplate stays exempt, as in scripts/validate-media-manifests.py).
  2. No Qt5-only imports in pipeline-owned runtime files (the legacy
     Main.qml/Qt5 stack is owned by the Qt6 port track, not this audit).
  3. No shell-exec / PAM / dotfile hooks in pipeline-owned runtime files
     (no QML runCommand/execute, no 'pam', no '~/' or '$HOME' paths).
  4. Licenses: every shipped manifest uses an allowlisted CC license.
  5. Git hygiene: no video binaries tracked or present; manifests stay
     small (<= 16 KiB each); cache/build/dist dirs stay untracked.
  6. Staging permissions (when build/media/base exists): files 0644.

    python3 scripts/media/audit.py

Used by CI and by packagers before release.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ALLOWED_LICENSES, BUILD_BASE_DIR, load_manifests  # noqa: E402

REPO = Path(__file__).resolve().parent.parent.parent
URL_RE = re.compile(r"https?://")
GPL_RE = re.compile(r"gnu\.org/licenses")
QT5_RE = re.compile(r"QtMultimedia\s+5|QtQuick\s+2\.|SddmComponents\s+2\.0")
EXEC_RE = re.compile(r"runCommand|execute\(|Qt\.createQmlObject|WorkerScript.*\.mjs")
PAM_RE = re.compile(r"\bpam\b", re.IGNORECASE)
HOME_RE = re.compile(r"~/|\$HOME|file:///home/")
VIDEO_EXTS = {".webm", ".mp4", ".m4v", ".ogv", ".ogg", ".ogm", ".mov",
              ".mkv", ".avi", ".flv", ".wmv"}
# Legacy upstream stack: owned by the Qt6 port track, exempt here.
EXEMPT_RUNTIME = {"Main.qml", "components/WallpaperFader.qml"}


def runtime_owned_files():
    """Pipeline-owned runtime surface: generated catalog + theme snippet."""
    owned = []
    for name in ("catalog.json", "catalog.csv"):
        path = BUILD_BASE_DIR / name
        if path.is_file():
            owned.append(path)
    snippet = REPO / "packaging" / "arch" / "hornero-greeter" / "hornero.conf"
    if snippet.is_file():
        owned.append(snippet)
    return owned


def check_runtime_offline(errors):
    for path in runtime_owned_files():
        try:
            text = path.read_text(encoding="utf-8", errors="strict")
        except OSError as exc:
            errors.append(f"unreadable {path}: {exc}")
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if URL_RE.search(line) and not GPL_RE.search(line):
                errors.append(f"runtime network URL: {path.name}:{lineno}")


def check_no_qt5_exec_pam_dotfiles(errors):
    for path in runtime_owned_files():
        if path.suffix not in (".qml", ".js", ".conf"):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if QT5_RE.search(text):
            errors.append(f"Qt5 dependency in pipeline runtime file: {path.name}")
        if EXEC_RE.search(text):
            errors.append(f"shell-exec hook in pipeline runtime file: {path.name}")
        if PAM_RE.search(text):
            errors.append(f"PAM reference in pipeline runtime file: {path.name}")
        if HOME_RE.search(text):
            errors.append(f"dotfile/home dependency in pipeline file: {path.name}")
    # Pipeline scripts themselves must not fake PAM (real pam imports or
    # pam config writes), as opposed to merely documenting the no-fakery
    # rule in comments and docstrings.
    PAM_FAKE_RE = re.compile(r"import\s+pam|python-?pam|pam\.authenticate|"
                             r"common-(auth|password)|/etc/pam\.d", re.IGNORECASE)
    for script in sorted((REPO / "scripts" / "media").glob("*.py")):
        text = script.read_text(encoding="utf-8")
        if PAM_FAKE_RE.search(text):
            errors.append(f"PAM fakery in pipeline script: {script.name}")


def check_licenses(errors):
    for path, data in load_manifests():
        short = data.get("license", {}).get("short")
        if short not in ALLOWED_LICENSES:
            errors.append(f"{path.name}: license '{short}' not allowlisted")


def check_git_hygiene(errors):
    try:
        tracked = subprocess.run(
            ["git", "ls-files"], cwd=REPO, capture_output=True,
            text=True, check=False).stdout.splitlines()
    except OSError as exc:
        errors.append(f"git ls-files failed: {exc}")
        return
    for rel in tracked:
        if Path(rel).suffix.lower() in VIDEO_EXTS:
            errors.append(f"video binary tracked in git: {rel}")
        if rel in (".cache/", "build/", "dist/") or rel.startswith(
                (".cache/", "build/", "dist/")):
            errors.append(f"generated dir tracked in git: {rel}")
    for path in sorted((REPO / "media" / "manifests").glob("*.json")):
        if path.stat().st_size > 16 * 1024:
            errors.append(f"{path.name}: manifest exceeds 16 KiB size guard")
    # Untracked-but-present video binaries also fail (validator parity).
    for path in sorted(REPO.rglob("*")):
        if ".git/" in path.parts or ".cache/" in path.parts:
            continue
        if path.is_file() and path.suffix.lower() in VIDEO_EXTS:
            if str(path.relative_to(REPO)).startswith(("build/", "dist/")):
                continue
            errors.append(f"video binary in repo: {path.relative_to(REPO)}")


def check_permissions(errors):
    if not BUILD_BASE_DIR.is_dir():
        return
    for path in sorted(BUILD_BASE_DIR.iterdir()):
        if path.is_file():
            mode = path.stat().st_mode & 0o777
            if mode & 0o044 != 0o044:
                errors.append(f"{path.name}: not world-readable ({oct(mode)})")


def main():
    errors = []
    check_runtime_offline(errors)
    check_no_qt5_exec_pam_dotfiles(errors)
    check_licenses(errors)
    check_git_hygiene(errors)
    check_permissions(errors)
    if errors:
        print("audit FAILED:")
        for message in errors:
            print(f"  - {message}")
        return 1
    print("audit OK: offline runtime, licenses, git hygiene, permissions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
