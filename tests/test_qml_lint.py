"""qmllint gate over every QML file (skipped when qmllint is absent)."""
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
QML_FILES = sorted([REPO_ROOT / "Main.qml", *((REPO_ROOT / "components").glob("*.qml"))])

QMLLINT = shutil.which("qmllint")
pytestmark = pytest.mark.skipif(QMLLINT is None, reason="qmllint not installed")


def qml_import_path():
    for candidate in ("/usr/lib/qt6/qml", "/usr/lib/x86_64-linux-gnu/qt6/qml"):
        if Path(candidate).is_dir():
            return candidate
    return None


@pytest.mark.parametrize("qml", [str(p) for p in QML_FILES], ids=[p.name for p in QML_FILES])
def test_qmllint_clean(qml):
    cmd = [QMLLINT]
    import_path = qml_import_path()
    if import_path:
        cmd += ["-I", import_path]
    cmd.append(qml)
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    assert proc.returncode == 0, f"{qml}:\n{proc.stdout}\n{proc.stderr}"
