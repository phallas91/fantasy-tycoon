#!/usr/bin/env python3
"""Fail CI when the Play Store listing drifts from the active game identity."""

from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
META = ROOT / "fastlane" / "metadata" / "android"
LOCALES = ("en-US", "pt-PT")
FORBIDDEN = ("drone tycoon", "sky fleet", "com.lpcf.dronetycoon", "bananaware")


def read(path: Path) -> str:
    assert path.is_file(), f"Missing store file: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8").strip()


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"Not a PNG: {path.relative_to(ROOT)}"
    return struct.unpack(">II", data[16:24])


for locale in LOCALES:
    base = META / locale
    title = read(base / "title.txt")
    short = read(base / "short_description.txt")
    full = read(base / "full_description.txt")
    changelog = read(base / "changelogs" / "70.txt")

    assert title == "Arcane Trade Empire", f"Wrong title for {locale}: {title}"
    assert len(title) <= 30, f"Title exceeds Play limit for {locale}"
    assert len(short) <= 80, f"Short description exceeds Play limit for {locale}"
    assert "Arcane Trade Empire" in full, f"Full description lacks brand for {locale}"

    listing = "\n".join((title, short, full, changelog)).lower()
    for stale in FORBIDDEN:
        assert stale not in listing, f"Legacy identity '{stale}' remains in {locale}"

    assert png_size(base / "images" / "featureGraphic.png") == (1024, 500), \
        f"Wrong feature graphic dimensions for {locale}"
    assert png_size(base / "images" / "icon.png") == (512, 512), \
        f"Wrong icon dimensions for {locale}"

for doc in (ROOT / "docs" / "ADMOB_INTEGRATION.md", ROOT / "docs" / "CLOUD_SAVE_SETUP.md"):
    lowered = read(doc).lower()
    assert "com.arcanetrade.empire" in lowered, f"Active package missing from {doc.name}"
    assert "com.lpcf.dronetycoon" not in lowered, f"Legacy package remains in {doc.name}"

print("Play Store metadata and asset checks passed.")
