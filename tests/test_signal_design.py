"""Hornero Signal contract for the greeter (RFC 0001 + amendment 3, Signal
Visual Language "Signal Bezel", HorneroOS/docs).

Pins the token values to the RFC, checks WCAG contrast for every text and
boundary pairing the greeter draws, and keeps Material / legacy upstream
controls from returning.
"""
import configparser
import json
import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = REPO_ROOT / "components"
SIGNAL_JS = COMPONENTS / "Signal.js"
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
QML_FILES = [REPO_ROOT / "Main.qml", *sorted(COMPONENTS.glob("*.qml"))]
RUNTIME_TEXT = "\n".join(p.read_text(encoding="utf-8") for p in QML_FILES + [SIGNAL_JS])

# RFC 0001 §3.2, Signal Night column (factory default), with amendment 3
# (blue-hour graphite Night, ruleStrong #8393A6, optional glow role).
RFC_NIGHT = {
    "ground": "#0C1016", "sunken": "#10151C", "base": "#141B24",
    "panel": "#1B2430", "raised": "#24303D", "lifted": "#2C3947",
    "ink": "#E6EBF1", "inkMuted": "#A9B7C6", "inkFaint": "#8999AB",
    "rule": "#2D3B4B", "ruleStrong": "#8393A6", "focus": "#8BCEF0",
    "signal": "#F2AC52", "onSignal": "#1E1304", "signalWell": "#3D2B12",
    "onSignalWell": "#FFE0B0", "cue": "#8BCEF0", "onCue": "#071A26",
    "cueWell": "#163345", "onCueWell": "#D6EFFC", "phosphor": "#8DDBAF",
    "onPhosphor": "#071D12", "phosphorWell": "#153425",
    "onPhosphorWell": "#D1F5E0", "alert": "#FF8494", "onAlert": "#24070C",
    "alertWell": "#421922", "onAlertWell": "#FFD6DC", "inverse": "#E6EBF1",
    "onInverse": "#1B2430", "inverseSignal": "#864700", "scrim": "#000000",
    "shadow": "#000000", "glow": "#FFC06B",
}

FORBIDDEN = (
    "MaterialIcon", "Material Symbols", "materialyoucolor", "m3primary",
    "m3surface", "M3Palette", "QtQuick.Controls.Material",
)

LEGACY_CONTROLS = re.compile(r"^\s*(TextBox|PasswordBox|ComboBox|ImageButton|Button)\s*\{", re.MULTILINE)
UPSTREAM_COLOURS = ("#dc322f", "#e0342c", "#393939", "#268bd2", "#2aa198", "#5692c4")


def _palettes():
    script = (
        "const fs=require('fs');const vm=require('vm');"
        f"const src=fs.readFileSync({json.dumps(str(SIGNAL_JS))},'utf8').replace('.pragma library','');"
        "const ctx={};vm.createContext(ctx);vm.runInContext(src,ctx);"
        "process.stdout.write(JSON.stringify({night:ctx.NIGHT,day:ctx.DAY,contrast:ctx.CONTRAST,"
        "pick:[ctx.palette(false,false)===ctx.NIGHT,ctx.palette(false,true)===ctx.DAY,ctx.palette(true,true)===ctx.CONTRAST],"
        "scheme:[ctx.isLight('auto',0),ctx.isLight('auto',1),ctx.isLight('auto',2),ctx.isLight('day',2),ctx.isLight('night',1)],"
        "fonts:[ctx.FONT_SANS,ctx.FONT_MONO,ctx.FONT_DISPLAY],dur:ctx.DURATION,"
        "reduced:[ctx.duration('scan',true),ctx.fadeDuration('medium',true),ctx.fadeDuration('medium',false)]}))"
    )
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True, timeout=30)
    return json.loads(out.stdout)


@pytest.fixture(scope="module")
def tokens():
    return _palettes()


