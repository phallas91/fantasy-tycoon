#!/usr/bin/env python3
"""Reject Android builds where monetization/retention code is present but unwired."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
ADS = (ROOT / "scripts" / "ads.gd").read_text(encoding="utf-8")
BILLING = (ROOT / "scripts" / "billing.gd").read_text(encoding="utf-8")
ADMOB = (ROOT / "addons" / "AdmobPlugin" / "android_export.cfg").read_text(encoding="utf-8")

autoloads = {
    'Billing="*res://scripts/billing.gd"',
    'Ads="*res://scripts/ads.gd"',
    'Notifications="*res://scripts/notifications.gd"',
    'CloudSave="*res://scripts/cloud_save.gd"',
}
for entry in autoloads:
    assert entry in PROJECT, f"Missing Android service autoload: {entry}"

plugins = {
    "res://addons/AdmobPlugin/plugin.cfg",
    "res://addons/GodotGooglePlayBilling/plugin.cfg",
    "res://addons/NotificationSchedulerPlugin/plugin.cfg",
}
for plugin in plugins:
    assert plugin in PROJECT, f"Android export plugin disabled: {plugin}"

release_aars = (
    "addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar",
    "addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar",
    "addons/NotificationSchedulerPlugin/bin/release/NotificationSchedulerPlugin-release.aar",
)
for relative in release_aars:
    path = ROOT / relative
    assert path.is_file() and path.stat().st_size > 10_000, f"Missing/empty release AAR: {relative}"

app_id = "ca-app-pub-6257070310596477~3020396061"
rewarded_id = "ca-app-pub-6257070310596477/2848051384"
assert app_id in ADMOB, "Production AdMob App ID missing"
assert '_admob.is_real = true' in ADS, "AdMob runtime is not in real mode"
assert rewarded_id in ADS, "Production rewarded unit ID missing"
assert "update_consent_info()" in ADS and "show_privacy_options()" in ADS, "UMP flow incomplete"

assert "query_product_details(PackedStringArray(PRODUCT_ORDER)" in BILLING, \
    "Products must be queried before purchase"
assert "_products_ready" in BILLING, "Purchases are not gated on product readiness"
for key in ("response_code", "purchase_state", "purchase_token", "product_ids", "is_acknowledged"):
    assert key in BILLING, f"Billing v3 response field unsupported: {key}"

assert "res://addons/GodotPlayGameServices/plugin.cfg" not in PROJECT, \
    "Play Games plugin must stay disabled until a real game ID is configured"

print("ANDROID_WIRING_SMOKE: PASS (native services wired; account/device verification remains)")
