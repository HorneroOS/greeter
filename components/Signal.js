.pragma library
// Hornero Signal tokens for the greeter (RFC 0001 §3, HorneroOS/docs).
//
// The greeter runs as the sddm user before any session exists, so it cannot
// read the live Chromatic scheme written by horneroctl. It carries the
// factory palettes verbatim instead: Signal Night (default), Signal Day
// (theme.conf colorScheme=day, or auto when the platform reports a light
// preference) and Signal High Contrast (theme.conf highContrast=true). Role names match
// HorneroOS/config profiles/themes/tokens.schema.json (schema v2) exactly;
// values include RFC 0001 amendment 2 (ruleStrong, optional glow role).

var NIGHT = {
    "ground": "#0C0F13",
    "sunken": "#101419",
    "base": "#13171D",
    "panel": "#181D24",
    "raised": "#1F252E",
    "lifted": "#283039",
    "ink": "#ECE6DA",
    "inkMuted": "#A8ABAD",
    "inkFaint": "#737980",
    "rule": "#2C333C",
    "ruleStrong": "#707A85",
    "focus": "#7EC1EA",
    "signal": "#F2A33A",
    "onSignal": "#1A1205",
    "signalWell": "#3A2A12",
    "onSignalWell": "#FFD9A3",
    "cue": "#7EC1EA",
    "onCue": "#06151F",
    "cueWell": "#16303F",
    "onCueWell": "#CDE8F8",
    "phosphor": "#8BD49A",
    "onPhosphor": "#07170C",
    "phosphorWell": "#173222",
    "onPhosphorWell": "#CDEFD4",
    "alert": "#F0705A",
    "onAlert": "#1E0905",
    "alertWell": "#3D1A14",
    "onAlertWell": "#FFD3CA",
    "inverse": "#ECE6DA",
    "onInverse": "#181D24",
    "inverseSignal": "#8A5200",
    "scrim": "#000000",
    "shadow": "#000000",
    // Emission colour for the rationed luminous accent only (Signal Visual
    // Language §9): never text or fill; <= 40 % alpha, <= 4 px blur.
    "glow": "#FFB650"
};

// Signal Day (HorneroOS/config profiles/themes/hornero-signal-day): warm
// technical-drawing paper, ink-black text, burnt-amber signal.
var DAY = {
    "ground": "#E6E1D5",
    "sunken": "#DCD6C8",
    "base": "#F2EEE5",
    "panel": "#F7F4EE",
    "raised": "#FBF9F5",
    "lifted": "#FFFFFF",
    "ink": "#1B1E22",
    "inkMuted": "#4E545B",
    "inkFaint": "#7A8086",
    "rule": "#D3CCBD",
    "ruleStrong": "#736D62",
    "focus": "#1A5F88",
    "signal": "#8F4B00",
    "onSignal": "#FFFFFF",
    "signalWell": "#F6DDB8",
    "onSignalWell": "#3D2200",
    "cue": "#1A5F88",
    "onCue": "#FFFFFF",
    "cueWell": "#D3E7F3",
    "onCueWell": "#0B2E44",
    "phosphor": "#256A3B",
    "onPhosphor": "#FFFFFF",
    "phosphorWell": "#D5EBD9",
    "onPhosphorWell": "#0E2E17",
    "alert": "#A8341C",
    "onAlert": "#FFFFFF",
    "alertWell": "#F7D7D0",
    "onAlertWell": "#4A1209",
    "inverse": "#1B1E22",
    "onInverse": "#F2EEE5",
    "inverseSignal": "#F2A33A",
    "scrim": "#000000",
    "shadow": "#000000",
    "glow": "#8F4B00"
};

