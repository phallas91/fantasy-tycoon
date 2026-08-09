#!/usr/bin/env python3
"""Keep paid offers optional, contextual and out of the first-session loop."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")

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

print("MONETIZATION_PACING: PASS (optional four-stage catalogue, no automatic purchase prompt)")
