# Local media packs

The greeter plays video only from local files. It makes no network requests at
login. The editorial runtime catalog (`catalog.json`) holds two golden-hour
clips; day and night have no rights-cleared clip yet (see
`../MEDIA_ROADMAP.md`). A daypart without a clip shows an original designed
gradient (`components/resources/fallback-*.svg`), also used when video is
disabled, unavailable, or broken.

## Catalog and playback

`catalog.json` is the human-edited source of truth. `catalog.js` is generated
for synchronous QML import; regenerate it after catalog changes:

```sh
scripts/media/build-catalog
scripts/media/build-catalog --check
```

The QML deck chooses randomly within a populated daypart, avoids immediate
repeats, preloads the next clip, crossfades, skips broken files with bounded
retries, and holds the selected local still when a daypart has no playable
video. `theme.conf` is the sole source for day and golden-hour time windows.

Retired still/video provenance is archived in
`docs/archive/legacy-catalogue-2026/`. Pack membership is strict: only clips wired
in `catalog.json` are built and packaged, and retired ids are refused.
Attribution is in `NOTICE`. Source licenses are independent from the theme's
GPL source license.
