#!/usr/bin/env python3
"""Validate and stage the canonical Arcane Trade Empire store icon."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "appicon.png"
OUTPUT = ROOT / "export" / "store" / "app_icon_512.png"


def main() -> None:
    with Image.open(SOURCE) as icon:
        if icon.size != (512, 512):
            raise SystemExit(f"appicon.png must be 512x512, got {icon.size}")
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        icon.convert("RGBA").save(OUTPUT)
    print(f"Store icon staged: {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