def _lum(hex_colour):
    channels = [int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def test_night_palette_matches_rfc(tokens):
    assert tokens["night"] == RFC_NIGHT


# HorneroOS/config profiles/themes/hornero-signal-day/theme.json palette (RFC 0001 Amendment 3).
CONFIG_DAY = {
    "ground": "#E8EDF4", "sunken": "#E0E6EF", "base": "#EEF2F7",
    "panel": "#F5F8FC", "raised": "#FCFCFE", "lifted": "#FFFFFF",
    "ink": "#283344", "inkMuted": "#505E70", "inkFaint": "#606D80",
    "rule": "#D2DAE6", "ruleStrong": "#7A8798", "signal": "#864700",
    "onSignal": "#FFFFFF", "signalWell": "#FCE9C8", "onSignalWell": "#432300",
    "cue": "#145D86", "onCue": "#FFFFFF", "cueWell": "#D8EEF9",
    "onCueWell": "#0B334B", "phosphor": "#1E6448", "onPhosphor": "#FFFFFF",
    "phosphorWell": "#D6F4E8", "onPhosphorWell": "#0E3425", "alert": "#9C293E",
    "onAlert": "#FFFFFF", "alertWell": "#FADDE4", "onAlertWell": "#4E111E",
    "inverse": "#283344", "onInverse": "#F5F8FC", "inverseSignal": "#F2AC52",
    "scrim": "#000000", "shadow": "#000000", "focus": "#145D86", "glow": "#864700",
}

# HorneroOS/config profiles/themes/hornero-signal-contrast/theme.json palette (RFC 0001 Amendment 3).
CONFIG_CONTRAST = {
    "ground": "#000000", "sunken": "#050607", "base": "#0A0C0F",
    "panel": "#101317", "raised": "#181C21", "lifted": "#22272E",
    "ink": "#FFFFFF", "inkMuted": "#D9DCDF", "inkFaint": "#9DA3A9",
    "rule": "#5C646D", "ruleStrong": "#FFFFFF", "signal": "#FFC247",
    "onSignal": "#000000", "signalWell": "#3D2C00", "onSignalWell": "#FFE6B0",
    "cue": "#8FD3FF", "onCue": "#000000", "cueWell": "#0B2B3D",
    "onCueWell": "#DDF2FF", "phosphor": "#8CF0A4", "onPhosphor": "#000000",
    "phosphorWell": "#0E3319", "onPhosphorWell": "#D4FADE", "alert": "#FF8A73",
    "onAlert": "#000000", "alertWell": "#45120A", "onAlertWell": "#FFDCD4",
    "inverse": "#FFFFFF", "onInverse": "#000000", "inverseSignal": "#7A4A00",
    "scrim": "#000000", "shadow": "#000000", "focus": "#8FD3FF", "glow": "#FFC247",
}


def test_day_palette_matches_config(tokens):
    assert tokens["day"] == CONFIG_DAY


def test_palette_selection_and_scheme_preference(tokens):
    # High Contrast wins; Day only for an explicit or reported light
    # preference; an unknown platform preference stays on Night.
    assert tokens["pick"] == [True, True, True]
    assert tokens["scheme"] == [False, True, False, True, False]


def test_contrast_palette_has_every_role_and_rfc_anchors(tokens):
    hc = tokens["contrast"]
    assert set(hc) == set(RFC_NIGHT)
    assert hc == CONFIG_CONTRAST


@pytest.mark.parametrize("palette", ["night", "day", "contrast"])
def test_text_roles_pass_aa_on_greeter_surfaces(tokens, palette):
    p = tokens[palette]
    for surface in ("ground", "sunken", "base", "panel", "raised", "lifted"):
        assert contrast(p["ink"], p[surface]) >= 4.5, (palette, "ink", surface)
        assert contrast(p["inkMuted"], p[surface]) >= 4.5, (palette, "inkMuted", surface)
    for surface in ("sunken", "panel"):
        assert contrast(p["signal"], p[surface]) >= 4.5, (palette, "signal", surface)
        assert contrast(p["alert"], p[surface]) >= 4.5, (palette, "alert", surface)
        assert contrast(p["cue"], p[surface]) >= 4.5, (palette, "cue", surface)
        assert contrast(p["phosphor"], p[surface]) >= 4.5, (palette, "phosphor", surface)
    for fg, bg in (
        ("onSignal", "signal"),
        ("onCue", "cue"),
        ("onPhosphor", "phosphor"),
        ("onAlert", "alert"),
        ("onSignalWell", "signalWell"),
        ("onCueWell", "cueWell"),
        ("onPhosphorWell", "phosphorWell"),
        ("onAlertWell", "alertWell"),
        ("onInverse", "inverse"),
    ):
        assert contrast(p[fg], p[bg]) >= 4.5, (palette, fg, bg)


@pytest.mark.parametrize("palette", ["night", "day", "contrast"])
def test_boundaries_and_focus_pass_three_to_one(tokens, palette):
    p = tokens[palette]
    for surface in ("base", "panel", "lifted"):
        assert contrast(p["ruleStrong"], p[surface]) >= 3, (palette, surface)
    for surface in ("ground", "sunken", "base", "panel", "raised", "lifted"):
        assert contrast(p["focus"], p[surface]) >= 3, (palette, surface)


def test_ink_faint_reserved_for_disabled_and_decorative():
    # RFC 0001 §3.1: inkFaint is for disabled/decorative use only, never
    # readable text (captions, eyebrows, placeholders, metadata).
    assert "inkFaint" not in MAIN
    greetd_main = (REPO_ROOT / "greetd" / "qml" / "Main.qml").read_text(encoding="utf-8")
    faint_lines = [line.strip() for line in greetd_main.splitlines() if "inkFaint" in line]
    assert faint_lines == [
        "color: (noSessions || !backend.daemonConnected) ? sig.inkFaint : sig.onSignal"
    ]


def test_plex_families(tokens):
    assert tokens["fonts"] == ["IBM Plex Sans", "IBM Plex Mono", "IBM Plex Sans Condensed"]
    for family in ("Signal.FONT_SANS", "Signal.FONT_MONO", "Signal.FONT_DISPLAY"):
        assert family in RUNTIME_TEXT
    # Only the token module names font families (SDDM and greetd QML alike).
    for path in QML_FILES + [REPO_ROOT / "greetd" / "qml" / "Main.qml"]:
        text = path.read_text(encoding="utf-8")
        assert 'font.family: "' not in text, path.name
        assert not re.search(r'family:\s*"', text), path.name


def test_motion_tokens_and_reduced_motion(tokens):
    assert tokens["dur"] == {
        "quick": 90, "short": 160, "medium": 240, "long": 360, "scan": 480,
        "settle": 320, "settleFast": 220,
    }
    scan_reduced, fade_reduced, fade_full = tokens["reduced"]
    assert scan_reduced == 0
    assert fade_reduced == 90
    assert fade_full == 240


def test_motion_uses_named_curves_and_settle_only_moves_geometry():
    # Signal Visual Language §11: only RFC curve names; settle curves
    # animate position/size, never opacity or colour.
    for banned in ("OutBounce", "OutElastic", "OutBack", "easing.overshoot"):
        assert banned not in RUNTIME_TEXT, banned
    for path in QML_FILES:
        text = path.read_text(encoding="utf-8")
        for block in re.findall(r"Behavior on (\w+) \{(.*?)\n\s*\}\n\s*\}", text, re.DOTALL):
            prop, body = block
            if "CURVE.settle" in body:
                assert prop in ("x", "y", "width", "height"), (path.name, prop)


def test_glow_is_rationed():
    # §9: one glowing item, the clock's signal hairline (as on the lock
    # screen): static, <= 40 % alpha, <= 4 px blur, off in High Contrast
    # and on paper (Day).
    users = [p.name for p in QML_FILES if "sig.glow" in p.read_text(encoding="utf-8")]
    assert users == ["Main.qml"]
    assert MAIN.count("sig.glow") == 1
    block = MAIN.split("The one accent", 1)[1].split("id: accent", 1)[0]
    assert "blur: 4" in block and "spread: 0" in block
    assert "Signal.alpha(container.sig.glow, 0.4)" in block
    assert "visible: !container.highContrast && !container.light" in block
    assert "Behavior" not in block and "Animation" not in block


def test_no_material_or_legacy_controls():
    for token in FORBIDDEN:
        assert token not in RUNTIME_TEXT, token
    for path in QML_FILES:
        text = path.read_text(encoding="utf-8")
        assert not LEGACY_CONTROLS.search(text), path.name
        assert "import QtQuick.Controls" not in text, path.name
    for colour in UPSTREAM_COLOURS:
        assert colour.lower() not in RUNTIME_TEXT.lower(), colour


def test_colours_come_from_tokens():
    # Hex literals live only in Signal.js (and Glyph's neutral default).
    for path in QML_FILES:
        text = path.read_text(encoding="utf-8")
        literals = re.findall(r'"#[0-9A-Fa-f]{6,8}"', text)
        allowed = ['"#ECE6DA"', '"#F2A33A"'] if path.name in ("Glyph.qml", "DiagonalHatch.qml", "HorneroMark.qml") else []
        assert all(lit in allowed for lit in literals), (path.name, literals)


def test_glyph_names_used_exist():
    glyph = (COMPONENTS / "Glyph.qml").read_text(encoding="utf-8")
    known = set(re.findall(r'^\s*"([a-z-]+)":\s*"M', glyph, re.MULTILINE))
    used = set(re.findall(r'(?:glyph|name|trailingGlyph):\s*"([a-z-]+)"', RUNTIME_TEXT))
    used |= {"chevron-up", "chevron-down"}
    assert used <= known, used - known


def test_registration_tick_and_scan_in_present():
    assert "Registration tick" in MAIN
    assert "Scan-in" in MAIN
    assert "Signal.CURVE.sweep" in MAIN


def test_legacy_theme_keys_removed():
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / "theme.conf", encoding="utf-8")
    conf = parser["General"]
    for key in (
        "displayFont", "clockFontColor", "labelFontColor", "errorMsgFontColor",
        "actionBarFontColor", "brandingAccent", "clockFontSize",
        "relativePositionX", "relativePositionY", "showClearPasswordButton",
    ):
        assert key not in conf, key
        assert f"config.{key}" not in MAIN, key
    assert conf["reducedMotion"] == "false"


def test_legacy_assets_removed():
    for name in ("reboot.svg", "shutdown.svg", "warning_red.png"):
        assert not (COMPONENTS / "resources" / name).exists()
    for name in ("WallpaperFader.qml", "KeyboardToggle.qml", "MediaDeck.qml", "OnAirChip.qml", "DayScale.qml", "MediaCatalog.js"):
        assert not (COMPONENTS / name).exists()
