extends Node
## In-app purchases (autoload: Billing). Real Google Play Billing on Android
## when the GodotGooglePlayBilling native singleton is present; falls back to
## instant local grants in the editor and on desktop so purchase flows stay
## testable without a device or a live Play Console listing. Products are
## designed to be genuinely valuable (see docs/ADMOB_INTEGRATION).

signal purchased(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var ads_removed := false
var perm_mult := 1.0
var vip := false               # VIP pass: 2x always + 24h offline + bonus
var starter_owned := false     # hides the "Founder offer" card once bought

const PRODUCTS := {
	"starter":  {"name": "Pacote Inicial", "price": "€2,99", "type": "nonconsumable", "desc": "+300 Gemas, +5 drones e Lucros x2 por 1h. Arranque rápido!"},
	"vip":      {"name": "Passe VIP", "price": "€9,99", "type": "nonconsumable", "desc": "Lucros x2 SEMPRE ativos, offline até 24h, +500 Gemas."},
	"perm_x2":  {"name": "Lucros x2 (para sempre)", "price": "€6,99", "type": "nonconsumable", "desc": "Duplica todos os lucros, para sempre."},
	"gems_xs":  {"name": "Bolso de Gemas", "price": "€0,99", "type": "consumable", "gems": 50, "desc": "+50 Gemas"},
	"gems_s":   {"name": "Punhado de Gemas", "price": "€1,99", "type": "consumable", "gems": 120, "desc": "+120 Gemas"},
	"gems_m":   {"name": "Saco de Gemas", "price": "€7,99", "type": "consumable", "gems": 650, "desc": "+650 Gemas (bónus +30%)"},
	"gems_l":   {"name": "Cofre de Gemas", "price": "€19,99", "type": "consumable", "gems": 1900, "desc": "+1900 Gemas (óptimo valor)"},
	"gems_xl":  {"name": "Tesouro de Gemas", "price": "€34,99", "type": "consumable", "gems": 3800, "desc": "+3800 Gemas (melhor valor)"},
}
const PRODUCT_ORDER := ["starter", "vip", "perm_x2", "gems_xs", "gems_s", "gems_m", "gems_l", "gems_xl"]

# --- real Play Billing path ---
var _client: BillingClient = null
var _connected := false
var _products_ready := false
# Purchase tokens already granted — guards against double-granting a
# non-consumable (starter/vip/perm_x2) when Play re-lists it on every
# query_purchases() restore/relaunch. Persisted; bounded to the most recent
# 200 tokens since consumables get a fresh token per purchase and would
# otherwise grow this list forever.
var _processed_tokens: Array = []

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("GodotGooglePlayBilling"):
		return   # editor / desktop / plugin not baked into this build: fake path only
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_query_product_details_response)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.query_purchases_response.connect(_on_query_purchases_response)
	_client.start_connection()

func _on_connected() -> void:
	_connected = true
	_products_ready = false
	_client.query_product_details(PackedStringArray(PRODUCT_ORDER), BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)   # restore already-owned non-consumables

func _on_disconnected() -> void:
	_connected = false
	_products_ready = false

func _on_connect_error(_code: int, _message: String) -> void:
	_connected = false
	_products_ready = false

func _on_query_product_details_response(response: Dictionary) -> void:
	var details: Array = response.get("product_details", response.get("productDetails", []))
	_products_ready = _response_code(response) == BillingClient.BillingResponseCode.OK and not details.is_empty()

