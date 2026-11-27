"""Workflow hygiene contract: least-privilege permissions, concurrency, timeouts."""
import re
from pathlib import Path

WORKFLOWS = sorted((Path(__file__).resolve().parent.parent / ".github" / "workflows").glob("*.yml"))


def test_workflows_have_permissions_concurrency_and_timeouts():
    assert WORKFLOWS, "no workflow files found"
    for path in WORKFLOWS:
        text = path.read_text(encoding="utf-8")
        assert "permissions:" in text, path.name
        assert "contents: read" in text, path.name
        assert "concurrency:" in text, path.name
        assert "group:" in text, path.name
        # Non-reusable jobs (those declaring runs-on) must set timeout-minutes.
        runs_on_count = len(re.findall(r"^\s+runs-on:", text, re.MULTILINE))
        timeout_count = len(re.findall(r"^\s+timeout-minutes:", text, re.MULTILINE))
        assert timeout_count == runs_on_count, (
            f"{path.name}: expected {runs_on_count} timeout-minutes, found {timeout_count}"
        )
