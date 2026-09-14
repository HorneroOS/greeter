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
