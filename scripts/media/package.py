#!/usr/bin/env python3
"""Assemble the distributable hornero-greeter-media-base pack.

Reads build/media/base/ (see build.py) and writes a reproducible
tarball:

    dist/hornero-greeter-media-base-<version>.tar.zst

Tarball layout (prefix hornero-greeter-media-base/):
    base/<id>.mp4 + base/<id>.sha256
    base/catalog.json + base/catalog.csv
    base/MEDIA_LICENSES.md + base/ATTRIBUTION.md

Reproducibility: sorted entries, uid/gid 0, fixed mtime. Permissions
are normalized to 0644 files / 0755 dirs so the sddm user can read
every runtime file after install.

Only the base pack is built by this script: one pack, one tarball.

    python3 scripts/media/package.py [--version <ver>]

Requires: tar, zstd. Stdlib otherwise.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD_BASE_DIR, DIST_DIR, PACK_NAME, REPRO_MTIME  # noqa: E402

REQUIRED_GENERATED = ("catalog.json", "catalog.csv",
                      "MEDIA_LICENSES.md", "ATTRIBUTION.md")


def run(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {proc.stderr.strip()[-2000:]}")
    return proc


def tar_supports(flag):
    """True when this tar build accepts *flag* (minimal builds vary)."""
    probe = subprocess.run(["tar", flag, "--help"],
                           capture_output=True, text=True)
    return "unrecognized option" not in probe.stderr


def main(argv=None):
    parser = argparse.ArgumentParser(description="package the media base pack")
    parser.add_argument("--version", default="1.0.0")
    args = parser.parse_args(argv)
    for tool in ("tar", "zstd"):
        if shutil.which(tool) is None:
            print(f"missing required tool: {tool}", file=sys.stderr)
            return 2
    if not BUILD_BASE_DIR.is_dir():
        print(f"nothing to pack: {BUILD_BASE_DIR} missing (run build.py)",
              file=sys.stderr)
        return 1
    mp4s = sorted(BUILD_BASE_DIR.glob("*.mp4"))
    if not mp4s:
        print(f"nothing to pack: no .mp4 in {BUILD_BASE_DIR}", file=sys.stderr)
        return 1
    missing = [n for n in REQUIRED_GENERATED if not (BUILD_BASE_DIR / n).is_file()]
    if missing:
        print(f"missing generated files: {', '.join(missing)} (run build.py)",
              file=sys.stderr)
        return 1
    for mp4 in mp4s:
        if not mp4.with_suffix(".sha256").is_file():
            print(f"missing sidecar: {mp4.name}.sha256", file=sys.stderr)
            return 1

    stage = BUILD_BASE_DIR.parent.parent / ".pack-stage"
    if stage.exists():
        shutil.rmtree(stage)
    dest_root = stage / PACK_NAME / "base"
    dest_root.mkdir(parents=True)
    for path in sorted(BUILD_BASE_DIR.iterdir()):
        if path.is_file():
            shutil.copy2(path, dest_root / path.name)
    # Normalize permissions: sddm-readable 0644 files / 0755 dirs.
    for path in sorted(stage.rglob("*")):
        if path.is_dir():
            path.chmod(0o755)
        else:
            path.chmod(0o644)

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    out = DIST_DIR / f"{PACK_NAME}-{args.version}.tar.zst"
    file_list = sorted(str(p.relative_to(stage))
                       for p in (stage / PACK_NAME).rglob("*") if p.is_file())
    list_file = stage / "filelist.txt"
    list_file.write_text("\n".join(file_list) + "\n", encoding="utf-8")
    tar_cmd = ["tar"]
    for flag in ("--sort-name", "--owner=0", "--group=0",
                 f"--mtime=@{REPRO_MTIME}"):
        if tar_supports(flag):
            tar_cmd.append(flag)
    # The file list is always pre-sorted, so entry order is deterministic
    # even on minimal tar builds without --sort-name.
    tar_cmd += ["-cf", str(stage / "pack.tar"),
                "-C", str(stage), "-T", str(list_file)]
    run(tar_cmd)
    # Compress to the final tarball (zstd -19, no extra timestamp).
    with open(out, "wb") as handle:
        proc = subprocess.run(["zstd", "-19", "-c", str(stage / "pack.tar")],
                              stdout=handle, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        print(f"zstd failed: {proc.stderr.strip()[-1000:]}", file=sys.stderr)
        return 1
    shutil.rmtree(stage)
    out.chmod(0o644)
    print(f"pack OK: {out.name} ({len(mp4s)} clip(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
