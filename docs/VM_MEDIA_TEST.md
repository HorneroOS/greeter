# VM test: greeter media pack (offline)

Goal: prove the SDDM greeter plays the Argentina base pack with no
network, and degrades gracefully without it. Runs on the installer
track's VM harness; this repo only defines the procedure and the
pass criteria.

## Prerequisites

- VM built from an ISO that installs both packages:
  `hornero-greeter` (theme) and `hornero-greeter-media-base` (clips).
- Host network disabled for the VM (offline proof); keep a screenshot
  channel (SPICE / screenshot dump).

## Procedure

1. Golden-hour boot (set the VM clock inside the `theme.conf` golden-hour
   window, e.g. 18:30, restart SDDM, screenshot after ~15 s). Expect:
   fullscreen video (`ar-rn-dina-huapi-sunset` or `ar-ba-dusk-timelapse`)
   behind the clock/login, not `components/resources/fallback-golden-hour.svg`.
2. Rotation: restart the greeter 6+ times, screenshotting each boot. Expect:
   both golden-hour clips appear, no immediate repeat, no stuck frame.
3. Day and night: set the clock to 12:00 and 02:00, restart SDDM, screenshot.
   Expect: the designed gradient fallback for that daypart (no day or night
   clip is approved yet), login fully usable.
4. Missing pack: uninstall `hornero-greeter-media-base` (leaving the
   theme's `media/base` symlink dangling), restart SDDM, screenshot.
   Expect: static designed gradient fallback (also at golden hour), login fully usable, no QML
   errors in the journal.
5. Reinstall the pack, restart, screenshot. Expect: video resumes.

## Pass criteria

- Steps 1-2 show motion (two screenshots 3 s apart differ); step 3 is static by design.
- `journalctl -u sddm` shows no MediaPlayer error loops and no network
  access attempts from the greeter process.
- Step 4 never blocks login; step 5 recovers without config changes.

## Already verified locally (no VM)

`sddm-greeter-qt6 --test-mode` with the staged install layout
(`preview.sh --real-media`, historical, pre-replacement catalogue): all built
clips decoded and rendered behind the login UI, one per screenshot;
fallback path covered by `--static`. Test mode exercises the deck, not
the SDDM daemon — hence this VM note.
