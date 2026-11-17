# Greeter UX checklist

First-frame and coherence review for the Hornero Signal SDDM greeter.
Run through this list on every media-pack or layout change; anything
unchecked blocks the change.

## First frame

- [ ] A still (`components/resources/fallback-day.svg` or pack poster) paints before the
  video pipeline is ready — never a black screen on slow disks.
- [ ] Clock and login form are legible over the busiest frame of each
  pack (day, golden-hour, night windows in `theme.conf`).
- [ ] Video failure (missing codec, corrupt file) degrades to the
  still, not to an error surface. See `tests/test_runtime_offline.py`.
- [ ] No network access at any point: packs are local
  (`tests/test_runtime_offline.py` enforces).

## Coherence with the desktop

- [ ] The greeter reads as HorneroOS on Hornero Signal (RFC 0001):
  Signal Night roles only (`components/Signal.js`), IBM Plex Sans / Mono /
  Sans Condensed, small radii, hairline rules, mono eyebrows, the
  registration tick and celeste focus ring, the La Plata diagonal only in
  the console header and bottom rail.
- [ ] No Material-styled control, icon font or upstream colour returns
  (`tests/test_signal_design.py`).
- [ ] The scene credit in the bottom rail matches the footage or still on
  screen, and only rights-reviewed manifests are credited
  (`tests/test_scene_credits.py`).
- [ ] Day / golden-hour / night rotation matches the desktop's
  day-night story (no noon footage at midnight).
- [ ] New media packs ship a manifest validated by
  `scripts/validate-media-manifests.py` and previews under `screens/`.

## Interaction

- [ ] Typing works on first keypress: no focus steal by the video
  surface after load.
- [ ] Session list, keyboard layout, user list and power actions are
  reachable and operable without a pointer; Tab skips hidden controls and
  Escape closes a list and returns focus (`tests/test_accessibility.py`).
- [ ] Focus is always visible: 2 px focus ring plus registration tick.
- [ ] Failed login keeps the typed username and returns focus to the
  password field.

## Accessibility and motion

- [ ] `largeText=true`: every text and control scales 1.5x without
  clipping at 1920x1080 and 1366x768.
- [ ] `highContrast=true`: Signal High Contrast palette, opaque rails.
- [ ] `reducedMotion=true`: no travel or wipes, fades at most 90 ms; the
  screen is complete and calm with motion disabled.
- [ ] Contrast: every text role passes WCAG AA and every boundary 3:1 on
  the surfaces it is drawn on (`tests/test_signal_design.py`).

## Failure modes

- [ ] Missing media pack: still image + full login, zero video.
- [ ] Broken `theme.conf` value: sane default wins, greeter still loads
  (`tests/test_theme_conf.py`).
- [ ] Missing `ttf-ibm-plex`: fontconfig fallback renders every label
  (no tofu, no clipped clock).
- [ ] Capture evidence with `scripts/preview.sh --grab` (offscreen, states
  where it ran) or `--shot` on a real display; never reuse old captures.
