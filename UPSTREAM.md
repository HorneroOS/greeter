# Upstream provenance

This theme starts from the **aerial-sddm-theme** project by Fabio Almeida
(`3ximus/aerial-sddm-theme`), which plays Apple TV aerial videos behind an
SDDM login screen.

- Upstream repository: https://github.com/3ximus/aerial-sddm-theme
- Imported as: `chore: import 3ximus/aerial-sddm-theme upstream`
  (commit `d198df6` on `main`).
- Upstream license: **GPL-3.0** (`LICENSE`, kept verbatim). This project
  stays GPL-3.0.
- Upstream attribution is preserved in `NOTICE` and in the original theme
  files (`metadata.desktop`, `README.md`).

## What HorneroOS changes

HorneroOS replaces the Apple TV footage (non-redistributable) with freely
licensed footage of Argentina, curated under `media/` with per-clip source
manifests, and ports the theme to Qt6. The upstream code remains credited
above; every new file in this repository is likewise GPL-3.0 unless its
own header says otherwise. Per-clip video licenses (CC BY / CC BY-SA) are
recorded in each manifest and summarized in `NOTICE`; they govern the
footage, not the code.
