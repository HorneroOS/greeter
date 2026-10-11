# Local media packs

The greeter plays video only from local files. It makes no network requests at
login. The editorial runtime catalog (`catalog.json`) selects three daylight
videos. Golden hour and night currently have no selected video: `theme.conf`
provides local, licensed still backgrounds for those moods. The day fallback
remains `background.jpg` when video is disabled, unavailable, or broken.

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

The standalone still records under `media/stills/` include original and
derivative hashes, source dimensions, creator, license, source URL, review
evidence, processing notes, and runtime role. Their generated derivatives are
1920x1080 JPEGs; the night fallback is about 496 KiB and the golden-hour image
about 236 KiB in this checkout. Attribution is in `NOTICE`. These source
licenses are independent from the theme's GPL source license.

## Adding or replacing video

Video binaries are never committed. They are fetched, verified, transcoded,
and packaged during the build.

1. Add a provenance-complete manifest under `manifests/`; validate it with
   `python3 scripts/validate-media-manifests.py`.
2. Review source rights for redistribution, editing, and packaging. A public
   URL or attribution is not permission. Keep uncertain media in
   `candidates/` until evidence is recorded.
3. Fetch the original by manifest ID. SHA256 is checked and originals are
   cached under ignored `.cache/`:

   ```sh
   python3 scripts/media/fetch.py --id <id>
   ```

4. Put only approved video IDs in `catalog.json`. The default build packages
   only those catalogued IDs; `--id` builds one clip for inspection. Per
   manifest, the build applies trim/crop, scales to the runtime profile,
   strips audio, and validates H.264 output:

   ```sh
   python3 scripts/media/build.py
   python3 scripts/media/build.py --id <id>
   ```

5. Regenerate the QML catalog, package the base media pack, then run
   `pytest tests/` and the media audit. Files installed for SDDM must remain
   world-readable (0644 files, 0755 directories).

The Arch theme package installs the stills and generated catalog, and links
`media/base` to `/usr/share/hornero/greeter/media/base/` supplied by the
separate media-base package. A missing pack is supported: QML keeps the local
fallback visible.

## Website previews

The website does not serve the desktop media pack. Its preview assets are
generated separately from the same approved originals and edits, at web-sized
resolution and bitrate, with a poster image for every scene. Static stills
are copied from the approved theme derivatives. The website's scene data is
generated from these manifests and the pinned greeter source revision; do not
maintain a second hand-written scene list. See `scripts/media/export-web-previews.py`
and the HorneroOS website data-sync documentation for the reproducible flow.

## Safe preview

Use the isolated Qt6 SDDM test mode or repository preview script. Do not restart
SDDM or replace the active graphical session to inspect media changes.
