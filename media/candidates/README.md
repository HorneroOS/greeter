# Parking lot: clips that must NOT ship yet

Files in this directory use the same schema as `../manifests/` (see
`../manifest.schema.json`), but their `review.status` is
`license-review-needed` or `review-pending`. That is the whole point of
this directory: a clip lives here until a reviewer confirms its license
on the Wikimedia Commons file page.

## Rules

1. Nothing in `media/candidates/` is converted, packaged, or referenced
   by runtime playlists. The validator (`scripts/validate-media-manifests.py`)
   fails if a `license-review-needed` / `review-pending` entry appears in
   `media/manifests/`.
2. To promote a candidate: confirm the license on the Commons file page
   (reviewer name + date, or a `reviewed licenses` category), download the
   original, record its SHA256 and byte size, pick trim/crop, then move the
   manifest to `media/manifests/` with `review.status` set to `reviewed`
   (or `own-work` / `written-permission` with evidence).
3. `original.sha256` is null here on purpose: these originals were never
   fetched. Never invent a hash; fill it in when you promote.

## Current candidates

| id | why it is parked |
| --- | --- |
| `ar-ju-pachamama` | YouTube CC BY 4.0 claim, bare `LicenseReview`, category `License review needed (video)`. |
| `ar-noa-purmamarca-salinas-cafayate` | YouTube CC BY 3.0 claim, bare `LicenseReview`, `License review needed (video)`. Highest-value NOA file once cleared. |
| `ar-ju-purmamarca-salinas-vlog` | YouTube CC BY 3.0 claim, bare `LicenseReview`, `License review needed (video)`; 703 MB vlog, lowest priority. |
| `ar-rn-dina-huapi-timelapse` | Vimeo CC BY 3.0 claim via video2commons with no reviewer confirmation; verify the archived Vimeo source license first. |
