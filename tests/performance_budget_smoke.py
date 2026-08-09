#!/usr/bin/env python3
"""Enforce release-size budgets for source assets and Android packages."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUDGET_PATH = ROOT / "tests/performance_budget.json"
ASSET_ROOT = ROOT / "assets"
IGNORED_SUFFIXES = {".import", ".uid"}
BYTES_PER_MB = 1_000_000


def fail(message: str) -> None:
    raise SystemExit(f"PERFORMANCE_BUDGET: FAIL: {message}")


def megabytes(size: int) -> float:
    return size / BYTES_PER_MB


def load_budgets() -> dict[str, float]:
    raw = json.loads(BUDGET_PATH.read_text(encoding="utf-8"))
    required = {
        "source_assets_max_mb",
        "music_assets_max_mb",
        "single_asset_max_mb",
        "apk_max_mb",
        "aab_max_mb",
    }
    if set(raw) != required or any(not isinstance(raw[key], (int, float)) for key in required):
        fail("performance_budget.json has an invalid schema")
    return {key: float(raw[key]) for key in required}


def source_assets() -> list[Path]:
    return sorted(
        path
        for path in ASSET_ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() not in IGNORED_SUFFIXES
    )


def enforce_source_budgets(budgets: dict[str, float]) -> tuple[float, float, Path]:
    assets = source_assets()
    if not assets:
        fail("no source assets found")
    total_bytes = sum(path.stat().st_size for path in assets)
    music_bytes = sum(path.stat().st_size for path in assets if "music" in path.parts)
    largest = max(assets, key=lambda path: path.stat().st_size)
    total_mb = megabytes(total_bytes)
    music_mb = megabytes(music_bytes)
    largest_mb = megabytes(largest.stat().st_size)

    if total_mb > budgets["source_assets_max_mb"]:
        fail(f"source assets are {total_mb:.1f} MB (budget {budgets['source_assets_max_mb']:.1f} MB)")
    if music_mb > budgets["music_assets_max_mb"]:
        fail(f"music assets are {music_mb:.1f} MB (budget {budgets['music_assets_max_mb']:.1f} MB)")
    if largest_mb > budgets["single_asset_max_mb"]:
        fail(
            f"{largest.relative_to(ROOT)} is {largest_mb:.1f} MB "
            f"(single-asset budget {budgets['single_asset_max_mb']:.1f} MB)"
        )
    return total_mb, music_mb, largest


def enforce_package_budget(path: Path, budgets: dict[str, float]) -> str:
    if not path.is_file():
        fail(f"package is missing: {path}")
    suffix = path.suffix.lower()
    budget_key = {".apk": "apk_max_mb", ".aab": "aab_max_mb"}.get(suffix)
    if budget_key is None:
        fail(f"unsupported package type: {path.suffix}")
    size_mb = megabytes(path.stat().st_size)
    limit = budgets[budget_key]
    if size_mb > limit:
        fail(f"{path.name} is {size_mb:.1f} MB (budget {limit:.1f} MB)")
    return f"{path.name} {size_mb:.1f}/{limit:.1f} MB"


def main() -> None:
    budgets = load_budgets()
    total_mb, music_mb, largest = enforce_source_budgets(budgets)
    package_results = [enforce_package_budget(Path(arg), budgets) for arg in sys.argv[1:]]
    largest_mb = megabytes(largest.stat().st_size)
    details = (
        f"assets {total_mb:.1f}/{budgets['source_assets_max_mb']:.1f} MB, "
        f"music {music_mb:.1f}/{budgets['music_assets_max_mb']:.1f} MB, "
        f"largest {largest.relative_to(ROOT)} {largest_mb:.1f}/"
        f"{budgets['single_asset_max_mb']:.1f} MB"
    )
    if package_results:
        details += ", " + ", ".join(package_results)
    print(f"PERFORMANCE_BUDGET: PASS ({details})")


if __name__ == "__main__":
    main()
