# Contributing media to the greeter

English only, here and in every manifest. No video binaries in git. The
theme may include optimized still derivatives; each needs a provenance JSON
record under `media/stills/` and must be listed in `NOTICE` and installed by
the theme package.

## Provider and license model

A manifest records **where a clip comes from** separately from **under what
license it may be redistributed**:

- `source.provider`: `wikimedia-commons` (the default when absent, so every
  pre-existing manifest keeps its meaning) or `pexels`.
- `license.short` / `license.url`: the actual license. Commons sources use a
  CC license below. Pexels sources use `Pexels` with
  `https://www.pexels.com/license/` — the Pexels License is **not** a
  Creative Commons license and must never be recorded as one.
- `review.distribution`: explicit approval state for binary-package
  redistribution (`approved`, `pending`, `not-approved`). The shippable set
  **fails closed**: a provider/license without recorded approval evidence is
  never packaged. Legacy Commons CC manifests carry no such field; for them
  a shippable `review.status` remains the recorded approval, exactly as
  before. Non-Commons sources need explicit `approved` with the permission
  evidence quoted in `review.evidence`.

Allowlists and the shippable computation have one source of truth,
`scripts/media/common.py`; the validator, audit, and schema are cross-checked
against it by `tests/test_media_pipeline.py`.

### Rights gate for Pexels (issue #39)

No Pexels clip ships today. The Pexels License does not by itself grant the
redistribution this project performs (transcoded clips inside a downloadable
OS media package), so each Pexels candidate stays in `media/candidates/`
with `review.distribution: not-approved` until written permission is
recorded. `scripts/media/fetch.py` refuses Pexels sources for the same
reason — it never scrapes or invents download URLs. Ready-to-send permission
requests live in `docs/PEXELS_PERMISSION_REQUEST.md`. The synthetic
`media/candidates/ar-example-pexels-fixture.json` proves the manifest shape
offline; it is a fixture, not a real clip.

## License policy (hard rules)

- Accepted licenses for Commons sources: **CC0, CC-BY, CC-BY-SA** (any of
  3.0 / 4.0 where versioned). Pexels sources are representable as candidates
  under the Pexels License but ship only past the rights gate above.
- Accepted provenance, one of:
  - `own-work`: the Commons uploader asserts it is their own work under
    the stated license (Self-published work category);
  - `reviewed`: a third-party transfer (YouTube, Vimeo, Flickr) with a
    reviewer name + date or a reviewed-licenses category on the file page;
  - `written-permission`: permission archived on the file page (OTRS/VRT
    ticket or equivalent), quoted in `review.evidence`.
- Anything else (`license-review-needed`, `review-pending`) goes to
  `media/candidates/` and **never** ships. The validator enforces this.

## Still backgrounds

Stills require the same source-rights review as video; credit alone is not a
redistribution grant. Keep the original outside Git and record the source
page, author, license, evidence, original dimensions/hash, derivative
dimensions/hash, crop/encoding steps, and role in `media/stills/<id>.json`.
Commit only the optimized derivative used by the theme, add its author and
source to `NOTICE`, install it in the theme package, and test the configured
daypart fallback with the media pack absent. A still fallback is not a video
scene and must not appear in the runtime video catalog.

## How to propose a clip

1. Find footage of Argentina on Wikimedia Commons. Prefer landscape
   (16:9), daylight, silent or strippable-audio clips of 10-60 s.
2. Open the **file description page** and verify: author, source, license
   template, and review status (search the page for `LicenseReview` and
   check the categories for `License review needed`).
3. Copy `media/fixtures/sample-manifest.json` to
   `media/manifests/ar-<id>.json` (or to `media/candidates/` if parked)
   and fill every field:
   - `location`: place, province, region, country (`Argentina`).
   - `source.page`: the Commons file page URL (source-side metadata;
     allowed here, never in runtime files).
   - `license`: short code, full name, canonical license URL.
   - `review`: status, reviewer/date when applicable, and the evidence
     you saw (template text, category names).
   - `original`: byte size, SHA256 of the file you downloaded,
     duration, dimensions, container (`webm`, `ogv`, or `mp4`). Never invent
     a hash: download the original and hash it. Sizes must match the
     provider file page.
   - `dayparts`: any of `day`, `golden-hour`, `night` (daylight footage is
     `day`; sunset-lit footage is `golden-hour`).
   - `edit`: trim window inside the real duration, crop plan
     (portrait and 4:3 sources need a 16:9 center-crop note), scale
     target, and `audio` (`strip`, or `none` if the file has no audio
     track). The greeter always plays muted.
   - `notes`: anything the transcoder or the next curator must know.
4. Run the validator and fix everything it reports:
   `python3 scripts/validate-media-manifests.py`
5. Open a pull request. Every PR must be green before merge.

## Runtime constraints your clip must respect

- **Zero network at runtime.** Transcoded clips ship with the theme;
  the greeter never downloads or streams. No URLs in QML or configs
  (the validator scans them; GPL license-header URLs are ignored).
  Source-page and license URLs live only in manifests and docs, never in
  runtime files. The legacy `playlists/*.m3u` Apple-stream references are
  upstream leftovers owned by the Qt6 port track, which replaces them
  with local files built from these manifests.
- **No Qt5-isms, no shell execution, no new dotfile dependencies.**
- Transcoded files must be readable by the `sddm` user (0644/0755).
- Attribution: credit the creator in `NOTICE` when your clip ships.

## Promoting a candidate

Follow `media/candidates/README.md`: confirm the license on the Commons
page, fetch the original, record SHA256, pick trim/crop, move the manifest
to `media/manifests/`, and update `MEDIA_ROADMAP.md` (coverage table up,
gap down) and `NOTICE` (new creator line).
