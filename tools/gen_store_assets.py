#!/usr/bin/env python3
"""Validate and stage the canonical Arcane Trade Empire Play Store artwork."""

from pathlib import Path
import shutil
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
IMAGE_DIR = ROOT / "fastlane" / "metadata" / "android" / "en-US" / "images"
OUTPUT = ROOT / "export" / "store"
ASSETS = {
    "featureGraphic.png": (1024, 500),
    "icon.png": (512, 512),
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, expected in ASSETS.items():
        source = IMAGE_DIR / name
        with Image.open(source) as image:
            if image.size != expected:
                raise SystemExit(f"{name} must be {expected}, got {image.size}")
        target = OUTPUT / ("app_icon_512.png" if name == "icon.png" else name)
        shutil.copyfile(source, target)
        print(f"Store asset staged: {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
