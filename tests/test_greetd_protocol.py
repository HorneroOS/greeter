"""End-to-end greetd IPC: the real C++ client (via the headless
self-test binary) against a scripted greetd double. Skipped when the
binaries have not been built; CI builds them in the greetd job.
"""
import json
import os
import subprocess
from pathlib import Path

import pytest

from fake_greetd import FakeGreetd

REPO_ROOT = Path(__file__).resolve().parent.parent
SELFTEST = REPO_ROOT / "greetd" / "build" / "hornero-greetd-selftest"

pytestmark = pytest.mark.skipif(
    not SELFTEST.exists(), reason="greetd binaries not built (cmake -S greetd -B greetd/build)"
)


def run_conversation(tmp_path, mode, answers, expect_failed=False):
    sock = tmp_path / "greetd.sock"
    fake = FakeGreetd(sock, mode=mode)
    fake.start()
    try:
        proc = subprocess.run(
            [str(SELFTEST), str(sock), "juan", *answers],
            capture_output=True, text=True, timeout=20,
        )
    finally:
        fake.stop()
    events = [json.loads(line) for line in proc.stdout.strip().splitlines() if line.strip()]
    return fake, proc, events


def test_password_flow_starts_session(tmp_path):
    fake, proc, events = run_conversation(tmp_path, "ok", ["mate-2026"])
    assert proc.returncode == 0, proc.stderr
    kinds = [e["event"] for e in events]
    assert kinds == ["auth_message", "auth_success", "session_started"]
    assert events[0]["kind"] == "secret"

    assert fake.requests[0] == {"type": "create_session", "username": "juan"}
    assert fake.requests[1]["type"] == "post_auth_message_response"
    assert fake.requests[1]["response"] == "mate-2026"
    start = fake.requests[2]
    assert start["type"] == "start_session"
    assert start["cmd"] == ["true"]
    assert "XDG_SESSION_TYPE=wayland" in start["env"]


def test_wrong_password_is_an_auth_error(tmp_path):
    fake, proc, events = run_conversation(tmp_path, "ok", ["wrong-pass"])
    assert proc.returncode == 0, proc.stderr
    assert events[-1]["event"] == "error"
    assert events[-1]["error_type"] == "auth_error"
    # A failed conversation must never reach start_session.
    assert all(r["type"] != "start_session" for r in fake.requests)


def test_retry_after_auth_error_on_same_connection(tmp_path):
    # Regression: after a wrong password, a second create_session on the
    # same connection must reach the daemon and be able to succeed
    # (the graphical greeter stalled here on a real seat).
    fake, proc, events = run_conversation(
        tmp_path, "ok", ["wrong-pass", "mate-2026", "--retry"]
    )
    assert proc.returncode == 0, proc.stderr
    kinds = [e["event"] for e in events]
    assert kinds == [
        "auth_message",
        "error",
        "retrying",
        "cancel_ack",
        "auth_message",
        "auth_success",
        "session_started",
    ]
    creates = [r for r in fake.requests if r["type"] == "create_session"]
    assert len(creates) == 2
    assert all(c["username"] == "juan" for c in creates)
    # The failed session must be cancelled before re-creating: real
    # greetd otherwise answers "a session is already being configured".
    order = [r["type"] for r in fake.requests]
    first_create = order.index("create_session")
    cancel = order.index("cancel_session")
    second_create = order.index("create_session", first_create + 1)
    assert first_create < cancel < second_create


def test_two_prompt_conversation(tmp_path):
    fake, proc, events = run_conversation(tmp_path, "two-prompts", ["anything", "123456"])
    assert proc.returncode == 0, proc.stderr
    kinds = [(e["event"], e.get("kind")) for e in events]
    assert kinds == [
        ("auth_message", "secret"),
        ("auth_message", "visible"),
        ("auth_success", None),
        ("session_started", None),
    ]
    responses = [r.get("response") for r in fake.requests if r["type"] == "post_auth_message_response"]
    assert responses == ["anything", "123456"]


def _write_session(directory: Path, subdir: str, filename: str, name: str, comment: str = "") -> None:
    target = directory / subdir
    target.mkdir(parents=True, exist_ok=True)
    lines = [
        "[Desktop Entry]",
        "Type=Application",
        f"Name={name}",
        "Exec=/bin/true",
    ]
    if comment:
        lines.append(f"Comment={comment}")
    (target / filename).write_text("\n".join(lines) + "\n", encoding="utf-8")


def _list_sessions(datadir: Path, include_x11: bool = False) -> list[dict]:
    cmd = [str(SELFTEST), "--list-sessions", str(datadir)]
    if include_x11:
        cmd.append("--include-x11")
    env = {
        "PATH": os.environ.get("PATH", ""),
        "XDG_DATA_DIRS": str(datadir),
        "XDG_DATA_HOME": str(datadir),
    }
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=15, env=env)
    return [json.loads(line) for line in proc.stdout.strip().splitlines() if line.strip()]


def test_session_priority_hornero_then_hyprland_then_stable_then_experimental(tmp_path):
    _write_session(tmp_path, "wayland-sessions", "00-experimental-gaming.desktop", "Gaming (Experimental)")
    _write_session(tmp_path, "wayland-sessions", "hornero-gaming-session.desktop", "HorneroOS Gaming Session (Experimental)")
    _write_session(tmp_path, "wayland-sessions", "cosmic.desktop", "COSMIC")
    _write_session(tmp_path, "wayland-sessions", "hyprland.desktop", "Hyprland")
    _write_session(tmp_path, "wayland-sessions", "hornero-desktop.desktop", "HorneroOS Desktop")

    sessions = _list_sessions(tmp_path)
    assert [s["id"] for s in sessions] == [
        "hornero-desktop",
        "hyprland",
        "cosmic",
        "hornero-gaming-session",
        "00-experimental-gaming",
    ]


def test_session_priority_hyprland_default_when_no_hornero(tmp_path):
    # Even when an experimental entry's Comment (or id) flags it rather than
    # its Name, it must still sort after stable Hyprland and GNOME.
    _write_session(
        tmp_path,
        "wayland-sessions",
        "a-gaming.desktop",
        "Gaming Session",
        comment="Experimental gaming mode",
    )
    _write_session(tmp_path, "wayland-sessions", "gnome.desktop", "GNOME")
    _write_session(tmp_path, "wayland-sessions", "hyprland.desktop", "Hyprland (uwsm-managed)")

    sessions = _list_sessions(tmp_path)
    assert [s["id"] for s in sessions] == ["hyprland", "gnome", "a-gaming"]


def test_session_priority_wayland_before_x11_and_experimental_last(tmp_path):
    _write_session(tmp_path, "wayland-sessions", "sway.desktop", "Sway")
    _write_session(tmp_path, "xsessions", "00-experimental-x11.desktop", "Experimental X11")
    _write_session(tmp_path, "xsessions", "openbox.desktop", "Openbox")

    sessions = _list_sessions(tmp_path, include_x11=True)
    assert [s["id"] for s in sessions] == ["sway", "openbox", "00-experimental-x11"]
