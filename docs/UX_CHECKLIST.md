# Greeter UX checklist

First-frame and coherence review for the Hornero Signal SDDM greeter.
Run through this list on every layout, copy or background change. Anything
unchecked blocks the change.

## First frame

- [ ] The generative horizon paints on the first frame: no black screen,
  no image load (`tests/test_no_bundled_media.py`).
- [ ] The clock, channels and status line are legible on Night, Day and
  High Contrast, and over an opt-in `backgroundImage` with the default
  `backgroundDim`.
- [ ] An opt-in video that is missing, undecodable or unsupported (no
  `qt6-multimedia`) leaves the generative horizon, not an error surface.
- [ ] No network access at any point (`tests/test_runtime_offline.py`).

## Coherence with the desktop

- [ ] The greeter reads as HorneroOS on Hornero Signal (RFC 0001):
  built-in Signal roles only (`components/Signal.js`), IBM Plex Sans,
  Mono and Sans Condensed, small radii, hairline rules, mono eyebrows, the
  registration tick and celeste focus ring, and the La Plata diagonal only
  in the sign-in header and the bottom rail.
- [ ] It belongs with the lock screen and the reload-cover slate: the same
  clock (muted colon, one signal hairline, uppercase mono date), Javi's
  greeting, the Hornero mark, and the dial-scale vocabulary
  (`tests/test_design_contract.py`).
- [ ] No Material-styled control, icon font or upstream colour returns
  (`tests/test_signal_design.py`).
- [ ] No third-party photo or video is added to the tree or the package
  (`tests/test_no_bundled_media.py`).

## Interaction

- [ ] Typing works on the first keypress, from the channels or before any
  field has focus.
- [ ] Channels, the typed user name, session, keyboard layout and power
  actions are reachable and operable without a pointer. Tab skips hidden
  and disabled controls, and Escape closes a list or the power question
  and returns focus (`tests/test_accessibility.py`).
- [ ] Focus is always visible: a 2 px focus ring plus the registration
  tick.
- [ ] A failed login keeps the account, clears and refocuses the password,
  and says which attempt it was from the second failure on.
- [ ] Power actions ask first, with Cancel focused.

## Accessibility and motion

- [ ] `largeText=true`: every text and control scales 1.5× without clipping
  at 1920×1080 and 1366×768 (the layout splits when the column does not
  fit).
- [ ] `highContrast=true`: the Signal High Contrast palette, opaque rails,
  and a background reduced to the horizon line.
- [ ] `reducedMotion=true`: no travel or wipes, fades at most 90 ms, no
  ambient scan, no blink. The screen is complete and calm.
- [ ] Contrast: every text role passes WCAG AA and every boundary 3:1 on
  the surfaces it is drawn on (`tests/test_signal_design.py`).
- [ ] Spanish and English both read naturally: voseo, no exclamation
  marks, no emoji (`tests/test_strings.py`).

## Failure modes

- [ ] No sessions installed: an alert in words, and log in disabled.
- [ ] No accounts listed (hidden users): a typed user name.
- [ ] A daemon that never answers: "No answer from the display manager
  yet" after 12 s.
- [ ] A broken `theme.conf` value: the sane default wins and the greeter
  still loads (`tests/test_theme_conf.py`).
- [ ] Missing `ttf-ibm-plex`: the fontconfig fallback renders every label
  (no tofu, no clipped clock).
- [ ] Multi-monitor: the main card is on the primary output only, and the
  others show the quiet plate.
- [ ] Capture evidence with `scripts/render-matrix.sh` or
  `scripts/preview.sh --grab` (offscreen; say where it ran) or `--shot` on
  a real display. Never reuse old captures.
