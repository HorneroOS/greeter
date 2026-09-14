# Upstream attribution

This theme is derived from the **aerial-sddm-theme** by Fabio Almeida
(3ximus):

- Upstream repository: <https://github.com/3ximus/aerial-sddm-theme>
- Imported into HorneroOS/greeter as commit `d198df6`
  (`chore: import 3ximus/aerial-sddm-theme upstream`).
- Upstream license: GNU General Public License v3.0 (see `LICENSE`).

## What changed in the Qt6 migration (`feat/qt6-migration`)

- `Main.qml` and `components/` were ported from Qt5 (`QtQuick 2.0`,
  `QtMultimedia 5.7`, `Playlist`/`QMediaPlaylist`, `QtGraphicalEffects`)
  to Qt6 (`QtQuick`, `QtMultimedia` `MediaPlayer` + `VideoOutput`,
  `QtQuick.Effects` `MultiEffect`). `QMediaPlaylist` no longer exists in
  Qt6 and was replaced, not preserved.
- The upstream HTTP video playlists (`playlists/*.m3u`, streaming Apple TV
  aerial clips) were removed: the greeter must run with zero network
  access. They are replaced by a local sequencer: `components/MediaDeck.qml`
  driven by `components/MediaCatalog.js` and `media/catalog.json`.
- `components/WallpaperFader.qml` was reworked on `MultiEffect` and its
  default state was fixed (the old default referenced
  `lockScreenRoot.uiVisible`, which does not exist in an SDDM greeter).
- New `theme.conf` keys: `mediaManifest`, `videoEnabled`,
  `crossfadeDuration` (clamped to 2000-4000 ms), `testMode`.
- All SDDM flows (username/password login with masked password and
  last-user default, session and keyboard selectors, login-failure errors,
  reboot/power-off buttons, keyboard focus chain) are unchanged.

Qt6 reference consulted during the port: Keyitdev/sddm-astronaut-theme
(unversioned `QtMultimedia` import, `QtQuick.Effects` usage).

## Hornero identity (`feat/hornero-identity`)

- `Main.qml` was redesigned around a Hornero-native cinematic hero: warm
  charcoal surfaces, earth browns, terracotta and burnt-orange accents,
  cream type. The video hero keeps `PreserveAspectCrop` and is graded with
  a warm tint wash, a vertical legibility gradient and a horizontal
  vignette; below it sit a large clock, date, a subtle location label (no
  URLs on screen) and one minimal login card.
- The login card adds an optional avatar (`showAvatar` / `avatarImage`
  theme keys, local relative paths only) with a graceful initial-letter
  fallback medallion. Password entry stays masked via `PasswordBox`; the
  full keyboard flow (Tab chain across user, password, login, power,
  session and layout controls, Enter to log in, Escape to clear) is kept.
- Layout is resolution-independent: a `uiScale` factor derived from the
  screen size (1.0 at 1280x720, clamped) drives hero width, card metrics
  and font sizes, covering 720p, 1080p, 1440p and HiDPI from one file.
- New `theme.conf` keys: `locationLabel`, `locationFontSize`,
  `showAvatar`, `avatarImage`, `creamColor`, `mutedColor`, `accentColor`,
  `terracottaColor`, `surfaceColor`, `surfaceBorderColor`. All prior keys
  keep their meaning.
- Fixed a latent Qt6 bug the port carried over: `FontLoader { name: ... }`
  is a read-only property in Qt6 and aborts theme loading at runtime
  (caught by previewing under `sddm-greeter-qt6 --test-mode`). The display
  font family now binds directly from `theme.conf`.
- New `scripts/preview.sh` stages a throwaway theme directory (symlinks,
  repo stays read-only), builds local fixture clips from `background.jpg`
  with ffmpeg (no downloads), and runs `sddm-greeter-qt6 --test-mode`
  with optional `grim`/x11grab screenshots, HiDPI scale and a static
  fallback (`--static`) mode.
