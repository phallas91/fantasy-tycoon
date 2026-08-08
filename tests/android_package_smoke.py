#!/usr/bin/env python3
"""Inspect a Godot Android export without requiring Android tooling."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"ANDROID_PACKAGE_SMOKE: FAIL: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: android_package_smoke.py <apk-or-aab>")

    package = Path(sys.argv[1])
    if package.suffix.lower() not in {".apk", ".aab"}:
        fail(f"unsupported package type: {package.suffix}")
    if not package.is_file() or package.stat().st_size < 1_000_000:
        fail(f"package is missing or implausibly small: {package}")

    try:
        with zipfile.ZipFile(package) as archive:
            bad_entry = archive.testzip()
            if bad_entry:
                fail(f"corrupt ZIP entry: {bad_entry}")
            names = set(archive.namelist())
    except zipfile.BadZipFile as exc:
        fail(f"invalid ZIP container: {exc}")

    if package.suffix.lower() == ".apk":
        manifest = "AndroidManifest.xml"
        arm64_prefix = "lib/arm64-v8a/"
    else:
        manifest = "base/manifest/AndroidManifest.xml"
        arm64_prefix = "base/lib/arm64-v8a/"

    if manifest not in names:
        fail(f"missing manifest: {manifest}")
    arm64_libraries = sorted(
        name for name in names if name.startswith(arm64_prefix) and name.endswith(".so")
    )
    if not arm64_libraries:
        fail("package contains no ARM64 native library")

    print(
        f"ANDROID_PACKAGE_SMOKE: PASS ({package.name}, "
        f"{package.stat().st_size / 1_000_000:.1f} MB, "
        f"{len(arm64_libraries)} ARM64 libraries)"
    )


if __name__ == "__main__":
    main()
