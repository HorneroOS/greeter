# Media codec decision: H.264 in MP4

Status: accepted. Runtime profile: `mp4 / H.264 / yuv420p / <=1080p /
<=30fps / no audio / faststart`, produced by `scripts/media/build.py`.

## Qt6 evidence

The Qt6 reference track (`origin/feat/qt6-migration`, `media/README.md`)
already standardizes on local `.mp4` files: its `catalog.json` schema
shows entries like `media/pack/day/coast-01.mp4`, and "Adding a pack"
says to copy `.mp4` files into `media/pack/day|night/`. Nothing on that
branch points at VP9/WebM. Staying with H.264 keeps the base pack
directly playable by both the legacy Qt5 `QtMultimedia` player and the
Qt6 `MediaDeck` sequencer without a re-encode.

## Benchmark (2026-09-14, ffmpeg n9.0.1, 1280x720p30 testsrc, 4 s)

| profile | command (essence) | size | encode wall |
| --- | --- | --- | --- |
| H.264 (chosen) | `libx264 -preset slow -crf 20 -pix_fmt yuv420p +faststart` | 75,323 B | < 1 s |
| VP9 | `libvpx-vp9 -b:v 0 -crf 30 -pix_fmt yuv420p` | 41,600 B | 2.4 s |

VP9 compresses synthetic content smaller, as expected. It loses on the
criteria that matter for a greeter:

1. **Decode cost at login.** H.264 has universal hardware decode
   (VA-API/VDPAU/NVDEC, GStreamer `openh264`); VP9 software decode
   burns CPU before the user even logs in.
2. **Stack compat.** SDDM's QtMultimedia backends (GStreamer,
   ffmpeg) play H.264 everywhere; VP9-in-WebM needs extra plugins on
   minimal ISO images.
3. **Qt6 alignment.** The reference catalog already expects `.mp4`.
4. **Determinism.** `libx264` with `-preset slow -crf 20
   -map_metadata -1 +faststart` gives byte-stable, instantly-starting
   local files; VP9 two-pass/CRF tuning adds build-time variance.

## Consequences

- `build.py` emits `.mp4` only; `package.py` ships the single
  `hornero-greeter-media-base` pack (`dist/*.tar.zst`).
- No VP9/WebM derivatives are produced. If future Qt6 evidence (real
  playback traces, not synthetic sizes) favors VP9, revisit this file
  with new measurements; the filter chain (`build_filter_chain`) is
  codec-agnostic and only the encoder block changes.
- SD sources (e.g. the 720x480 Bariloche slot) are never upscaled:
  upscaling spends bytes without adding detail. The manifest's
  center-crop box (`crop=720:405`) is applied; the `scale` note stays
  advisory.
- Frame rate is capped, never raised: sources above 30fps get
  `fps=30`; 24/25/30fps sources keep their native rate.