func buy(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		purchase_failed.emit(product_id, "produto desconhecido"); return
	if _client == null or not _connected or not _products_ready:
		if _purchase_simulator_allowed():
			_grant(product_id)   # editor/desktop purchase-flow simulator
		else:
			purchase_failed.emit(product_id, "billing_unavailable")
		return
	var res: Dictionary = _client.purchase(product_id)
	var code := _response_code(res)
	if code != BillingClient.BillingResponseCode.OK and code != -1:
		purchase_failed.emit(product_id, _debug_message(res, "erro desconhecido"))
	# On success the actual grant happens asynchronously via on_purchase_updated.

func _on_purchase_updated(response: Dictionary) -> void:
	var code := _response_code(response)
	if code != BillingClient.BillingResponseCode.OK:
		if code != BillingClient.BillingResponseCode.USER_CANCELED:
			purchase_failed.emit("", _debug_message(response, "erro de compra"))
		return
	for p: Dictionary in response.get("purchases", []):
		_process_purchase(p)

func _on_query_purchases_response(response: Dictionary) -> void:
	if _response_code(response) != BillingClient.BillingResponseCode.OK:
		return
	for p: Dictionary in response.get("purchases", []):
		_process_purchase(p)

func _process_purchase(p: Dictionary) -> void:
	if int(p.get("purchase_state", p.get("purchaseState", 0))) != BillingClient.PurchaseState.PURCHASED:
		return   # PENDING purchases resolve later via another on_purchase_updated
	var token: String = str(p.get("purchase_token", p.get("purchaseToken", "")))
	if token.is_empty():
		purchase_failed.emit("", "missing_purchase_token")
		return
	var already_granted: bool = token in _processed_tokens
	var valid_products: Array[String] = []
	var purchased_ids: Array = Array(p.get("product_ids", p.get("products", [])))
	for product_id: String in purchased_ids:
		if PRODUCTS.has(product_id):
			valid_products.append(product_id)
	if valid_products.is_empty():
		return

	# Persist the granted inventory and its idempotency token in ONE envelope.
	# Granting first only mutates memory; if the app dies before save, Play lists
	# the purchase again and it is safely retried. Once save succeeds, both the
	# reward and token exist together, so a relaunch cannot double-grant it.
	if not already_granted:
		for product_id: String in valid_products:
			_grant(product_id, false)
		_processed_tokens.append(token)
		if _processed_tokens.size() > 200:
			_processed_tokens = _processed_tokens.slice(_processed_tokens.size() - 200)
		if has_node("/root/SaveSystem"):
			SaveSystem.save_game()

	for product_id: String in valid_products:
		var ptype: String = str(PRODUCTS[product_id].get("type", "consumable"))
		if ptype == "consumable":
			_client.consume_purchase(token)
		elif not bool(p.get("is_acknowledged", p.get("isAcknowledged", false))):
			_client.acknowledge_purchase(token)

func _response_code(response: Dictionary) -> int:
	return int(response.get("response_code", response.get("responseCode", -1)))

func _debug_message(response: Dictionary, fallback: String) -> String:
	return str(response.get("debug_message", response.get("debugMessage", fallback)))

func _grant(product_id: String, persist := true) -> void:
	var p: Dictionary = PRODUCTS[product_id]
	match product_id:
		"gems_xs", "gems_s", "gems_m", "gems_l", "gems_xl":
			GameState.gems += int(p["gems"])
		"perm_x2":
			perm_mult = max(perm_mult, 2.0)
		"vip":
			vip = true; ads_removed = true; GameState.gems += 500
		"starter":
			starter_owned = true
			GameState.gems += 300; GameState.drones += 5; GameState._rebuild_drones()
			GameState.boost_earn_2x()
	purchased.emit(product_id)
	if persist and has_node("/root/SaveSystem"):
		SaveSystem.save_game()

## Re-query Google Play for owned purchases ("Restaurar compras" in settings).
## Returns false when the real billing client isn't available (editor/desktop).
func restore() -> bool:
	if _client == null or not _connected:
		return false
	_client.query_purchases(BillingClient.ProductType.INAPP)
	return true

## Never simulate purchases on an exported mobile build. Until StoreKit is
## integrated, iOS fails closed instead of granting paid products for free.
func _purchase_simulator_allowed() -> bool:
	return OS.has_feature("editor") or OS.get_name() in ["Windows", "macOS", "Linux"]

func to_dict() -> Dictionary:
	return {"ads_removed": ads_removed, "perm_mult": perm_mult, "vip": vip,
		"starter_owned": starter_owned, "processed_tokens": _processed_tokens.duplicate()}

func from_dict(d: Dictionary) -> void:
	ads_removed = bool(d.get("ads_removed", false))
	perm_mult = float(d.get("perm_mult", 1.0))
	vip = bool(d.get("vip", false))
	starter_owned = bool(d.get("starter_owned", false))
	_processed_tokens = Array(d.get("processed_tokens", []))
