#!/usr/bin/env python3
"""Dependency-free project-wide data, resource and localization integrity test."""

from pathlib import Path
import csv
import json
import math
import re
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise AssertionError(f"PROJECT_INTEGRITY: {message}")


resource_files = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
resource_files += list((ROOT / "scenes").rglob("*.tscn"))
resource_files += list((ROOT / "scenes").rglob("*.tres"))
for source in resource_files:
    text = source.read_text(encoding="utf-8")
    for match in re.findall(r'"res://([^"\n]+)"', text):
        if "%" in match or "…" in match:
            continue
        if not (ROOT / match).exists():
            fail(f"missing resource {match!r} referenced by {source.relative_to(ROOT)}")

world = json.loads((ROOT / "data" / "world.json").read_text(encoding="utf-8"))
countries = world.get("countries")
if not isinstance(countries, list) or len(countries) != 40:
    fail("world must contain exactly 40 realms")
names: set[str] = set()
for index, country in enumerate(countries):
    name = country.get("name")
    if not isinstance(name, str) or not name.strip() or name in names:
        fail(f"invalid/duplicate realm name at index {index}")
    names.add(name)
    cities = country.get("cities")
    outline = country.get("outline")
    if not isinstance(cities, list) or len(cities) < 2:
        fail(f"realm {index} needs a capital and at least one route city")
    if not cities[0].get("capital", False):
        fail(f"realm {index} first city must be the capital")
    if not isinstance(outline, list) or len(outline) < 3:
        fail(f"realm {index} has no usable outline")
    for point in outline:
        if len(point) != 2 or not all(math.isfinite(float(v)) and 0.0 <= float(v) <= 1.0 for v in point):
            fail(f"realm {index} contains an invalid outline point")
    for city in cities:
        if not str(city.get("name", "")).strip():
            fail(f"realm {index} contains an unnamed city")
        for axis in ("x", "y"):
            value = float(city.get(axis, -1.0))
            if not math.isfinite(value) or not 0.0 <= value <= 1.0:
                fail(f"realm {index} city coordinate {axis} is invalid")

with (ROOT / "translations" / "ui.csv").open(encoding="utf-8", newline="") as handle:
    rows = list(csv.reader(handle))
if rows[0] != ["keys", "pt", "en", "es", "fr", "de", "it", "ru", "ja", "zh"]:
    fail("unexpected localization header")
keys: set[str] = set()
for line, row in enumerate(rows[1:], 2):
    if len(row) != 10 or any(not value.strip() for value in row):
        fail(f"incomplete translation row {line}")
    if row[0] in keys:
        fail(f"duplicate translation key at row {line}: {row[0]}")
    keys.add(row[0])

def validate_png(image: Path) -> tuple[int, int]:
    """Validate every PNG chunk, including CRC and the mandatory IEND."""
    data = image.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"invalid PNG signature: {image.relative_to(ROOT)}")
    offset = 8
    dimensions: tuple[int, int] | None = None
    found_iend = False
    while offset < len(data):
        if offset + 12 > len(data):
            fail(f"truncated PNG chunk: {image.relative_to(ROOT)}")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            fail(f"truncated PNG payload: {image.relative_to(ROOT)}")
        payload = data[offset + 8:offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length:chunk_end])[0]
        actual_crc = zlib.crc32(payload, zlib.crc32(chunk_type)) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            fail(f"PNG CRC mismatch: {image.relative_to(ROOT)}")
        if chunk_type == b"IHDR":
            if length != 13:
                fail(f"invalid PNG IHDR: {image.relative_to(ROOT)}")
            dimensions = struct.unpack(">II", payload[:8])
        if chunk_type == b"IEND":
            if length != 0 or chunk_end != len(data):
                fail(f"invalid PNG ending: {image.relative_to(ROOT)}")
            found_iend = True
            break
        offset = chunk_end
    if dimensions is None or not found_iend:
        fail(f"incomplete PNG: {image.relative_to(ROOT)}")
    return dimensions


for image in ROOT.rglob("*.png"):
    if "arcane-trade-empire-v0.6-premium-clean" in image.parts or ".godot" in image.parts:
        continue
    width, height = validate_png(image)
    if width < 1 or height < 1 or width > 8192 or height > 8192:
        fail(f"invalid PNG dimensions: {image.relative_to(ROOT)} = {width}x{height}")

for script in (ROOT / "scripts").rglob("*.gd"):
    previous = ""
    for line_number, raw in enumerate(script.read_text(encoding="utf-8").splitlines(), 1):
        current = raw.strip()
        if current.startswith("var ") and current == previous:
            fail(f"duplicate declaration in {script.relative_to(ROOT)}:{line_number}")
        previous = current

print(f"PROJECT_INTEGRITY: PASS ({len(countries)} realms, {len(keys)} keys, 9 locales)")
