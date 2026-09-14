.pragma library
// MediaCatalog.js — pure-logic sequencer for the SDDM greeter background deck.
//
// No Qt imports here on purpose: this file must stay importable from QML
// ("import \"MediaCatalog.js\" as Catalog") and testable from plain node.
// There is deliberately no network, no shell, and no filesystem access.

var DAYPARTS = ["day", "golden-hour", "night", "any"];
// Daypart buckets present in a catalog file. day/night are required;
// golden-hour is optional (missing means an empty golden-hour bucket).
var CATALOG_PARTS = ["day", "golden-hour", "night"];
var MIN_CROSSFADE_MS = 2000;
var MAX_CROSSFADE_MS = 4000;
var DEFAULT_CROSSFADE_MS = 3000;
var DEFAULT_MAX_ERRORS = 3;
var TEST_SEED = 1234;

function clampCrossfade(ms) {
    var v = parseInt(ms, 10);
    if (isNaN(v)) {
        return DEFAULT_CROSSFADE_MS;
    }
    if (v < MIN_CROSSFADE_MS) {
        return MIN_CROSSFADE_MS;
    }
    if (v > MAX_CROSSFADE_MS) {
        return MAX_CROSSFADE_MS;
    }
    return v;
}

function isRemoteUrl(value) {
    return typeof value === "string" && /^\s*https?:\/\//i.test(value);
}

function isLocalRelativePath(value) {
    if (typeof value !== "string" || value.length === 0) {
        return false;
    }
    if (isRemoteUrl(value)) {
        return false;
    }
    if (value.charAt(0) === "/" || value.charAt(0) === "~") {
        return false;
    }
    if (value.indexOf("$HOME") !== -1 || value.indexOf("..") !== -1) {
        return false;
    }
    return true;
}

// Returns { ok: bool, errors: [string] }. Never throws.
function validateCatalog(obj) {
    var errors = [];
    if (obj === null || typeof obj !== "object" || Array.isArray(obj)) {
        return { ok: false, errors: ["catalog must be an object"] };
    }
    if (obj.version !== 1) {
        errors.push("catalog.version must be 1");
    }
    if (!isLocalRelativePath(obj.fallbackImage)) {
        errors.push("catalog.fallbackImage must be a local relative path");
    }
    if (obj.dayparts === null || typeof obj.dayparts !== "object" || Array.isArray(obj.dayparts)) {
        errors.push("catalog.dayparts must be an object with day/night arrays (golden-hour optional)");
        return { ok: errors.length === 0, errors: errors };
    }
    var seen = {};
    CATALOG_PARTS.forEach(function (part) {
        var list = obj.dayparts[part];
        if (list === undefined && part === "golden-hour") {
            return;
        }
        if (!Array.isArray(list)) {
            errors.push("catalog.dayparts." + part + " must be an array");
            return;
        }
        list.forEach(function (entry, i) {
            var where = "catalog.dayparts." + part + "[" + i + "]";
            if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
                errors.push(where + " must be an object");
                return;
            }
            if (typeof entry.id !== "string" || entry.id.length === 0) {
                errors.push(where + ".id must be a non-empty string");
            } else if (seen[entry.id]) {
                errors.push(where + ".id duplicates \"" + entry.id + "\"");
            } else {
                seen[entry.id] = true;
            }
            if (!isLocalRelativePath(entry.file)) {
                errors.push(where + ".file must be a local relative path");
            }
            if (DAYPARTS.indexOf(entry.daypart) === -1) {
                errors.push(where + ".daypart must be one of day/golden-hour/night/any");
            }
            if (entry.kind !== "video") {
                errors.push(where + ".kind must be \"video\"");
            }
        });
    });
    return { ok: errors.length === 0, errors: errors };
}

// Hour-based day/night selection. Inclusive on both ends, matching the
// upstream aerial theme (dayTimeStart <= hour <= dayTimeEnd means day).
function isDay(hour, start, end) {
    var h = parseInt(hour, 10);
    var s = parseInt(start, 10);
    var e = parseInt(end, 10);
    if (isNaN(h) || isNaN(s) || isNaN(e)) {
        return true;
    }
    return h >= s && h <= e;
}

function inWindow(hour, start, end) {
    var h = parseInt(hour, 10);
    var s = parseInt(start, 10);
    var e = parseInt(end, 10);
    if (isNaN(h) || isNaN(s) || isNaN(e)) {
        return false;
    }
    return h >= s && h <= e;
}

// Daypart moods for the background deck: "day", "golden-hour" or "night".
// The golden-hour window is checked first so an evening mood can overlap
// the tail of the day window. Unparseable input falls back to "day".
function daypartForHour(hour, dayStart, dayEnd, goldenStart, goldenEnd) {
    if (inWindow(hour, goldenStart, goldenEnd)) {
        return "golden-hour";
    }
    if (isDay(hour, dayStart, dayEnd)) {
        return "day";
    }
    return "night";
}

function entriesForDaypart(catalog, daypart) {
    if (!catalog || !catalog.dayparts || !Array.isArray(catalog.dayparts[daypart])) {
        return [];
    }
    var out = [];
    CATALOG_PARTS.forEach(function (part) {
        var list = catalog.dayparts[part] || [];
        list.forEach(function (entry) {
            if (entry.daypart === daypart || entry.daypart === "any") {
                out.push(entry);
            }
        });
    });
    return out;
}

// resolver maps a catalog-relative file path to a playable URL string.
function resolveEntries(catalog, daypart, resolver) {
    return entriesForDaypart(catalog, daypart).map(function (entry) {
        return { id: entry.id, url: resolver(entry.file) };
    });
}

// 32-bit mulberry RNG for deterministic test mode.
function makeRng(seed) {
    var a = seed >>> 0;
    return function () {
        a |= 0;
        a = (a + 0x6D2B79F5) | 0;
        var t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function shuffledCopy(items, rand) {
    var arr = items.slice();
    for (var i = arr.length - 1; i > 0; i--) {
        var j = Math.floor(rand() * (i + 1));
        var tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;
    }
    return arr;
}

// Sequencer: random order, no immediate repeat, broken entries skipped with
// a bounded retry budget, deterministic when options.seed is a number.
// next() returns an entry or null when nothing is playable.
function createSequencer(entries, options) {
    var opts = options || {};
    var items = (entries || []).slice();
    var maxErrors = opts.maxErrors === undefined ? DEFAULT_MAX_ERRORS : opts.maxErrors;
    var rand = (typeof opts.seed === "number") ? makeRng(opts.seed) : Math.random;
    var errors = {};
    var queue = [];
    var lastId = null;

    function eligible() {
        return items.filter(function (e) { return (errors[e.id] || 0) <= maxErrors; });
    }

    function refill() {
        var pool = eligible();
        if (pool.length === 0) {
            queue = [];
            return;
        }
        queue = shuffledCopy(pool, rand);
        if (pool.length > 1 && queue[0].id === lastId) {
            queue.push(queue.shift());
        }
    }

    return {
        pending: function () {
            return eligible().length;
        },
        next: function () {
            if (queue.length === 0) {
                refill();
            }
            if (queue.length === 0) {
                return null;
            }
            var entry = queue.shift();
            lastId = entry.id;
            return entry;
        },
        reportBroken: function (id) {
            errors[id] = (errors[id] || 0) + 1;
            queue = queue.filter(function (e) { return e.id !== id || (errors[id] || 0) <= maxErrors; });
            if (queue.length === 0) {
                refill();
            }
        }
    };
}
