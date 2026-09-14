# Contributing media to the greeter

English only, here and in every manifest. No video binaries in git:
manifests plus tiny JSON fixtures are the only media files committed.

## License policy (hard rules)

- Accepted licenses: **CC0, CC-BY, CC-BY-SA** (any of 3.0 / 4.0 where versioned).
- Accepted provenance, one of:
  - `own-work`: the Commons uploader asserts it is their own work under
    the stated license (Self-published work category);
  - `reviewed`: a third-party transfer (YouTube, Vimeo, Flickr) with a
    reviewer name + date or a reviewed-licenses category on the file page;
  - `written-permission`: permission archived on the file page (OTRS/VRT
    ticket or equivalent), quoted in `review.evidence`.
- Anything else (`license-review-needed`, `review-pending`) goes to
  `media/candidates/` and **never** ships. The validator enforces this.

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
     duration, dimensions, container. Never invent a hash: download the
     original and hash it. Sizes must match the Commons file page.
   - `dayparts`: `day`, `night`, or both (daylight footage is `day`).
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
