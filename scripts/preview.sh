#!/bin/sh
# Preview the Hornero greeter with sddm-greeter-qt6 in test mode.
#
# Builds short local fixture clips (no downloads: graded stills rendered
# from background.jpg with ffmpeg), stages a throwaway theme directory in
# /tmp that reuses this repo read-only via symlinks, and runs the greeter.
#
# Usage:
#   scripts/preview.sh [--shot FILE] [--delay SECS] [--scale N]
#                      [--run-secs N] [--keep] [--fixtures-only]
#
#   --shot FILE     capture the root window to FILE (needs ImageMagick import)
#   --delay SECS    wait before capture (default 8: reveal timer + crossfade)
#   --scale N       QT_SCALE_FACTOR for a HiDPI pass (default 1)
#   --real-media    stage the REAL built pack (build/media/base) and the repo
#                   catalog instead of synthetic fixtures (needs build.py run)
#   --clip ID       with --real-media: preview a single catalog entry by id,
#                   forcing the deck to its daypart (per-clip visual QA)
#   --run-secs N    stop the greeter after N seconds (default 12 with --shot,
#                   otherwise run until interrupted)
#   --keep          keep the staged theme directory instead of deleting it
#   --fixtures-only only (re)build the fixture clips and manifest
#   --daypart PART  stage a catalog with only PART (day|golden|night) and
#                   force the deck to it in the STAGED Main.qml copy, so any
#                   mood renders regardless of the real clock hour
#   --prefill-user NAME / --prefill-password TEXT
#                   staged-copy-only probe: preset login fields to render
#                   avatar/focus-with-content states (never in the repo file)
#   --fail-login    staged-copy-only probe: attempt a bogus login on startup
#                   to render the production login-error path
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIXDIR=/tmp/greeter-fixtures
STAGE=$(mktemp -d /tmp/greeter-preview-XXXXXX)

SHOT=""
DELAY=8
SCALE=1
RUN_SECS=""
KEEP=0
STATIC=0
FIXTURES_ONLY=0
REAL_MEDIA=0
CLIP=""
DAYPART=""
PREFILL_USER=""
PREFILL_PASSWORD=""
FAIL_LOGIN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --shot) SHOT="$2"; shift 2;;
    --delay) DELAY="$2"; shift 2;;
    --scale) SCALE="$2"; shift 2;;
    --run-secs) RUN_SECS="$2"; shift 2;;
    --keep) KEEP=1; shift;;
    --static) STATIC=1; shift;;
    --real-media) REAL_MEDIA=1; shift;;
    --clip) CLIP="$2"; shift 2;;
    --fixtures-only) FIXTURES_ONLY=1; shift;;
    --daypart) DAYPART="$2"; shift 2;;
    --prefill-user) PREFILL_USER="$2"; shift 2;;
    --prefill-password) PREFILL_PASSWORD="$2"; shift 2;;
    --fail-login) FAIL_LOGIN=1; shift;;
    *) echo "unknown flag: $1" >&2; exit 1;;
  esac
done

case "$DAYPART" in
  ""|day|golden|night) ;;
  *) echo "bad --daypart: $DAYPART (day|golden|night)" >&2; exit 1;;
esac

if [ -n "$SHOT" ] && [ -z "$RUN_SECS" ]; then
  RUN_SECS=$((DELAY + 4))
fi

mkdir -p "$FIXDIR"
if [ ! -f "$FIXDIR/day.mp4" ] || [ ! -f "$FIXDIR/night.mp4" ] || [ ! -f "$FIXDIR/golden.mp4" ]; then
  echo "building fixture clips in $FIXDIR ..."
  ffmpeg -y -loglevel error -loop 1 -i "$ROOT/background.jpg" \
    -filter_complex "[0:v]scale=1280:720,zoompan=z='1.0+0.03*on/150':d=150:s=1280x720:fps=30,eq=saturation=1.1:contrast=1.05,format=yuv420p[v]" \
    -map "[v]" -t 5 -c:v libx264 -preset veryfast -crf 23 "$FIXDIR/day.mp4"
  ffmpeg -y -loglevel error -loop 1 -i "$ROOT/background.jpg" \
    -filter_complex "[0:v]scale=1280:720,zoompan=z='1.0+0.03*on/150':d=150:s=1280x720:fps=30,eq=brightness=-0.25:saturation=0.9:contrast=1.05,colorbalance=rs=0.2:gs=-0.05:bs=-0.2,format=yuv420p[v]" \
    -map "[v]" -t 5 -c:v libx264 -preset veryfast -crf 23 "$FIXDIR/night.mp4"
  ffmpeg -y -loglevel error -loop 1 -i "$ROOT/background.jpg" \
    -filter_complex "[0:v]scale=1280:720,zoompan=z='1.0+0.03*on/150':d=150:s=1280x720:fps=30,eq=brightness=-0.08:saturation=1.35:contrast=1.08,colorbalance=rs=0.45:gs=0.05:bs=-0.35:rm=0.25:gm=0.0:bm=-0.2,format=yuv420p[v]" \
    -map "[v]" -t 5 -c:v libx264 -preset veryfast -crf 23 "$FIXDIR/golden.mp4"
