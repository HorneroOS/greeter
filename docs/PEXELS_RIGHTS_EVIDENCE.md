# Pexels rights evidence (rights gate, issue #39)

Reviewed 2026-11-17 from the official pages. Quotes are verbatim.

| Source | URL | Date on page |
| --- | --- | --- |
| Pexels License | https://www.pexels.com/license/ | none shown (footer 2026) |
| Terms of Service | https://www.pexels.com/terms-of-service/ | "Last updated: October 20th, 2026" |
| API documentation | https://www.pexels.com/api/documentation/ | none shown |

## Clauses

- License: "All photos and videos on Pexels are free to use." and "You can modify the photos and videos from Pexels."
- License: "Don't redistribute or sell the photos and videos on other stock photo or wallpaper platforms."
- License: "Don't sell unaltered copies of a photo or video, e.g. as a poster, print or on a physical product."
- Terms s.5: "You cannot sell or distribute the Content (either in digital or physical form) on a Standalone basis." Standalone means "where no creative effort has been applied to the Content and it remains in substantially the same form", including as a "video ... or other digital file".
- Terms s.8: "Bulk, large-scale or systematic copying of Content is strictly prohibited unless explicit permission", and scraping or automatic data collection programs are prohibited.
- API: "Authorization is required for the Pexels API." Rate limit 200 requests/hour and 20,000/month; circumventing it ends API access. "Whenever you are doing an API request make sure to show a prominent link to Pexels." Storage, caching and redistribution of API results are not addressed.

## Decision

Using a clip as login-screen background inside the product is within the License. Shipping the clips in a **separate downloadable media package** (`hornero-greeter-media-base`) is a distribution of the Content as a downloadable video file. The package adds trimming, cropping and transcoding, but no creative work beyond that, and the project's own brief states those edits alone do not make a file non-standalone. The Terms do not authorise this and the standalone clause plausibly forbids it. The API page says nothing that grants redistribution.

**Result: not authorised. Every Pexels clip is CANDIDATE-ONLY.** All 11 manifests in `media/candidates/` carry `review.distribution: not-approved`; `is_shippable` fails closed, `fetch.py` refuses Pexels and the validator rejects any such file in `media/manifests/`. No clip may be fetched for packaging, published in the pack, or promoted until written permission from Pexels (and, if they require it, each creator) is recorded in `review.evidence` with `review.distribution: approved`.

Local, non-redistributed evaluation (a developer viewing clips for editorial review) is a different gate from public distribution and is not blocked by this finding. Evaluation files stay in `.cache/` and never enter Git, the pack or the website.

## Paths forward

1. Send the drafts in `docs/PEXELS_PERMISSION_REQUEST.md` (to Pexels, then to each creator). Nothing has been sent.
2. Redistribution-compatible substitutes: Wikimedia Commons CC0/CC-BY/CC-BY-SA Argentine footage (the existing Commons pipeline already supports it), creators' own CC releases, or public-source footage. Every substitute needs its own license review.
3. Genuinely Argentine night footage is still unsourced in all cases.

## What is not done and why

Candidate manifests list `original.verified: false`: bytes, SHA256, duration and dimensions are null because the Pexels API record has not been fetched (no `PEXELS_API_KEY` is available to this workflow) and no download URL is ever guessed. Titles, creators, ids and dayparts come from the 2026-11-13 editorial research and are unverified.
