"""Every runtime file must be readable by the sddm user."""
import os
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

RUNTIME_PATHS = [
    REPO_ROOT / "Main.qml",
    REPO_ROOT / "theme.conf",
    REPO_ROOT / "theme.conf.user",
    REPO_ROOT / "metadata.desktop",
    REPO_ROOT / "background.jpg",
    REPO_ROOT / "media" / "catalog.json",
    REPO_ROOT / "LICENSE",
    *sorted((REPO_ROOT / "components").glob("*.qml")),
    *sorted((REPO_ROOT / "components").glob("*.js")),
    *sorted((REPO_ROOT / "components" / "resources").iterdir()),
]


def test_runtime_files_exist_and_world_readable():
    assert len(RUNTIME_PATHS) > 10
    for path in RUNTIME_PATHS:
        assert path.is_file(), f"missing: {path}"
        mode = os.stat(path).st_mode
        assert mode & 0o044 == 0o044, f"not world-readable: {path} ({oct(mode)})"


def test_runtime_dirs_world_traversable():
    for path in (REPO_ROOT, REPO_ROOT / "components", REPO_ROOT / "media"):
        mode = os.stat(path).st_mode
        assert mode & 0o011 == 0o011, f"not traversable: {path}"