fi

if [ "$FIXTURES_ONLY" = 1 ]; then
  echo "fixtures ready in $FIXDIR"
  rmdir "$STAGE"
  exit 0
fi

# Stage a preview theme: symlink the repo read-only, overlay a preview-only
# media dir (real catalog files + fixture clips) and a preview theme.conf.
# Probe flags (--daypart/--prefill-*/--fail-login) operate on a COPY of
# Main.qml inside the throwaway stage dir; the repo file is never modified.
mkdir -p "$STAGE/media"
ln -s "$ROOT/components" "$STAGE/components"
ln -s "$ROOT/background.jpg" "$STAGE/background.jpg"
ln -s "$ROOT/metadata.desktop" "$STAGE/metadata.desktop"
for f in "$ROOT"/media/*; do
  case "$(basename "$f")" in
    README.md) ln -s "$f" "$STAGE/media/README.md";;
  esac
done
ln -s "$FIXDIR/day.mp4" "$STAGE/media/preview-day.mp4"
ln -s "$FIXDIR/night.mp4" "$STAGE/media/preview-night.mp4"
ln -s "$FIXDIR/golden.mp4" "$STAGE/media/preview-golden.mp4"

if [ -n "$CLIP" ] && [ "$REAL_MEDIA" != 1 ]; then
  echo "--clip needs --real-media" >&2
  exit 2
fi
if [ -n "$CLIP" ]; then
  # Resolve the clip's bucket early: the STAGED Main.qml daypart force below
  # runs before the catalog is staged, so the mood must be known here.
  DAYPART=$(python3 - "$ROOT/media/catalog.json" "$CLIP" <<'EOF'
import json, sys
repo, want = sys.argv[1], sys.argv[2]
doc = json.load(open(repo, encoding="utf-8"))
for part, entries in doc["dayparts"].items():
    for entry in entries:
        if entry["id"] == want:
            print({"day": "day", "golden-hour": "golden", "night": "night"}[part])
            sys.exit(0)
print(f"unknown clip id: {want}", file=sys.stderr)
sys.exit(2)
EOF
)
fi

STAGE_MAIN_NEEDS_COPY=0
[ -n "$DAYPART" ] && STAGE_MAIN_NEEDS_COPY=1
[ -n "$CLIP" ] && STAGE_MAIN_NEEDS_COPY=1
[ -n "$PREFILL_USER" ] && STAGE_MAIN_NEEDS_COPY=1
[ -n "$PREFILL_PASSWORD" ] && STAGE_MAIN_NEEDS_COPY=1
[ "$FAIL_LOGIN" = 1 ] && STAGE_MAIN_NEEDS_COPY=1
if [ "$STAGE_MAIN_NEEDS_COPY" = 1 ]; then
  cp "$ROOT/Main.qml" "$STAGE/Main.qml"
else
  ln -s "$ROOT/Main.qml" "$STAGE/Main.qml"
fi

if [ -n "$DAYPART" ]; then
  # Force the deck mood in the STAGED copy so the state renders
  # regardless of the real clock hour.
  python3 - "$STAGE/Main.qml" "$DAYPART" <<'EOF'
import re, sys
path, part = sys.argv[1], sys.argv[2]
qml_file = {"day": "day", "golden": "golden-hour", "night": "night"}[part]
src = open(path, encoding="utf-8").read()
src2, n = re.subn(r"deck\.daypart\s*=\s*[^;]+;", 'deck.daypart = "%s";' % qml_file, src, count=1)
assert n == 1, "daypart assignment not found"
open(path, "w", encoding="utf-8").write(src2)
EOF
fi
if [ -n "$PREFILL_USER" ]; then
  python3 - "$STAGE/Main.qml" "$PREFILL_USER" <<'EOF'
import sys
path, name = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
old = "text: userModel.lastUser"
assert old in src, "username binding not found"
src = src.replace(old, 'text: "%s"' % name, 1)
open(path, "w", encoding="utf-8").write(src)
EOF
fi
if [ -n "$PREFILL_PASSWORD" ]; then
  python3 - "$STAGE/Main.qml" "$PREFILL_PASSWORD" <<'EOF'
import sys
path, secret = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
old = "id: password_input_box"
assert old in src, "password box not found"
src = src.replace(old, 'id: password_input_box\n                            text: "%s"' % secret, 1)
open(path, "w", encoding="utf-8").write(src)
EOF
fi
if [ "$FAIL_LOGIN" = 1 ]; then
  # Test-mode sddm.login() is a silent no-op (no daemon to authenticate
  # against), so drive the production onLoginFailed handler body directly in
  # the STAGED copy to render the true error style and layout shift.
  python3 - "$STAGE/Main.qml" <<'EOF'
import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
old = "loginRevealTimer.start();"
assert old in src, "reveal timer not found"
src = src.replace(old, old + '\n            error_message.color = config.errorMsgFontColor;\n            error_message.text = textConstants.loginFailed;', 1)
open(path, "w", encoding="utf-8").write(src)
EOF
fi

if [ "$REAL_MEDIA" = 1 ]; then
  # Real-pack QA: link the built base pack and stage the repo catalog, so
  # the greeter plays the actual shipped clips through the install layout
  # (media/base/ bridge). Fixture clips are not staged in this mode.
  if [ ! -d "$ROOT/build/media/base" ]; then
    echo "no built pack: run python3 scripts/media/build.py first" >&2
    exit 1
  fi
  ln -s "$ROOT/build/media/base" "$STAGE/media/base"
  if [ -n "$CLIP" ]; then
    # Single out one entry: the staged catalog holds only that clip (the
    # deck mood was already forced to its bucket in the STAGED Main.qml).
    python3 - "$ROOT/media/catalog.json" "$STAGE/media/catalog.json" "$CLIP" <<'EOF'
import json, sys
repo, staged, want = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(repo, encoding="utf-8"))
hit = None
for part, entries in doc["dayparts"].items():
    for entry in entries:
        if entry["id"] == want:
            hit = (part, entry)
if hit is None:
    print(f"unknown clip id: {want}", file=sys.stderr)
    sys.exit(2)
part, entry = hit
out = {"version": 1, "fallbackImage": doc["fallbackImage"],
       "dayparts": {"day": [], "golden-hour": [], "night": []}}
out["dayparts"][part] = [entry]
json.dump(out, open(staged, "w", encoding="utf-8"), indent=2)
EOF
  else
    cp "$ROOT/media/catalog.json" "$STAGE/media/catalog.json"
  fi
elif [ "$STATIC" = 1 ]; then
  # Empty catalog: exercises the static fallback image path.
  cat > "$STAGE/media/catalog.json" <<'EOF'
{
  "version": 1,
  "fallbackImage": "background.jpg",
  "dayparts": {
    "day": [],
    "night": []
  }
}
EOF
elif [ -n "$DAYPART" ]; then
  case "$DAYPART" in
    day) DP_QML="day"; CLIP="preview-day.mp4"; PID="preview-day";;
    golden) DP_QML="golden-hour"; CLIP="preview-golden.mp4"; PID="preview-golden";;
    night) DP_QML="night"; CLIP="preview-night.mp4"; PID="preview-night";;
  esac
  cat > "$STAGE/media/catalog.json" <<EOF
{
  "version": 1,
  "fallbackImage": "background.jpg",
  "dayparts": {
    "day": [],
    "golden-hour": [],
    "night": []
  }
}
EOF
  python3 - "$STAGE/media/catalog.json" "$DP_QML" "$PID" "$CLIP" <<'EOF'
import json, sys
path, part, pid, clip = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
doc = json.load(open(path, encoding="utf-8"))
doc["dayparts"][part] = [{"id": pid, "daypart": part, "kind": "video", "file": "media/" + clip}]
json.dump(doc, open(path, "w", encoding="utf-8"), indent=2)
EOF
else
  cat > "$STAGE/media/catalog.json" <<'EOF'
{
  "version": 1,
  "fallbackImage": "background.jpg",
  "dayparts": {
    "day": [
      {"id": "preview-day", "daypart": "day", "kind": "video", "file": "media/preview-day.mp4"}
    ],
    "golden-hour": [
      {"id": "preview-golden", "daypart": "golden-hour", "kind": "video", "file": "media/preview-golden.mp4"}
    ],
    "night": [
      {"id": "preview-night", "daypart": "night", "kind": "video", "file": "media/preview-night.mp4"}
    ]
  }
}
EOF
fi
# Runtime catalog for the staged theme: generated from the staged
# catalog.json (the greeter imports catalog.js synchronously; Qt blocks XHR
# reads of local files, so catalog.json alone would leave video dark).
"$ROOT/scripts/media/build-catalog" "$STAGE/media/catalog.json" >/dev/null
sed -e 's/^testMode=false/testMode=true/' "$ROOT/theme.conf" > "$STAGE/theme.conf"

echo "preview theme staged at $STAGE"
if [ "$KEEP" = 1 ]; then
  echo "(keeping stage dir)"
fi

GREETER_PID=""
cleanup() {
  if [ -n "$GREETER_PID" ]; then
    kill "$GREETER_PID" 2>/dev/null || true
  fi
  if [ "$KEEP" = 0 ]; then
    rm -rf "$STAGE"
  fi
}
trap cleanup EXIT INT TERM

QT_SCALE_FACTOR="$SCALE" sddm-greeter-qt6 --test-mode --theme "$STAGE" &
GREETER_PID=$!

if [ -n "$SHOT" ]; then
  sleep "$DELAY"
  # Dismiss nothing: the greeter auto-reveals; grab the compositor output.
  if command -v grim >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" grim "$SHOT"
  else
    ffmpeg -y -loglevel error -f x11grab -i "${DISPLAY:-:0}" -frames:v 1 "$SHOT"
  fi
  echo "screenshot saved to $SHOT"
fi

if [ -n "$RUN_SECS" ]; then
  sleep "$RUN_SECS" &
  WAIT_PID=$!
  wait "$WAIT_PID" || true
else
  wait "$GREETER_PID"
  GREETER_PID=""
fi
