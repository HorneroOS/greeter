# Argentina media collection

The previous collection (three daytime videos and two stills) was fully retired
for the cinematic Argentina replacement (HorneroOS/greeter#41). Source policy:
redistributable footage first (Wikimedia Commons CC0/CC-BY/CC-BY-SA, other
explicitly licensed sources). Pexels clips stay candidate-only; Pexels API key
issuance is paused as of 2026-11-17, so the permission-request drafts
(`docs/PEXELS_PERMISSION_REQUEST.md`) are the only Pexels path.

## Active scenes

| ID | Place | Creator / source | License | Daypart |
| --- | --- | --- | --- | --- |
| `ar-rn-dina-huapi-sunset` | Dina Huapi, Nahuel Huapi · Río Negro · Patagonia | Jmmuguerza · [Commons](https://commons.wikimedia.org/wiki/File:Atardecer_en_Dina_Huapi.webm) | CC BY-SA 4.0, own work | golden-hour |
| `ar-ba-dusk-timelapse` | Buenos Aires rooftops, sunset into blue hour · CABA · Pampeana | Mariano Cirigliano · [Commons](https://commons.wikimedia.org/wiki/File:Eclipse_Parcial_Lunar.webm) | CC BY 3.0, YouTube import reviewed by LicenseReviewerBot | golden-hour (ends in blue hour, not night) |

Golden-hour has two approved clips. Day and night have **no approved clip**: those dayparts show the designed
gradient fallback instead of a weak clip. Rejected after frame review
(2026-11-17, kept parked in `media/candidates/`): `ar-mis-iguazu-devils-throat`
(handheld, identifiable people), `ar-ba-haedo-sunset-east` (static suburban
rooftops), `ar-night-starlink-cc0` (near-black, noisy; the only verified CC0
Argentine night source). Also rejected: `ar-fsa-banado-la-estrella` (reviewed CC BY TV-news fragment, but burned-in channel logo, ticker and interviewees). Sources searched 2026-11-17 without a usable day or night find: Commons Argentina video categories, Commons CC0/self-published/YouTube-reviewed/Vimeo searches, Internet Archive (matches are NC/ND or non-scenic), NASA/NOAA public-domain (satellite imagery, not footage). Commons files marked "License review needed"
(Hornocal, Uquía, Salinas Grandes, Tilcara timelapse, Purmamarca) are not
usable until a reviewer confirms the YouTube license.

## Rights state

Pexels does not clearly authorise redistributing clips in a separate media
package (Terms of Service, last updated 2026-10-20, section 5: "You cannot sell
or distribute the Content ... on a Standalone basis"). Evidence and decision:
`docs/PEXELS_RIGHTS_EVIDENCE.md`. All Pexels clips are candidate-only.

## Candidate clips (nothing is verified, cleared, packaged or released)

| Ref | Manifest id | Pexels id | Place | Daypart | State |
| --- | --- | --- | --- | --- | --- |
| D1 | `ar-mza-potrerillos-drone` | 37382809 | Potrerillos, Mendoza | day | blocked: rights, API record unfetched |
| D2 | `ar-mis-iguazu-cataratas-aerial` | 33053999 | Iguazú, Misiones | day | blocked |
| D3 | `ar-ctc-piedra-pomez` | 37112523 | Piedra Pómez, Catamarca | day | blocked |
| D4 | `ar-rn-bariloche-aerial` | 33665907 | Bariloche, Río Negro | day | blocked, loop risk (8 s) |
| G1 | `ar-sc-fitz-roy-sunrise` | 33285416 | Fitz Roy, Santa Cruz | golden-hour | blocked, top priority |
| G2 | `ar-ju-hornocal-golden` | 18210885 | Hornocal, Jujuy | golden-hour | blocked, loop risk (8 s) |
| G3 | `ar-pat-river-sunset` | 38921813 | unconfirmed Patagonian river | golden-hour | blocked, geography unverified |
| N1 | `ar-ba-dusk-skyscrapers` | 34075564 | Buenos Aires | golden-hour (dusk, not night) | blocked |
| N2 | `ar-ba-skyline-sunset` | 36229695 | Buenos Aires | golden-hour (sunset, not night) | blocked |
| R1 | `ar-sa-cafayate-red-rocks` | 36783241 | Cafayate, Salta | day (reserve) | blocked |
| R2 | `ar-mza-andes-aerial` | 37382839 | unconfirmed Andes | day (reserve) | blocked |

No genuine Argentine night footage has been sourced; the night bucket stays
empty and shows the designed night gradient. Retired records are archived in
`docs/archive/legacy-catalogue-2026/`.

## Other reviewed sources

| ID / status | Place · original | Source / creator | Rights state | Editorial decision |
| --- | --- | --- | --- | --- |
| `ar-ba-buenos-aires` · inactive | Buenos Aires · 1280×720, 31.2 s | [Commons](https://commons.wikimedia.org/wiki/File:Buenos_Aires_-_Argentina.webm) · Neoredacturus | CC BY-SA 4.0, own work | Removed from rotation: prominent commercial signage competes with the login scene. |
| `ar-mis-iguazu-falls` · inactive | Iguazú Falls · 1280×720, 61.9 s | [Commons](https://commons.wikimedia.org/wiki/File:Iguazu_Falls_(Cataratas_de_Iguasu)_in_Argentina.webm) · redwing115 via YouTube | CC BY 3.0, external source reviewed by McZusatz in 2013 | Superseded by the newly reviewed 1080p own-work Iguazú panorama; preserved as source history, not in default pack. |
| `ar-rn-bariloche` · inactive | Bariloche · 720×480, 17.7 s | [Commons](https://commons.wikimedia.org/wiki/File:San_Carlos_de_Bariloche,_Argentina.ogv) · Gabo2012 | CC BY-SA 3.0, own work | Not shipped by default: soft SD source; seek a crisp Nahuel Huapi replacement. |
| `ar-sc-perito-moreno-wall` · inactive | Perito Moreno · 2160×3840, 50 s | [Commons](https://commons.wikimedia.org/wiki/File:Muro_de_hielo_del_Glaciar_Perito_Moreno_en_el_Lago_Argentino.webm) · Brandon Antonio Segura Torres & Priscilla Vieto Bonilla | CC BY-SA 4.0, own work | Retained as provenance/history, not rotated: portrait crop overlaps the selected continuous pan. |
| `ar-sc-perito-moreno-calving` · inactive | Perito Moreno · 2160×3840, 20.7 s | [Commons](https://commons.wikimedia.org/wiki/File:Desprendimiento_de_iceberg_en_glaciar_Perito_Moreno.webm) · Brandon Antonio Segura Torres & Priscilla Vieto Bonilla | CC BY-SA 4.0, own work | Excluded from the initial rotation: portrait action clip and same-source overlap. |
| `ar-sa-salta-musicians` · inactive | Salta · 640×480, 35 s | [Commons](https://commons.wikimedia.org/wiki/File:Street_musicians_(Salta,_Argentina).webm) · Viktor Pinchuk | CC BY 4.0, own work | Faces and close-up performance are too prominent behind login controls; low resolution. |
| `ar-pat-mountain-lake` · inactive | Unspecified Patagonia lake · 1280×720, 4 s | [Commons](https://commons.wikimedia.org/wiki/File:Un_lago_de_montana_en_la_Patagonia.webm) · Tamtam90 | CC BY-SA 4.0, own work | Excluded: the place is not identified and four seconds is too short for a calm background. |
| `ar-rn-dina-huapi-timelapse` · candidate | Dina Huapi / Nahuel Huapi · 1920×1080, 46.2 s | [Commons](https://commons.wikimedia.org/wiki/File:Time-lapse_of_Patagonia,_Argentina.webm) · Erico Schulz via Vimeo | CC BY 3.0 shown, external-source review still pending | Strong candidate; do not redistribute until the archived Vimeo grant has reviewer-confirmed evidence. |
| `ar-ju-pachamama` · candidate | Quebrada de Humahuaca area, Jujuy · 1920×1080, 568.1 s | [Commons](https://commons.wikimedia.org/wiki/File:Un_viaje_al_coraz%C3%B3n_de_la_Pachamama,_Jujuy,_Argentina.webm) · Eco Destinos via YouTube | CC BY 4.0 claimed, license-review-needed | Long vlog; rights review and a deliberate scenic segment are both required. |
| `ar-ju-purmamarca-salinas-vlog` · candidate | Purmamarca / Salinas Grandes · 1920×1080, 662.9 s | [Commons](https://commons.wikimedia.org/wiki/File:Purmamarca_y_Salinas_Grandes,_Jujuy,_Argentina.webm) · Gajes del Youtuber via YouTube | CC BY 3.0 claimed, license-review-needed | Long, large vlog; low editorial priority until Commons review clears. |
| `ar-noa-purmamarca-salinas-cafayate` · candidate | Purmamarca, Salinas Grandes, Salta, Cafayate · 2560×1440, 101.8 s | [Commons](https://commons.wikimedia.org/wiki/File:Purmamarca,_Las_Salinas_Grandes_de_Jujuy,_Salta_y_Cafayate.webm) · Views4k via YouTube | CC BY 3.0 claimed; license-review-needed | Highest-value NOA scout only if Commons review clears; long external-source transfer is not approved for redistribution. |

The stills are authored, cropped derivatives with source resolution, original
and derivative hashes, processing notes, source pages, and license evidence in
`docs/archive/legacy-catalogue-2026/`. Full video provenance is in `media/manifests/`.
`NOTICE` records the attributions. Media licenses are independent of the
theme's GPL source-code license.

## Provider model and the Pexels rights gate

Manifests are provider-neutral: `source.provider` (`wikimedia-commons` by
default, or `pexels`) is recorded separately from `license`, and
`review.distribution` records explicit approval for binary-package
redistribution. The packaged set fails closed for any provider/license
without recorded approval; existing Commons CC clips keep their exact
previous behaviour and no catalogue entry changed.

Pexels is a *candidate* provider only. Until written permission covering OS
greeter-background redistribution in a downloadable media package is
recorded (rights gate, issue #39; drafts in
`docs/PEXELS_PERMISSION_REQUEST.md`), Pexels-shaped manifests stay parked in
`media/candidates/`, `fetch.py` refuses them, and nothing non-Commons is
downloaded or shipped. `ar-example-pexels-fixture` in `candidates/` is a
synthetic shape fixture, not a clip.

## Editorial decisions

The catalog excludes the older Buenos Aires video because its signage is
visually distracting behind login controls; two portrait Perito Moreno clips
are replaced by one continuous wide crop; the Bariloche source is soft SD; the
Salta clip puts close-up faces behind the form; and the short Patagonian lake
clip does not identify its lake. Their manifests remain available as
historical/inactive source records, but the default media build packages only
IDs selected in `media/catalog.json`.

The candidate `ar-rn-dina-huapi-timelapse` is not promoted while the upstream
license grant still needs reviewer-confirmed evidence. Jujuy/Salta candidates
remain parked until their redistribution rights are verified. Never infer
permission from public availability or attribution alone.

## Coverage gaps

- Nighttime video: Buenos Aires or southern landscapes with verified
  redistribution rights.
- Northwest landscapes: Salinas Grandes, Purmamarca, Hornocal, or Cafayate.
- Stronger Patagonia Norte, Atlantic coast / Península Valdés, Cuyo / Aconcagua,
  Córdoba Sierras, and Fitz Roy / El Chaltén material.

These are search directions, not promises or geographic quotas. Keep the still
fallbacks until a video is both visually strong and cleared for redistribution.

## Reproduce and validate

Originals are fetched from their manifest source and SHA256-verified into the
ignored `.cache/` directory. `scripts/media/build.py` applies each selected
manifest's trim and crop, strips audio, creates H.264 runtime files, and
validates output. The default build selects only IDs in `media/catalog.json`;
`--id` is useful for a single clip. `scripts/media/package.py` assembles the
installable media pack. Video binaries are not stored in Git.

```sh
python3 scripts/validate-media-manifests.py
python3 scripts/media/fetch.py --id ar-sc-perito-moreno-pan
python3 scripts/media/build.py
scripts/media/build-catalog
scripts/media/build-catalog --check
pytest tests/
```

The website preview generator consumes the same approved source manifests and
runtime outputs. It makes separate, smaller web previews and posters; it never
changes the desktop pack. See `media/README.md` for that workflow.
