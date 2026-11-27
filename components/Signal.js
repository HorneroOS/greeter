.pragma library
// Hornero Signal tokens for the greeter (RFC 0001 §3, HorneroOS/docs).
//
// The greeter runs as the sddm user before any session exists, so it cannot
// read the live Chromatic scheme written by horneroctl. It carries the
// factory palettes verbatim instead: Signal Night (default), Signal Day
// (theme.conf colorScheme=day, or auto when the platform reports a light
// preference) and Signal High Contrast (theme.conf highContrast=true). Role names match
// HorneroOS/config profiles/themes/tokens.schema.json (schema v2) exactly;
// values include RFC 0001 amendment 3 (Cool Ceramic Day, Blue-Hour Graphite
// Night, High Contrast sync, ruleStrong, optional glow role).

var NIGHT = {
    "ground": "#0C1016",
    "sunken": "#10151C",
    "base": "#141B24",
    "panel": "#1B2430",
    "raised": "#24303D",
    "lifted": "#2C3947",
    "ink": "#E6EBF1",
    "inkMuted": "#A9B7C6",
    "inkFaint": "#8999AB",
    "rule": "#2D3B4B",
    "ruleStrong": "#8393A6",
    "focus": "#8BCEF0",
    "signal": "#F2AC52",
    "onSignal": "#1E1304",
    "signalWell": "#3D2B12",
    "onSignalWell": "#FFE0B0",
    "cue": "#8BCEF0",
    "onCue": "#071A26",
    "cueWell": "#163345",
    "onCueWell": "#D6EFFC",
    "phosphor": "#8DDBAF",
    "onPhosphor": "#071D12",
    "phosphorWell": "#153425",
    "onPhosphorWell": "#D1F5E0",
    "alert": "#FF8494",
    "onAlert": "#24070C",
    "alertWell": "#421922",
    "onAlertWell": "#FFD6DC",
    "inverse": "#E6EBF1",
    "onInverse": "#1B2430",
    "inverseSignal": "#864700",
    "scrim": "#000000",
    "shadow": "#000000",
    // Emission colour for the rationed luminous accent only (Signal Visual
    // Language §9): never text or fill; <= 40 % alpha, <= 4 px blur.
    "glow": "#FFC06B"
};

// Signal Day (HorneroOS/config profiles/themes/hornero-signal-day): white
// ceramic and pale aluminum instrument panels, dark slate ink, amber live
// signal and celeste focus cue.
var DAY = {
    "ground": "#E8EDF4",
    "sunken": "#E0E6EF",
    "base": "#EEF2F7",
    "panel": "#F5F8FC",
    "raised": "#FCFCFE",
    "lifted": "#FFFFFF",
    "ink": "#283344",
    "inkMuted": "#505E70",
    "inkFaint": "#606D80",
    "rule": "#D2DAE6",
    "ruleStrong": "#7A8798",
    "focus": "#145D86",
    "signal": "#864700",
    "onSignal": "#FFFFFF",
    "signalWell": "#FCE9C8",
    "onSignalWell": "#432300",
    "cue": "#145D86",
    "onCue": "#FFFFFF",
    "cueWell": "#D8EEF9",
    "onCueWell": "#0B334B",
    "phosphor": "#1E6448",
    "onPhosphor": "#FFFFFF",
    "phosphorWell": "#D6F4E8",
    "onPhosphorWell": "#0E3425",
    "alert": "#9C293E",
    "onAlert": "#FFFFFF",
    "alertWell": "#FADDE4",
    "onAlertWell": "#4E111E",
    "inverse": "#283344",
    "onInverse": "#F5F8FC",
    "inverseSignal": "#F2AC52",
    "scrim": "#000000",
    "shadow": "#000000",
    "glow": "#864700"
};

// Signal High Contrast: same roles, black ground, white ink, brighter
// signal/cue and a pure white ruleStrong (RFC 0001 §3.2).
var CONTRAST = {
    "ground": "#000000",
    "sunken": "#050607",
    "base": "#0A0C0F",
    "panel": "#101317",
    "raised": "#181C21",
    "lifted": "#22272E",
    "ink": "#FFFFFF",
    "inkMuted": "#D9DCDF",
    "inkFaint": "#9DA3A9",
    "rule": "#5C646D",
    "ruleStrong": "#FFFFFF",
    "focus": "#8FD3FF",
    "signal": "#FFC247",
    "onSignal": "#000000",
    "signalWell": "#3D2C00",
    "onSignalWell": "#FFE6B0",
    "cue": "#8FD3FF",
    "onCue": "#000000",
    "cueWell": "#0B2B3D",
    "onCueWell": "#DDF2FF",
    "phosphor": "#8CF0A4",
    "onPhosphor": "#000000",
    "phosphorWell": "#0E3319",
    "onPhosphorWell": "#D4FADE",
    "alert": "#FF8A73",
    "onAlert": "#000000",
    "alertWell": "#45120A",
    "onAlertWell": "#FFDCD4",
    "inverse": "#FFFFFF",
    "onInverse": "#000000",
    "inverseSignal": "#7A4A00",
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
