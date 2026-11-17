.pragma library
// GENERATED from catalog.json — do not edit by hand.
// Regenerate: scripts/media/build-catalog
// The greeter imports this module synchronously; it must never be fetched
// over the network at runtime (see AGENTS.md no-runtime-network invariant).
var CATALOG = {
  "dayparts": {
    "day": [],
    "golden-hour": [
      {
        "daypart": "golden-hour",
        "file": "media/base/ar-rn-dina-huapi-sunset.mp4",
        "id": "ar-rn-dina-huapi-sunset",
        "kind": "video"
      },
      {
        "daypart": "golden-hour",
        "file": "media/base/ar-ba-dusk-timelapse.mp4",
        "id": "ar-ba-dusk-timelapse",
        "kind": "video"
      }
    ],
    "night": []
  },
  "fallbackImage": "components/resources/fallback-day.svg",
  "version": 1
};
// On-screen scene credits (Hornero Signal bottom rail), derived from the
// rights-reviewed manifests of wired clips and shipped stills only.
var CREDITS = {
  "ar-ba-dusk-timelapse": {
    "creator": "Mariano Cirigliano",
    "license": "CC BY 3.0",
    "place": "Buenos Aires city",
    "title": "Buenos Aires rooftops from sunset into blue hour (time-lapse)"
  },
  "ar-rn-dina-huapi-sunset": {
    "creator": "Jmmuguerza",
    "license": "CC BY-SA 4.0",
    "place": "Dina Huapi, Nahuel Huapi lake",
    "title": "Sunset over Nahuel Huapi from Dina Huapi"
  }
};
