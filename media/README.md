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
      { "id": "ar-mis-iguazu-falls",
        "file": "media/base/ar-mis-iguazu-falls.mp4",
        "daypart": "day", "kind": "video" }
    ],
    "night": [
      { "id": "ar-pat-mountain-lake",
        "file": "media/base/ar-pat-mountain-lake.mp4",
        "daypart": "night", "kind": "video" }
    ]
  }
}
```

The 7 wired entries are the Argentina base pack rotation (Iguazu,
Perito Moreno x2, Ushuaia penguins, Buenos Aires, Bariloche by day; the
mountain lake dimmed at night as the interim night mood — see
`MEDIA_ROADMAP.md` gap 2 — until native night footage ships).
`ar-sa-salta-musicians` ships in the pack (licensed and attributed) but is
held out of rotation: visual QA showed close-up faces dominating the
frame behind the login fields. The runtime catalog is editorial — wiring
fewer entries than the pack ships is a supported state.

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

## Adding or replacing a clip

Clips are never committed: they are fetched, transcoded, and packed at
build time, and the theme resolves them through an install-time bridge.

1. Add a manifest under `media/manifests/` (see `manifest.schema.json`;
   validate with `scripts/validate-media-manifests.py`).
2. `python3 scripts/media/fetch.py --id <id>` (SHA256-verified, cached
   under `.cache/`), then `python3 scripts/media/build.py --id <id>`
   (deterministic H.264 profile, validated, world-readable under
   `build/media/base/`).
3. `python3 scripts/media/package.py` assembles
   `dist/hornero-greeter-media-base-<version>.tar.zst`, which installs to
   `/usr/share/hornero/greeter/media/base/`.
4. Wire one entry per file in `media/catalog.json` with a unique `id` and
   `file` exactly `media/base/<id>.mp4` (enforced offline by
   `tests/test_catalog_schema.py`), regenerate (`scripts/media/build-catalog`),
   and run the test suite (`pytest tests/`).
5. Ensure every file stays world-readable so the `sddm` user can read it
   (`scripts/media/audit.py` checks).

Install bridge: the `hornero-greeter` theme package installs the generated
`media/catalog.js` and symlinks `<theme>/media/base` to the media-base
pack directory. The link dangles when the pack is absent — a supported
state: the deck skips missing files and holds `background.jpg`.

## Playback behaviour (see `components/MediaDeck.qml`)

Random order with no immediate repeat, the next clip is preloaded while the
current one finishes, clips crossfade over the configurable
`crossfadeDuration` (2-4 s), broken files are skipped with a bounded retry
budget, and an empty or fully broken pack falls back to the static image.
