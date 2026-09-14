# Upstream provenance

This theme starts from the **aerial-sddm-theme** project by Fabio Almeida
(`3ximus/aerial-sddm-theme`), which plays Apple TV aerial videos behind an
SDDM login screen.

- Upstream repository: https://github.com/3ximus/aerial-sddm-theme
- Imported as: `chore: import 3ximus/aerial-sddm-theme upstream`
  (commit `2499e0d` on `main`).
- Upstream license: **GPL-3.0** (`LICENSE`, kept verbatim). This project
  stays GPL-3.0.
- Upstream attribution is preserved in `NOTICE` and in the original theme
  files (`metadata.desktop`, `README.md`).

## What HorneroOS changes

HorneroOS replaces the Apple TV footage (non-redistributable) with freely
licensed footage of Argentina, curated under `media/` with per-clip source
manifests, and ports the theme to Qt6. The upstream code remains credited
above; every new file in this repository is likewise GPL-3.0 unless its
own header says otherwise. Per-clip video licenses (CC BY / CC BY-SA) are
recorded in each manifest and summarized in `NOTICE`; they govern the
footage, not the code.

## What changed in the Qt6 migration (`feat/qt6-migration`)

- `Main.qml` and `components/` were ported from Qt5 (`QtQuick 2.0`,
  `QtMultimedia 5.7`, `Playlist`/`QMediaPlaylist`, `QtGraphicalEffects`)
  to Qt6 (`QtQuick`, `QtMultimedia` `MediaPlayer` + `VideoOutput`,
  `QtQuick.Effects` `MultiEffect`). `QMediaPlaylist` no longer exists in
  Qt6 and was replaced, not preserved.
- The upstream HTTP video playlists (`playlists/*.m3u`, streaming Apple TV
  aerial clips) were removed: the greeter must run with zero network
  access. They are replaced by a local sequencer: `components/MediaDeck.qml`
  driven by `components/MediaCatalog.js` and the generated `media/catalog.js` (built from `media/catalog.json`).
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

## Fidelity restoration (upstream look, Argentina footage)

The `feat/hornero-identity` redesign (cinematic hero, location label,
avatar, hairline fields, terracotta palette) was reverted: the greeter
now reproduces the upstream layout verbatim — centered clock column,
label-left login rows, top action bar, upstream fonts/sizes/colors —
and the ONLY intentional difference is local Argentina clips instead of
the streamed playlists. `tests/test_upstream_fidelity.py` pins this
contract (upstream values, structure, and the absence of redesign
markers). Kept from the port: the `MediaDeck` local sequencer, the
`FontLoader.name` read-only workaround, and the functional `theme.conf`
keys (`videoEnabled`, `crossfadeDuration`, `testMode`, golden-hour
window). Upstream `bgVidDay/bgVidNight` (`playlists/*.m3u`) stay out:
streaming playlists violate the offline invariant.

## Hornero identity (`feat/hornero-identity`, superseded)

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
