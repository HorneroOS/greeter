#!/bin/sh
# Render the greeter's review matrix offscreen (sddm-greeter-qt6
# --test-mode on QT_QPA_PLATFORM=offscreen via scripts/preview.sh --grab),
# with fixture accounts and sessions, a pinned clock and a pinned sky, so
# every frame is reproducible and shows no real account.
#
# Usage: scripts/render-matrix.sh OUTDIR [--sheet]
#   --sheet  also build OUTDIR/contact-sheet.png (needs ImageMagick montage)
#
# Heavy-ish (one greeter process per frame, ~5 s each): on a shared
# machine run it through a resource cap, e.g. `bounded sh scripts/...`.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:?usage: render-matrix.sh OUTDIR [--sheet]}
SHEET=${2:-}
mkdir -p "$OUT"
P="$ROOT/scripts/preview.sh"

frame() {
  name=$1
  shift
  sh "$P" --grab "$OUT/$name.png" "$@" >/dev/null
  echo "$OUT/$name.png"
}

frame 01-night-1920x1080 --scheme night
frame 02-day-1920x1080 --scheme day
frame 03-high-contrast-1920x1080 --high-contrast
frame 04-high-contrast-large-text-1920x1080 --high-contrast --large-text
frame 05-night-1366x768 --size 1366x768
frame 06-large-text-1366x768 --size 1366x768 --large-text
frame 07-night-2560x1440 --size 2560x1440
frame 08-two-monitors --screens 2
frame 09-login-failed --fail-login 2
frame 10-caps-lock --caps-lock
frame 11-no-sessions --no-sessions
frame 12-no-users-typed-name --no-users
frame 13-other-channel --other-user
frame 14-power-confirm-restart --confirm restart
frame 15-session-list-open --open-sessions
frame 16-es-night --lang es
frame 17-es-day-1366x768 --lang es --scheme day --size 1366x768
frame 18-reduced-motion --reduced-motion
frame 19-many-users --many-users
frame 20-plain-background --plain
frame 21-morning-day --scheme day --time 08:15
frame 22-hidpi-scale2 --size 1280x720 --scale 2

if [ "$SHEET" = "--sheet" ]; then
  montage -label '%t' "$OUT"/[0-9][0-9]-*.png -tile 4x -geometry 480x270+8+8 \
    -background '#0C0F13' -fill '#ECE6DA' -pointsize 12 "$OUT/contact-sheet.png"
  echo "$OUT/contact-sheet.png"
fi
