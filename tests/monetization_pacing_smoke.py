#!/usr/bin/env python3
"""Keep paid offers optional, contextual and out of the first-session loop."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
billing = (ROOT / "scripts" / "billing.gd").read_text(encoding="utf-8")

required = (
    "func _shop_catalog_stage() -> int:",
    "if GameState.current_country < 1 and Prestige.count <= 0:",
    '"starter": return catalog_stage >= 1',
    '"vip", "perm_x2": return catalog_stage >= 2',
    '"gems_xs", "gems_s", "gems_m": return catalog_stage >= 3',
    '"gems_l", "gems_xl": return catalog_stage >= 4',
    "Todas as rotas e reinos podem ser conquistados gratuitamente.",
    "_refresh_shop_catalog()",
)
missing = [token for token in required if token not in main]
if missing:
    raise SystemExit("MONETIZATION_PACING: FAIL: missing gates: " + ", ".join(missing))

# Paid purchase calls belong exclusively to deliberate button handlers. They
# must never be triggered by boot, progression, rewards or modal presentation.
buy_calls = [line.strip() for line in main.splitlines() if "Billing.buy(" in line]
if buy_calls != ["Fx.press(btn); Billing.buy(product_id)"]:
    raise SystemExit(
        "MONETIZATION_PACING: FAIL: purchase can start outside its explicit button: "
        + repr(buy_calls)
    )

if "_show_iap" in main or "offer_countdown" in main:
    raise SystemExit("MONETIZATION_PACING: FAIL: coercive paid-offer popup/timer detected")

store_price_guards = (
    "signal catalog_updated",
    'detail.get("one_time_purchase_offer_details",',
    'offer_dict.get("formatted_price",',
    "func display_price(product_id: String) -> String:",
    "func can_purchase_product(product_id: String) -> bool:",
)
missing_price_guards = [token for token in store_price_guards if token not in billing]
if missing_price_guards:
    raise SystemExit(
        "MONETIZATION_PACING: FAIL: localized storefront price handling missing: "
        + ", ".join(missing_price_guards)
    )
if 'btn.text = str(product["price"])' in main or '"price": str(product["price"])' in main:
    raise SystemExit("MONETIZATION_PACING: FAIL: shop still renders configured preview prices")
if "btn.disabled = owned or not Billing.can_purchase_product(product_id)" not in main:
    raise SystemExit("MONETIZATION_PACING: FAIL: purchase buttons are active before store readiness")

print("MONETIZATION_PACING: PASS (optional staged catalogue, localized store prices, readiness gate)")
