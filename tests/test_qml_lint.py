"""qmllint gate over every QML file (skipped when qmllint is absent).

Mirrors scripts/qml-lint.sh tool selection: version-pinned Qt tools from
PySide6-Essentials 6.11.* win (CI installs the same pin) because distro
qmllint versions disagree on warning severity (6.4 fails on warnings
that 6.11 only reports).
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
QML_FILES = sorted([REPO_ROOT / "Main.qml", *((REPO_ROOT / "components").glob("*.qml"))])


def pinned_qmllint():
    try:
        import PySide6

        if PySide6.__version__.startswith("6.11."):
            binary = Path(PySide6.__file__).parent / "qmllint"
            if binary.is_file():
                return str(binary), str(Path(PySide6.__file__).parent / "Qt" / "qml")
    except ImportError:
        pass
    return None, None


def qml_import_paths(extra=None):
    paths = []
    for candidate in ([extra] if extra else []) + ["/usr/lib/qt6/qml", "/usr/lib/x86_64-linux-gnu/qt6/qml"]:
        if candidate and Path(candidate).is_dir():
            paths += ["-I", candidate]
    return paths


_PINNED, _PINNED_QML = pinned_qmllint()
QMLLINT = os.environ.get("QMLLINT_BIN") or _PINNED or shutil.which("qmllint")
pytestmark = pytest.mark.skipif(QMLLINT is None, reason="qmllint not installed")


@pytest.mark.parametrize("qml", [str(p) for p in QML_FILES], ids=[p.name for p in QML_FILES])
def test_qmllint_clean(qml):
    cmd = [QMLLINT] + qml_import_paths(_PINNED_QML) + [qml]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    assert proc.returncode == 0, f"{qml}:\n{proc.stdout}\n{proc.stderr}"
