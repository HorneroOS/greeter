"""Exercise the real components/MediaCatalog.js logic through node."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
JS_LIB = REPO_ROOT / "components" / "MediaCatalog.js"

NODE = shutil.which("node")
pytestmark = pytest.mark.skipif(NODE is None, reason="node not installed")

HARNESS = """
const fs = require("fs");
let src = fs.readFileSync(%s, "utf8");
src = src.split("\\n").filter(l => !l.startsWith(".pragma")).join("\\n");
const Catalog = new Function(src + "\\nreturn { clampCrossfade, isDay, isLocalRelativePath, validateCatalog, entriesForDaypart, resolveEntries, createSequencer, MIN_CROSSFADE_MS, MAX_CROSSFADE_MS, DEFAULT_CROSSFADE_MS, TEST_SEED };")();
const out = {};
%s
console.log(JSON.stringify(out));
"""


def run_js(body):
    script = HARNESS % (json.dumps(str(JS_LIB)), body)
    proc = subprocess.run([NODE, "-e", script], capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_clamp_crossfade_bounds():
    out = run_js("out.v = [Catalog.clampCrossfade(3000), Catalog.clampCrossfade(500), Catalog.clampCrossfade(9999), Catalog.clampCrossfade('nope'), Catalog.clampCrossfade(2000), Catalog.clampCrossfade(4000)];")
    assert out["v"] == [3000, 2000, 4000, 3000, 2000, 4000]


def test_is_day_boundaries_match_upstream_semantics():
    out = run_js("out.v = [Catalog.isDay(7, 7, 19), Catalog.isDay(19, 7, 19), Catalog.isDay(6, 7, 19), Catalog.isDay(20, 7, 19), Catalog.isDay(12, 7, 19)];")
    assert out["v"] == [True, True, False, False, True]


def test_validate_accepts_shipped_catalog():
    raw = json.loads((REPO_ROOT / "media" / "catalog.json").read_text())
    out = run_js("const raw = %s; out.r = Catalog.validateCatalog(raw);" % json.dumps(raw))
    assert out["r"]["ok"] is True, out["r"]["errors"]


def test_validate_rejects_dup_ids_and_remote_urls():
    body = """
const raw = {version: 1, fallbackImage: "background.jpg", dayparts: {day: [
  {id: "a", file: "media/pack/day/a.mp4", daypart: "day", kind: "video"},
  {id: "a", file: "http://evil/x.mp4", daypart: "day", kind: "video"}
], night: []}};
out.r = Catalog.validateCatalog(raw);
"""
    out = run_js(body)
    assert out["r"]["ok"] is False
    assert any("duplicates" in e for e in out["r"]["errors"])
    assert any(".file" in e for e in out["r"]["errors"])


def test_deterministic_test_mode_repeats():
    body = """
const entries = [{id: "a"}, {id: "b"}, {id: "c"}, {id: "d"}];
const s1 = Catalog.createSequencer(entries, {seed: Catalog.TEST_SEED});
const s2 = Catalog.createSequencer(entries, {seed: Catalog.TEST_SEED});
out.a = Array.from({length: 8}, () => s1.next().id);
out.b = Array.from({length: 8}, () => s2.next().id);
"""
    out = run_js(body)
    assert out["a"] == out["b"]


def test_no_immediate_repeat_with_multiple_entries():
    body = """
const entries = [{id: "a"}, {id: "b"}, {id: "c"}];
const s = Catalog.createSequencer(entries, {seed: 7});
out.seq = Array.from({length: 30}, () => s.next().id);
"""
    out = run_js(body)
    seq = out["seq"]
    assert all(a != b for a, b in zip(seq, seq[1:]))


def test_broken_entries_skipped_with_bounded_retry_then_excluded():
    body = """
const entries = [{id: "good"}, {id: "bad"}];
const s = Catalog.createSequencer(entries, {seed: 1, maxErrors: 2});
for (let i = 0; i < 3; i++) s.reportBroken("bad");
out.pending = s.pending();
const seen = new Set(Array.from({length: 6}, () => s.next().id));
out.seen = [...seen];
"""
    out = run_js(body)
    assert out["pending"] == 1
    assert out["seen"] == ["good"]


def test_local_path_gate_rejects_remote_home_and_absolute():
    out = run_js("out.v = ['media/pack/day/a.mp4', 'background.jpg', 'http://x/y.mp4', 'https://x/y.mp4', '/etc/passwd', '~/x.mp4', '$HOME/x.mp4', '../evil.mp4', ''].map(Catalog.isLocalRelativePath);")
    assert out["v"] == [True, True, False, False, False, False, False, False, False]


def test_empty_catalog_yields_null():
    out = run_js("out.v = Catalog.createSequencer([], {}).next();")
    assert out["v"] is None


def test_daypart_filtering_includes_any():
    body = """
const raw = {version: 1, fallbackImage: "background.jpg", dayparts: {day: [
  {id: "d1", file: "d.mp4", daypart: "day", kind: "video"},
  {id: "x", file: "x.mp4", daypart: "any", kind: "video"}
], night: [{id: "n1", file: "n.mp4", daypart: "night", kind: "video"}]}};
out.day = Catalog.resolveEntries(raw, "day", f => "u:" + f).map(e => e.id).sort();
out.night = Catalog.resolveEntries(raw, "night", f => "u:" + f).map(e => e.id).sort();
out.url = Catalog.resolveEntries(raw, "day", f => "u:" + f).find(e => e.id === "d1").url;
"""
    out = run_js(body)
    assert out["day"] == ["d1", "x"]
    assert out["night"] == ["n1", "x"]
    assert out["url"] == "u:d.mp4"
