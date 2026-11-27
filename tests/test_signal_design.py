"""Hornero Signal contract for the greeter (RFC 0001 + amendment 2, Signal
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

# RFC 0001 §3.2, Signal Night column (factory default), with amendment 2
# (ruleStrong #707A85, optional glow role).
RFC_NIGHT = {
    "ground": "#0C0F13", "sunken": "#101419", "base": "#13171D",
    "panel": "#181D24", "raised": "#1F252E", "lifted": "#283039",
    "ink": "#ECE6DA", "inkMuted": "#A8ABAD", "inkFaint": "#737980",
    "rule": "#2C333C", "ruleStrong": "#707A85", "focus": "#7EC1EA",
    "signal": "#F2A33A", "onSignal": "#1A1205", "signalWell": "#3A2A12",
    "onSignalWell": "#FFD9A3", "cue": "#7EC1EA", "onCue": "#06151F",
    "cueWell": "#16303F", "onCueWell": "#CDE8F8", "phosphor": "#8BD49A",
    "onPhosphor": "#07170C", "phosphorWell": "#173222",
    "onPhosphorWell": "#CDEFD4", "alert": "#F0705A", "onAlert": "#1E0905",
    "alertWell": "#3D1A14", "onAlertWell": "#FFD3CA", "inverse": "#ECE6DA",
    "onInverse": "#181D24", "inverseSignal": "#8A5200", "scrim": "#000000",
    "shadow": "#000000", "glow": "#FFB650",
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


# HorneroOS/config profiles/themes/hornero-signal-day/theme.json palette.
CONFIG_DAY = {
    "ground": "#E6E1D5", "sunken": "#DCD6C8", "base": "#F2EEE5",
    "panel": "#F7F4EE", "raised": "#FBF9F5", "lifted": "#FFFFFF",
    "ink": "#1B1E22", "inkMuted": "#4E545B", "inkFaint": "#7A8086",
    "rule": "#D3CCBD", "ruleStrong": "#736D62", "signal": "#8F4B00",
    "onSignal": "#FFFFFF", "signalWell": "#F6DDB8", "onSignalWell": "#3D2200",
    "cue": "#1A5F88", "onCue": "#FFFFFF", "cueWell": "#D3E7F3",
    "onCueWell": "#0B2E44", "phosphor": "#256A3B", "onPhosphor": "#FFFFFF",
    "phosphorWell": "#D5EBD9", "onPhosphorWell": "#0E2E17", "alert": "#A8341C",
    "onAlert": "#FFFFFF", "alertWell": "#F7D7D0", "onAlertWell": "#4A1209",
    "inverse": "#1B1E22", "onInverse": "#F2EEE5", "inverseSignal": "#F2A33A",
    "scrim": "#000000", "shadow": "#000000", "focus": "#1A5F88", "glow": "#8F4B00",
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
    assert hc["ground"] == "#000000" and hc["ink"] == "#FFFFFF"
    assert hc["signal"] == "#FFC247" and hc["cue"] == "#8FD3FF"
    assert hc["ruleStrong"] == "#FFFFFF"


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
    assert contrast(p["onSignal"], p["signal"]) >= 4.5


@pytest.mark.parametrize("palette", ["night", "day", "contrast"])
def test_boundaries_and_focus_pass_three_to_one(tokens, palette):
    p = tokens[palette]
    for surface in ("sunken", "base", "panel"):
        assert contrast(p["ruleStrong"], p[surface]) >= 3, (palette, surface)
        assert contrast(p["focus"], p[surface]) >= 3, (palette, surface)


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
