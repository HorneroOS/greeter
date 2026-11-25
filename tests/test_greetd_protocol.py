"""End-to-end greetd IPC: the real C++ client (via the headless
self-test binary) against a scripted greetd double. Skipped when the
binaries have not been built; CI builds them in the greetd job.
"""
import json
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
