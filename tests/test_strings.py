"""ES/EN copy: both tables complete, every key the QML uses exists, the
language follows the locale, and the voice rules hold."""
import json
import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
STRINGS = REPO_ROOT / "components" / "Strings.js"
QML = [REPO_ROOT / "Main.qml", *sorted((REPO_ROOT / "components").glob("*.qml"))]


def _run(expr):
    script = (
        "const fs=require('fs');const vm=require('vm');"
        f"const src=fs.readFileSync({json.dumps(str(STRINGS))},'utf8').replace('.pragma library','');"
        "const ctx={};vm.createContext(ctx);vm.runInContext(src,ctx);"
        f"process.stdout.write(JSON.stringify({expr}))"
    )
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True, timeout=30)
    return json.loads(out.stdout)


@pytest.fixture(scope="module")
def tables():
    return _run("{en:ctx.EN,es:ctx.ES}")


def test_both_languages_define_every_key(tables):
    assert set(tables["en"]) == set(tables["es"])


def test_every_key_used_by_the_qml_exists(tables):
    used = set()
    for path in QML:
        text = path.read_text(encoding="utf-8")
        used |= set(re.findall(r'(?:container\.tr|Strings\.t\([^,]+,)\s*\(?\s*"([A-Za-z0-9_.]+)"', text))
        used |= set(re.findall(r'container\.tr\("([A-Za-z0-9_.]+)"\)', text))
    # Keys built at runtime: greeting.<daypart>, greetingPlain.<daypart>,
    # confirm.<kind> and the power labels.
    for part in ("morning", "afternoon", "evening", "night"):
        used |= {f"greeting.{part}", f"greetingPlain.{part}"}
    for kind in ("suspend", "restart", "shutdown"):
        used |= {f"confirm.{kind}", kind}
    # Prefixes completed at runtime ("confirm." + kind) are not keys.
    used = {k for k in used if not k.endswith(".")}
    missing = used - set(tables["en"])
    assert not missing, missing


def test_language_follows_locale_unless_forced():
    got = _run("[ctx.pick('auto','es_AR'),ctx.pick('auto','es'),ctx.pick('auto','en_US'),"
               "ctx.pick('auto',''),ctx.pick('en','es_AR'),ctx.pick('es','en_GB'),ctx.pick('fr','es_ES')]")
    assert got == ["es", "es", "en", "en", "en", "es", "es"]


def test_missing_keys_fall_back_visibly():
    assert _run("[ctx.t('es','login'),ctx.t('de','login'),ctx.t('es','no.such.key')]") == [
        "Ingresar", "Log in", "no.such.key"]


def test_daypart_windows_match_the_shell_microcopy():
    got = _run("[0,4,5,11,12,17,18,22,23].map(ctx.daypart)")
    assert got == ["night", "night", "morning", "morning", "afternoon", "afternoon",
                   "evening", "evening", "night"]


def test_voice_rules(tables):
    # Shell microcopy rules: no exclamation marks, no emoji, short greetings.
    for lang, table in tables.items():
        for key, text in table.items():
            assert "!" not in text and "¡" not in text, (lang, key)
            assert all(ord(ch) < 0x2190 or ch in "…·−" for ch in text), (lang, key)
            if key.startswith("greeting"):
                assert len(text) <= 48, (lang, key)


def test_spanish_uses_voseo(tables):
    es = tables["es"]
    assert es["noResponse"].endswith("Probá de nuevo.")
    assert es["secondary"].startswith("INICIÁ")
