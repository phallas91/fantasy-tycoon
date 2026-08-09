#!/usr/bin/env python3
"""Guard the canonical root Godot project against local cache/backup leakage."""

from __future__ import annotations

from pathlib import Path, PurePosixPath
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
LEGACY_DIR = "arcane-trade-empire-v0.6-premium-clean"


def fail(message: str) -> None:
    raise SystemExit(f"REPOSITORY_HYGIENE_SMOKE: FAIL: {message}")


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    )
    return [entry for entry in result.stdout.decode("utf-8").split("\0") if entry]


project = ROOT / "project.godot"
if not project.is_file():
    fail("canonical project.godot is missing from repository root")

ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
for required in (".godot/", "*.import", "*.uid", f"{LEGACY_DIR}/"):
    if required not in ignore:
        fail(f"missing ignore rule: {required}")

tracked = tracked_files()
for name in tracked:
    path = PurePosixPath(name)
    if path.parts and path.parts[0] == LEGACY_DIR:
        fail(f"legacy nested project is tracked: {name}")
    if ".godot" in path.parts:
        fail(f"Godot cache is tracked: {name}")
    if name.endswith(".import"):
        fail(f"generated .import sidecar is tracked: {name}")

nested_projects = [
    name for name in tracked
    if name != "project.godot" and PurePosixPath(name).name == "project.godot"
]
if nested_projects:
    fail(f"nested Godot project detected: {nested_projects[:3]}")

print(
    "REPOSITORY_HYGIENE_SMOKE: PASS "
    f"({len(tracked)} tracked files, root project canonical, cache/legacy project excluded)"
)
