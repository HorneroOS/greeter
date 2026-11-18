# Greeter screens

Original renders of this theme. They are not photographs, and the theme
contains no third-party media. Every frame was produced offscreen by the
real `sddm-greeter-qt6 --test-mode` on Qt's offscreen platform with
`scripts/render-matrix.sh` (via `scripts/preview.sh --grab`). Each render
uses fixture accounts and sessions, the clock pinned to 21:40 (08:15 for
the morning frame) and sky seed 7. These are not captures of a real SDDM
login.

- `screenshot.png`: Signal Night, 1920×1080 (`metadata.desktop`
  Screenshot)
- `signal/01-night-1920x1080.png`: Signal Night, 1920×1080
- `signal/02-day-1920x1080.png`: Signal Day (`colorScheme=day`)
- `signal/04-high-contrast-large-text-1920x1080.png`: High Contrast plus
  large text (split layout)
- `signal/06-large-text-1366x768.png`: large text at 1366×768 (split
  layout)
- `signal/08-two-monitors-secondary.png`: the quiet plate on a secondary
  output
- `signal/09-login-failed.png`: second failed attempt
- `signal/11-no-sessions.png`: no sessions installed (log in disabled)
- `signal/14-power-confirm-restart.png`: restart confirmation
- `signal/15-session-list-open.png`: session list with Desktop, Studio and
  Gaming (experimental last)
- `signal/17-es-day-1366x768.png`: Spanish, Signal Day, 1366×768

To regenerate the files: `sh scripts/render-matrix.sh OUTDIR --sheet` and
copy the frames listed above.
