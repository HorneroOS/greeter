# Media roadmap: Argentina footage for the greeter

Status: 8 shipped clips, 7 locations, 5 provinces + CABA. All shipped
clips are CC BY / CC BY-SA (own work or reviewer-confirmed) with verified
SHA256 hashes. 4 candidates are parked in `media/candidates/` until their
license reviews clear.

## Shipped coverage

| clip | place | province | region | license |
| --- | --- | --- | --- | --- |
| `ar-ba-buenos-aires` | Buenos Aires | CABA | Pampas | CC BY-SA 4.0 |
| `ar-mis-iguazu-falls` | Puerto Iguazu | Misiones | Litoral | CC BY 3.0 (reviewed) |
| `ar-sc-perito-moreno-wall` | El Calafate | Santa Cruz | Patagonia | CC BY-SA 4.0 |
| `ar-sc-perito-moreno-calving` | El Calafate | Santa Cruz | Patagonia | CC BY-SA 4.0 |
| `ar-tdf-ushuaia-penguins` | Ushuaia | Tierra del Fuego | Patagonia Austral | CC BY-SA 4.0 |
| `ar-rn-bariloche` | Bariloche | Rio Negro | Patagonia Norte | CC BY-SA 3.0 |
| `ar-sa-salta-musicians` | Salta | Salta | NOA | CC BY 4.0 |
| `ar-pat-mountain-lake` | unspecified lake | unspecified | Patagonia | CC BY-SA 4.0 |

## Gaps (in priority order)

1. **NOA landscapes (Hornocal / Salinas Grandes / Purmamarca / Cafayate).**
   No shippable clip yet. Three Jujuy/Salta files are parked as
   `license-review-needed` (`ar-noa-purmamarca-salinas-cafayate` is the
   best: 1440p aerials). Action: watch their Commons review queues; the
   moment one clears, promote it per `media/candidates/README.md`.
2. **Night / dusk footage.** Every shipped clip is daylight, so the night
   playlist has no native material yet. Wanted: Buenos Aires at night,
   starry Patagonia/Andes. Interim (implemented): the night bucket reuses
   the calmest daylight clip dimmed by the theme's blur/dim layer
   (`ar-pat-mountain-lake`) until a native night clip ships.
   `ar-sa-salta-musicians` was tried at night and held out (close-up faces
   behind the login fields).
3. **Atlantic coast (Mar del Plata / Puerto Madryn / Valdes).** Surveyed
   Commons video results were event/archival footage, nothing scenic and
   freely licensed. Keep searching; a coast clip balances the Andes-heavy
   catalog.
4. **Cuyo / Mendoza scenic footage.** Surveyed hits were satellite weather
   loops and unrelated people named Mendoza. Wanted: Andes vineyards or
   Aconcagua daylight.
5. **Cordoba (Sierras).** Surveyed hits were Spain's Cordoba, civic events,
   or archival industrial film. Wanted: Sierras de Cordoba daylight.
6. **El Chalten / Fitz Roy.** No suitable Commons video found in this pass.
7. **HD Bariloche replacement.** `ar-rn-bariloche` is SD (720x480 Theora)
   and `ar-rn-dina-huapi-timelapse` (1080p, silent, Nahuel Huapi) is parked
   as `review-pending`. Promoting the timelapse fixes Patagonia Norte
   quality in one move: verify its archived Vimeo source license first.
8. **Locate `ar-pat-mountain-lake`.** The source page names no lake;
   province is recorded as Unspecified. Ask the author or replace the clip.

## Near-duplicates and alternates (deliberately not shipped)

- `Paneo a Glaciar Perito Moreno` (same authors, same shoot as the two
  Perito clips): alternate if a third Santa Cruz slot is ever needed.
- `Time-lapse of Patagonia, Argentina (short)`: cut-down of the parked
  timelapse; inherits the same review problem.

## Transcode queue (build time, not in git)

For each shipped manifest: fetch original by SHA256, apply the manifest
`edit` (trim/crop), transcode to the runtime codec, strip audio, install
under the runtime video directory with `sddm`-readable permissions
(0644 files / 0755 dirs). No video binaries are ever committed.
