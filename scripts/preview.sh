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
#   --run-secs N    stop the greeter after N seconds (default 12 with --shot,
#                   otherwise run until interrupted)
#   --keep          keep the staged theme directory instead of deleting it
#   --fixtures-only only (re)build the fixture clips and manifest
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

while [ $# -gt 0 ]; do
  case "$1" in
    --shot) SHOT="$2"; shift 2;;
    --delay) DELAY="$2"; shift 2;;
    --scale) SCALE="$2"; shift 2;;
    --run-secs) RUN_SECS="$2"; shift 2;;
    --keep) KEEP=1; shift;;
    --static) STATIC=1; shift;;
    --fixtures-only) FIXTURES_ONLY=1; shift;;
    *) echo "unknown flag: $1" >&2; exit 1;;
  esac
done

if [ -n "$SHOT" ] && [ -z "$RUN_SECS" ]; then
  RUN_SECS=$((DELAY + 4))
fi

mkdir -p "$FIXDIR"
if [ ! -f "$FIXDIR/day.mp4" ] || [ ! -f "$FIXDIR/night.mp4" ]; then
  echo "building fixture clips in $FIXDIR ..."
  ffmpeg -y -loglevel error -loop 1 -i "$ROOT/background.jpg" \
    -filter_complex "[0:v]scale=1280:720,zoompan=z='1.0+0.03*on/150':d=150:s=1280x720:fps=30,eq=saturation=1.1:contrast=1.05,format=yuv420p[v]" \
    -map "[v]" -t 5 -c:v libx264 -preset veryfast -crf 23 "$FIXDIR/day.mp4"
  ffmpeg -y -loglevel error -loop 1 -i "$ROOT/background.jpg" \
    -filter_complex "[0:v]scale=1280:720,zoompan=z='1.0+0.03*on/150':d=150:s=1280x720:fps=30,eq=brightness=-0.25:saturation=0.9:contrast=1.05,colorbalance=rs=0.2:gs=-0.05:bs=-0.2,format=yuv420p[v]" \
    -map "[v]" -t 5 -c:v libx264 -preset veryfast -crf 23 "$FIXDIR/night.mp4"
fi

if [ "$FIXTURES_ONLY" = 1 ]; then
  echo "fixtures ready in $FIXDIR"
  rmdir "$STAGE"
  exit 0
fi

# Stage a preview theme: symlink the repo read-only, overlay a preview-only
# media dir (real catalog files + fixture clips) and a preview theme.conf.
mkdir -p "$STAGE/media"
ln -s "$ROOT/Main.qml" "$STAGE/Main.qml"
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
if [ "$STATIC" = 1 ]; then
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
else
  cat > "$STAGE/media/catalog.json" <<'EOF'
{
  "version": 1,
  "fallbackImage": "background.jpg",
  "dayparts": {
    "day": [
      {"id": "preview-day", "daypart": "day", "kind": "video", "file": "media/preview-day.mp4"}
    ],
    "night": [
      {"id": "preview-night", "daypart": "night", "kind": "video", "file": "media/preview-night.mp4"}
    ]
  }
}
EOF
fi
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
