# Greeter UX checklist

First-frame and coherence review for the cinematic SDDM greeter.
Run through this list on every media-pack or layout change; anything
unchecked blocks the change.

## First frame

- [ ] A still (`background.jpg` or pack poster) paints before the
  video pipeline is ready — never a black screen on slow disks.
- [ ] Clock and login form are legible over the busiest frame of each
  pack (day, golden-hour, night windows in `theme.conf`).
- [ ] Video failure (missing codec, corrupt file) degrades to the
  still, not to an error surface. See `tests/test_runtime_offline.py`.
- [ ] No network access at any point: packs are local
  (`tests/test_runtime_offline.py` enforces).

## Coherence with the desktop

- [ ] The greeter reads as HorneroOS: Argentine landscapes,
  hornero identity, same typeface family as the desktop.
- [ ] Day / golden-hour / night rotation matches the desktop's
  day-night story (no noon footage at midnight).
- [ ] New media packs ship a manifest validated by
  `scripts/validate-media-manifests.py` and previews under `screens/`.

## Interaction

- [ ] Typing works on first keypress: no focus steal by the video
  surface after load.
- [ ] Session list, keyboard layout, and power actions are reachable
  without a pointer.
- [ ] Failed login keeps the typed username and returns focus to the
  password field.

## Failure modes

- [ ] Missing media pack: still image + full login, zero video.
- [ ] Broken `theme.conf` value: sane default wins, greeter still loads
  (`tests/test_theme_conf.py`).
- [ ] Upstream drift: `tests/test_upstream_fidelity.py` pins the
  aerial-sddm-theme port contract (see `UPSTREAM.md`).
