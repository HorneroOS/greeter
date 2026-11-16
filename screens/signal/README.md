# Hornero Signal greeter captures

Produced on 2026-11-16 on the maintainer's Arch Linux host (Qt 6.12,
SDDM 0.21, IBM Plex from `ttf-ibm-plex` 6.4.0 installed at user level) by
running the real `sddm-greeter-qt6 --test-mode` on Qt's offscreen platform
at 1920x1080 (08: 1366x768) against a staged copy of this theme, whose
`Main.qml` grabbed its own frame (the method behind
`scripts/preview.sh --grab`). They are product renders, not concept art,
with these staged-only probes:

- Restart and Shut down are forced visible: test mode reports no power
  permission, so they would otherwise be hidden.
- The daypart is forced per capture so each licensed still appears.
- 05 sets the login-failed state and a sample user name; 06 opens the
  session list.
- No video pack is staged and the offscreen platform does not capture video
  frames, so every capture shows the still fallback and the `STILL` chip.
  The `LIVE` chip and footage need a real display (host or VM).

| File | State |
| ---- | ----- |
| `01-signal-night-golden-hour.jpg` | Signal Night, golden hour still (El Palmar) |
| `02-signal-night-night.jpg` | Signal Night, night still (Buenos Aires) |
| `03-signal-night-day-fallback.jpg` | Day fallback still (`background.jpg`, no credit entry) |
| `04-high-contrast-large-text.jpg` | `highContrast=true`, `largeText=true` |
| `05-login-failed.jpg` | Failed login: alert well, status line, username kept |
| `06-session-list-open.jpg` | Session list open from the keyboard, notch and `ACTIVE` row |
| `07-reduced-motion-first-frame.jpg` | `reducedMotion=true`, about 1 s after start: complete frame |
| `08-1366x768.jpg` | 1366x768, type held at the RFC scale |