// Signal High Contrast: same roles, black ground, white ink, brighter
// signal/cue and a pure white ruleStrong (RFC 0001 §3.2).
var CONTRAST = {
    "ground": "#000000",
    "sunken": "#000000",
    "base": "#000000",
    "panel": "#000000",
    "raised": "#14181D",
    "lifted": "#1F252E",
    "ink": "#FFFFFF",
    "inkMuted": "#E6E6E6",
    "inkFaint": "#B8BCC0",
    "rule": "#8A939C",
    "ruleStrong": "#FFFFFF",
    "focus": "#8FD3FF",
    "signal": "#FFC247",
    "onSignal": "#000000",
    "signalWell": "#3A2A12",
    "onSignalWell": "#FFE2B0",
    "cue": "#8FD3FF",
    "onCue": "#000000",
    "cueWell": "#0E2A3A",
    "onCueWell": "#E2F3FF",
    "phosphor": "#9BE8AA",
    "onPhosphor": "#000000",
    "phosphorWell": "#0F2A18",
    "onPhosphorWell": "#E0F8E5",
    "alert": "#FF8A73",
    "onAlert": "#000000",
    "alertWell": "#3D1A14",
    "onAlertWell": "#FFE1DA",
    "inverse": "#FFFFFF",
    "onInverse": "#000000",
    "inverseSignal": "#7A4600",
    "scrim": "#000000",
    "shadow": "#000000",
    // Glow is never rendered in High Contrast.
    "glow": "#FFC247"
};

// High Contrast always wins; otherwise Day for a light scheme, Night for
// everything else (the factory default).
function palette(highContrast, light) {
    if (highContrast)
        return CONTRAST;
    return light ? DAY : NIGHT;
}

// theme.conf colorScheme -> light? "day" and "night" are explicit; "auto"
// follows the platform preference (Qt.styleHints.colorScheme: 1 = light,
// 2 = dark, 0 = unknown) and falls back to Night when SDDM's platform does
// not report one, which is the common case before any session exists.
function isLight(setting, platformScheme) {
    if (setting === "day")
        return true;
    if (setting === "night")
        return false;
    return platformScheme === 1;
}

// Typography (RFC 0001 §3.3). Families are system fonts from the
// ttf-ibm-plex package; fontconfig falls back to the default sans/mono
// when the package is missing, so the greeter never fails to render.
var FONT_SANS = "IBM Plex Sans";
var FONT_MONO = "IBM Plex Mono";
var FONT_DISPLAY = "IBM Plex Sans Condensed";

var TYPE = {
    "small": 11,
    "smaller": 12,
    "normal": 13,
    "larger": 15,
    "large": 18,
    "extraLarge": 28,
    "display": 56
};

// Geometry (RFC 0001 §3.5): 4 px grid, small radii.
var RADIUS = {
    "small": 3,
    "normal": 5,
    "large": 8
};

var SPACING = {
    "small": 4,
    "smaller": 8,
    "normal": 12,
    "larger": 16,
    "large": 24
};

// Motion (RFC 0001 §3.6 with amendment: settle curves, Signal Visual
// Language §11). Settle curves animate position/size only, never opacity
// or colour, and only for travel under 200 px. Bezier control points for Easing.BezierSpline
// (x1, y1, x2, y2, 1, 1).
var CURVE = {
    "standard": [0.2, 0, 0, 1, 1, 1],
    "enter": [0.05, 0.7, 0.1, 1, 1, 1],
    "exit": [0.3, 0, 1, 1, 1, 1],
    "sweep": [0.65, 0, 0.35, 1, 1, 1],
    "settle": [0.32, 1.24, 0.42, 1, 1, 1],
    "settleFast": [0.34, 1.3, 0.5, 1, 1, 1]
};

var DURATION = {
    "quick": 90,
    "short": 160,
    "medium": 240,
    "long": 360,
    "scan": 480,
    "settle": 320,
    "settleFast": 220
};

// Reduced motion: spatial animation collapses to 0 ms; opacity
// cross-fades survive but are capped at 90 ms (RFC 0001 §3.6).
function duration(name, reduced) {
    return reduced ? 0 : DURATION[name];
}

function fadeDuration(name, reduced) {
    return reduced ? Math.min(DURATION.quick, DURATION[name]) : DURATION[name];
}

// Colour helper: role colour at alpha (0..1) as #AARRGGBB.
function alpha(hex, a) {
    var v = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16);
    if (v.length < 2) {
        v = "0" + v;
    }
    return "#" + v + hex.substring(1);
}
