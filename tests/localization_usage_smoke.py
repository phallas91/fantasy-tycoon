#!/usr/bin/env python3
"""Prevent untranslated user-facing literals from leaking into the UI."""

from __future__ import annotations

import ast
import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UI_CSV = ROOT / "translations" / "ui.csv"
UI_LITERAL = re.compile(
    r'(?:\.text\s*=\s*|_lbl\(\s*|_section\(\s*|_scroll\(\s*)'
    r'("(?:\\.|[^"\\])*")'
)
BRAND_COPY = {
    "ARCANE TRADE ACADEMY",
    "ARCANE TRADE",
    "EMPIRE",
    "FANTASY  ·  IDLE  ·  TYCOON",
    "Arcane Trade Empire · v%s",
}


with UI_CSV.open(encoding="utf-8-sig", newline="") as handle:
    rows = list(csv.reader(handle))
keys = {row[0] for row in rows[1:] if row}

missing: list[str] = []
for script in sorted((ROOT / "scripts").glob("*.gd")):
    source = script.read_text(encoding="utf-8")
    for match in UI_LITERAL.finditer(source):
        value = ast.literal_eval(match.group(1))
        copy_without_formats = re.sub(r"%[-+0-9.]*[a-zA-Z%]", "", value)
        if not re.search(r"[A-Za-zÀ-ÿ]{2,}", copy_without_formats) or value in BRAND_COPY:
            continue
        if value not in keys:
            line = source.count("\n", 0, match.start()) + 1
            missing.append(f"{script.relative_to(ROOT)}:{line}: {value!r}")

# Economy definitions are data rather than direct Label assignments, but their
# upgrade and talent names/descriptions are rendered throughout the dashboard.
# Keep them under the same nine-locale coverage guarantee as scripted UI copy.
economy_source = (ROOT / "scripts" / "economy.gd").read_text(encoding="utf-8")
for block_name, next_block in (("UPGRADES", "UPGRADE_ORDER"), ("TALENTS", "TALENT_ORDER")):
    block = economy_source.split(f"const {block_name} := {{", 1)[1].split(
        f"const {next_block}", 1
    )[0]
    for field, value in re.findall(r'"(name|desc)"\s*:\s*"([^"]+)"', block):
        if value not in keys:
            missing.append(f"scripts/economy.gd: {block_name}.{field}: {value!r}")

if missing:
    raise SystemExit(
        "LOCALIZATION_USAGE: FAIL: user-facing literals lack translation rows:\n"
        + "\n".join(missing)
    )

print(f"LOCALIZATION_USAGE: PASS ({len(keys)} translated UI keys)")
