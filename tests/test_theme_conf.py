"""theme.conf contract: the Signal greeter's keys, defaults and ranges."""
import configparser
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAIN = (REPO_ROOT / "Main.qml").read_text(encoding="utf-8")


def read_conf(name="theme.conf"):
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(REPO_ROOT / name, encoding="utf-8")
    return parser["General"]


BOOLEANS = (
    "highContrast", "largeText", "reducedMotion", "mascot", "backgroundMotion",
    "showUserChannels", "allowOtherUser", "confirmPower", "virtualKeyboardAvailable",
    "virtualKeyboardEnabled", "showLoginButton", "showTopBar", "autofocusInput",
    "brandingEnabled",
)


def test_every_key_is_read_by_the_theme():
    for key in read_conf():
        assert f"config.{key}" in MAIN, key


def test_choices_and_defaults():
    conf = read_conf()
    assert conf["colorScheme"] == "auto"
    assert conf["language"] == "auto"
    assert conf["voice"] in ("cozy", "plain")
    assert conf["background"] == "horizon"
    for key in BOOLEANS:
        assert conf[key] in ("true", "false"), key
    assert 0.3 <= float(conf["backgroundDim"]) <= 0.9


def test_accessibility_options_are_off_by_default():
    conf = read_conf()
    for key in ("largeText", "highContrast", "reducedMotion", "virtualKeyboardAvailable", "virtualKeyboardEnabled"):
        assert conf[key] == "false", key


def test_power_confirmation_and_channels_on_by_default():
    conf = read_conf()
    assert conf["confirmPower"] == "true"
    assert conf["showUserChannels"] == "true"


def test_user_media_is_opt_in_and_nothing_is_bundled():
    conf = read_conf()
    assert conf["backgroundImage"] == ""
    assert conf["backgroundSeed"] == ""


def test_retired_media_keys_are_gone():
    conf = read_conf()
    for key in (
        "bgImgDay", "bgImgNight", "bgImgGoldenHour", "videoEnabled", "crossfadeDuration",
        "dayTimeStart", "dayTimeEnd", "goldenHourStart", "goldenHourEnd", "testMode",
    ):
        assert key not in conf, key
        assert f"config.{key}" not in MAIN, key


def test_no_remote_references():
    text = (REPO_ROOT / "theme.conf").read_text(encoding="utf-8")
    assert "http://" not in text and "https://" not in text


def test_user_override_is_not_shipped_as_factory_configuration():
    recipe = (REPO_ROOT / "packaging/arch/hornero-greeter/PKGBUILD").read_text(encoding="utf-8")
    assert '"$src/theme.conf.user"' not in recipe
