"""Signal greeter design contract: light on CPU/GPU (it runs before login
on any hardware), the lock-screen family resemblance, and motion that
honours reduced motion."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")
COMPONENTS = REPO_ROOT / "components"
FIELD = (COMPONENTS / "HorizonField.qml").read_text(encoding="utf-8")
SPRITE = (COMPONENTS / "HorneroSprite.qml").read_text(encoding="utf-8")
QML = {p.name: p.read_text(encoding="utf-8") for p in [REPO_ROOT / "Main.qml", *COMPONENTS.glob("*.qml")]}


def test_no_continuous_animation_anywhere():
    # No infinite or free-running animations: motion is one-shot reveals,
    # state transitions, a 1 Hz ambient step and a 7 s blink.
    for name, text in QML.items():
        assert "Animation.Infinite" not in text, name
        assert not re.search(r"(Number|Color|Sequential|Parallel)Animation on \w+", text), name
        assert "FrameAnimation" not in text, name
        assert "ShaderEffect" not in text, name


def test_timers_are_slow():
    for name, text in QML.items():
        for interval in re.findall(r"interval:\s*(\d+)", text):
            assert int(interval) >= 60, (name, interval)
    # Repeating timers tick at most once per second.
    for name, text in QML.items():
        for block in re.findall(r"Timer \{(.*?)\n\s*\}", text, re.DOTALL):
            if "repeat: true" in block:
                assert int(re.search(r"interval:\s*(\d+)", block).group(1)) >= 1000, (name, block)


def test_background_paints_once_into_an_image():
    assert "renderTarget: Canvas.Image" in FIELD
    # Repaints only on size, palette, seed or contrast changes.
    triggers = set(re.findall(r"on(\w+)Changed: canvas.requestPaint\(\)", FIELD))
    triggers |= set(re.findall(r"on(\w+)Changed: requestPaint\(\)", FIELD))
    assert triggers == {"Width", "Height", "Sig", "Seed", "HighContrast"}, triggers
    # Deterministic: a seeded PRNG, never Math.random.
    assert "Math.random" not in FIELD
    assert "mulberry32" in FIELD


def test_ambient_motion_is_gated():
    assert "running: field.ambient && !field.reducedMotion && !field.highContrast && field.visible" in FIELD
    assert "interval: 1000" in FIELD
    assert 'ambient: config.backgroundMotion != "false" && container.isPrimary' in MAIN
    assert "running: root.visible && !root.reducedMotion" in SPRITE


def test_lock_screen_family_resemblance():
    # Same clock language as modules/lock/Center.qml: condensed numerals,
    # a muted colon, one signal hairline, an uppercase mono date, Javi's
    # greeting in the shell's two voices.
    assert "Signal.FONT_DISPLAY" in MAIN and "font.weight: Font.Medium" in MAIN
    assert 'text: ":"\n                            color: container.sig.inkMuted' in MAIN
    assert "The one accent" in MAIN
    assert ".toUpperCase()" in MAIN and "Signal.FONT_MONO" in MAIN
    assert "HorneroSprite {" in MAIN
    assert '(container.cozy ? "greeting." : "greetingPlain.")' in MAIN


def test_slate_family_resemblance():
    # Shares the reload-cover slate's ident and dial vocabulary.
    mark = (COMPONENTS / "HorneroMark.qml").read_text(encoding="utf-8")
    assert "ctx.arc(12 * k, 12 * k, 9.5 * k" in mark
    assert "HorneroMark {" in MAIN
    assert "dial scale" in FIELD


def test_compact_layouts_switch_instead_of_overflowing():
    assert "readonly property bool split:" in MAIN
    assert "virtualKeyboard.height" in MAIN


def test_channel_tiles_fit_or_scroll():
    strip = (COMPONENTS / "ChannelStrip.qml").read_text(encoding="utf-8")
    assert "Math.max(92 * fontScale, Math.min(116 * fontScale" in strip
    assert "interactive: contentWidth > width" in strip
