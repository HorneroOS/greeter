# Local media packs

The greeter plays background video **only from local files**. There is no
network access at runtime: the old upstream `playlists/*.m3u` files that
streamed Apple TV aerial videos over HTTP were removed during the Qt6
migration.

## Catalog schema (`catalog.json`)

```json
{
  "version": 1,
  "fallbackImage": "background.jpg",
  "dayparts": {
    "day": [
      { "id": "coast-day-01", "file": "media/pack/day/coast-01.mp4",
        "daypart": "day", "kind": "video" }
    ],
    "night": []
  }
}
```

- `version`: integer, must be `1`.
- `fallbackImage`: path relative to the theme root, shown when a daypart
  has no playable video (missing pack, all files broken, or
  `videoEnabled=false`). Must be a local file, never a URL.
- `dayparts.day` / `dayparts.night`: required arrays of entries.
  `dayparts.golden-hour` is optional (evening mood, defaults to empty).
  Each entry needs a unique `id`, a local relative `file`, a `daypart` of
  `day`, `golden-hour`, `night`, or `any`, and a `kind` of `video` (only
  `video` entries are sequenced).
- `file` must be a relative path. Absolute paths, `~`, `$HOME`, and any
  `http://` / `https://` URL are rejected by the unit tests.

## Source manifest vs runtime catalog

`catalog.json` is the human-editable source of truth. The greeter itself
reads the GENERATED `catalog.js` (a QML-importable module produced by
`scripts/media/build-catalog`), because Qt disables `XMLHttpRequest` GET on
local files by default — an XHR-loaded catalog silently never arrives and no
video ever plays. After editing `catalog.json`, regenerate and keep both
files committed:

```sh
scripts/media/build-catalog        # regenerate media/catalog.js
scripts/media/build-catalog --check  # CI gate: fail when out of sync
```

## Adding a pack

1. Copy `.mp4` files into `media/pack/day/` and/or `media/pack/night/`
   (and/or a `golden-hour` set).
2. Add one entry per file with a unique `id`.
3. Regenerate (`scripts/media/build-catalog`) and run the test suite
   (`pytest tests/`) to validate the catalog.
4. Ensure every file stays world-readable so the `sddm` user can read it.

## Playback behaviour (see `components/MediaDeck.qml`)

Random order with no immediate repeat, the next clip is preloaded while the
current one finishes, clips crossfade over the configurable
`crossfadeDuration` (2-4 s), broken files are skipped with a bounded retry
budget, and an empty or fully broken pack falls back to the static image.
