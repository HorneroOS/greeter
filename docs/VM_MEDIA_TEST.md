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

1. Boot to the SDDM greeter. Screenshot after ~15 s (reveal + first clip).
   Expect: fullscreen video behind the clock/login, not `background.jpg`.
2. Cover rotation: restart the greeter 6+ times
   (`systemctl restart sddm`), screenshotting each boot. Expect: different
   day clips across boots (Iguazu, Perito Moreno wall/calving, Ushuaia,
   Buenos Aires, Bariloche), no immediate repeat, no stuck frame.
3. Night mood: set the VM clock to 02:00, restart SDDM, screenshot.
   Expect: the mountain-lake clip, dim and calm.
4. Missing pack: uninstall `hornero-greeter-media-base` (leaving the
   theme's `media/base` symlink dangling), restart SDDM, screenshot.
   Expect: static `background.jpg` fallback, login fully usable, no QML
   errors in the journal.
5. Reinstall the pack, restart, screenshot. Expect: video resumes.

## Pass criteria

- Steps 1-3 show motion (two screenshots 3 s apart differ).
- `journalctl -u sddm` shows no MediaPlayer error loops and no network
  access attempts from the greeter process.
- Step 4 never blocks login; step 5 recovers without config changes.

## Already verified locally (no VM)

`sddm-greeter-qt6 --test-mode` with the staged install layout
(`preview.sh --real-media`, single-clip and full-catalog): all 8 built
clips decoded and rendered behind the login UI, one per screenshot;
fallback path covered by `--static`. Test mode exercises the deck, not
the SDDM daemon — hence this VM note.
