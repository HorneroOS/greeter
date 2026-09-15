"""Zero-network / zero-legacy offline guarantees for every runtime file."""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

# metadata.desktop keeps a Website string (repo URL; upstream authorship
# lives in Author/NOTICE/UPSTREAM.md); SDDM never fetches it, so it is
# exempt from the URL ban but not from the other bans.
NO_NETWORK_FILES = sorted(
    [REPO_ROOT / "Main.qml"]
    + list((REPO_ROOT / "components").glob("*.qml"))
    + list((REPO_ROOT / "components").glob("*.js"))
    + [REPO_ROOT / "media" / "catalog.json"]
    + [REPO_ROOT / "media" / "catalog.js"]
    + [REPO_ROOT / "theme.conf"]
)

RUNTIME_FILES = sorted(NO_NETWORK_FILES + [REPO_ROOT / "metadata.desktop"])

REMOTE_RE = re.compile(r"https?://")
QT5_IMPORT_RE = re.compile(
    r"import\s+Qt(Quick|Multimedia|GraphicalEffects)[\s.]*[1-5]"
)
QT5_MODULE_RE = re.compile(r"import\s+QtGraphicalEffects")
CONTROLS1_RE = re.compile(r"import\s+QtQuick\.Controls\s+1\.")
PLAYLIST_RE = re.compile(r"\b(QMediaPlaylist|Playlist\s*\{)")
SHELL_EXEC_RE = re.compile(
    r"\b(System\.exec|execute\s*\(|runCommand|getenv\s*\(|WorkerScript\s*\{)"
)
HOME_RE = re.compile(r"(\$HOME|~/|\.dotfiles)")


@pytest.fixture(scope="module", params=[str(p) for p in RUNTIME_FILES], ids=[p.name for p in RUNTIME_FILES])
def runtime_text(request):
    path = Path(request.param)
    assert path.is_file(), f"runtime file missing: {path}"
    return path.read_text(encoding="utf-8")


@pytest.fixture(scope="module", params=[str(p) for p in NO_NETWORK_FILES], ids=[p.name for p in NO_NETWORK_FILES])
def offline_text(request):
    path = Path(request.param)
    assert path.is_file(), f"runtime file missing: {path}"
    return path.read_text(encoding="utf-8")


def test_no_qt5_versioned_imports(runtime_text):
    assert not QT5_IMPORT_RE.search(runtime_text), "Qt5 versioned import found"
    assert not QT5_MODULE_RE.search(runtime_text), "QtGraphicalEffects import found"
    assert not CONTROLS1_RE.search(runtime_text), "QtQuick.Controls 1.x import found"


def test_no_playlist_api(runtime_text):
    assert not PLAYLIST_RE.search(runtime_text), "Playlist/QMediaPlaylist must not survive the Qt6 port"


def test_no_shell_exec_or_env_probes(runtime_text):
    assert not SHELL_EXEC_RE.search(runtime_text)


def _code_body(text):
    # Attribution headers above the first import/pragma (e.g. the GPL notice
    # URL) are not runtime code; the network ban applies below them.
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("import ") or line.startswith(".pragma"):
            return "\n".join(lines[i:])
    return text


def test_no_remote_urls_in_runtime(offline_text):
    assert not REMOTE_RE.search(_code_body(offline_text))


def test_no_home_or_dotfile_references(runtime_text):
    # components/MediaCatalog.js implements the ban itself (it rejects $HOME
    # paths); that logic is covered functionally in test_sequencer_js.py.
    if "function isLocalRelativePath" in runtime_text:
        return
    assert not HOME_RE.search(runtime_text)


def test_no_remote_playlists_left_behind():
    assert not (REPO_ROOT / "playlists").exists()


def test_no_xhr_for_local_files():
    # Qt disables XMLHttpRequest GET on local files by default: an
    # XHR-loaded catalog silently never arrives and no video ever plays.
    # The runtime catalog must be imported synchronously instead.
    # (The word may appear in comments documenting this ban.)
    main = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
    assert "new XMLHttpRequest" not in main


def test_runtime_catalog_is_generated_module():
    text = (REPO_ROOT / "media" / "catalog.js").read_text(encoding="utf-8")
    assert "var CATALOG" in text
    assert "build-catalog" in text
