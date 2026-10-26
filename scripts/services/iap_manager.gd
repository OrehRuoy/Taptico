extends Node
## StoreKit IAP manager for lifetime unlock.
## Never hardcodes a currency string — display price comes from SKProduct / StoreKit 2.

const PRODUCT_LIFETIME := "com.orehruoy.taptico.lifetime"
const STORE_TIMEOUT_SEC := 45.0
const FALLBACK_PRICE := "$4.99"

signal purchase_started
signal purchase_succeeded
signal purchase_failed(message: String)
signal restore_finished(success: bool)
signal products_loaded
signal products_failed(message: String)
signal busy_changed(is_busy: bool)

var _plugin: Object = null
var _price_display: String = ""
var _price_ready: bool = false
var _busy: bool = false
var _op_id: int = 0
var _billing: BillingClient = null
var _billing_ready: bool = false
var _billing_setup_running: bool = false
var _android_restore_after_setup: bool = false
var _pending_android_purchase: bool = false
var _android_purchase_pending: bool = false
var _android_purchase_timed_out: bool = false
var _purchase_query_lock: bool = false
var _ack_lock: bool = false
var _inapp_review: InappReview = null
var _android_review_active: bool = false


func _ready() -> void:
	if OS.get_name() == "iOS" and Engine.has_singleton("StoreKit"):
		_plugin = Engine.get_singleton("StoreKit")
		_connect_plugin_signals()
		_init_store()
	elif Platform.is_android():
		_init_android_billing()
	else:
		# Editor / desktop has no StoreKit. Show the US list price until a device
		# build can replace it with the localized SKProduct string.
		_price_display = FALLBACK_PRICE
		_price_ready = true
		products_loaded.emit()


func _connect_plugin_signals() -> void:
	if _plugin == null:
		return
	_connect_if_present("purchase_updated", _on_native_purchase_updated)
	_connect_if_present("purchase_failed", _on_native_purchase_failed)
	_connect_if_present("entitlements_updated", _on_native_entitlements_updated)
	_connect_if_present("products_loaded", _on_native_products_loaded)
	_connect_if_present("products_failed", _on_native_products_failed)


func _connect_if_present(signal_name: String, callable: Callable) -> void:
	if _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable):
		_plugin.connect(signal_name, callable)


func _init_store() -> void:
	if _plugin == null:
		return
	# Silent entitlement sync only — do not call restoreCompletedTransactions on launch
	# (that can prompt Apple ID and fails Guideline 3.1.1 / review).
	_plugin.call("initialize", PRODUCT_LIFETIME)
	_sync_entitlements()
	_refresh_price_from_plugin()


func is_busy() -> bool:
	return _busy


func is_price_ready() -> bool:
	if not _price_display.is_empty():
		return true
	return _price_ready


func get_price_display() -> String:
	if not _price_display.is_empty():
		return _price_display
	# Android waits for Google Play's formatted price. Never show the hardcoded fallback there.
	if Platform.is_android():
		return ""
	# Editor and desktop have no StoreKit. A device build waits for the localized price.
	if OS.get_name() != "iOS":
		return FALLBACK_PRICE
	return ""


func can_purchase() -> bool:
	if _busy:
		return false
	if Platform.is_android():
		return _billing_ready and is_price_ready()
	if _plugin == null:
		return OS.has_feature("editor")
	return is_price_ready()


func purchase_lifetime() -> void:
	if _busy:
		return
	if Platform.is_android():
		_purchase_android()
		return
	if _plugin == null:
		if OS.has_feature("editor"):
			_begin_op()
			EntitlementStore.set_lifetime_unlocked(true)
			_finish_op()
			purchase_succeeded.emit()
		else:
			purchase_failed.emit("Purchases are not available on this device.")
		return
	if not is_price_ready():
		purchase_failed.emit("The App Store price has not loaded yet. Check your connection and try again.")
		return
	_begin_op()
	purchase_started.emit()
	_plugin.call("purchase", PRODUCT_LIFETIME)
	_await_timeout("The App Store did not respond. Check your connection and try again.")


func restore_purchases() -> void:
	if _busy:
		return
	if Platform.is_android():
		_restore_android()
		return
	if _plugin == null:
		if OS.has_feature("editor"):
			restore_finished.emit(EntitlementStore.lifetime_unlocked)
		else:
			restore_finished.emit(false)
		return
	_begin_op()
	purchase_started.emit()
	_plugin.call("restore")
	_await_timeout("Restore timed out. Check your connection and try again.")


func request_review() -> void:
	if Platform.is_android():
		_start_android_review()
		return
	if _plugin != null and _plugin.has_method("request_review"):
		_plugin.call("request_review")
		return
	if OS.has_feature("editor"):
		print("[IAP] Apple’s in-app review sheet would open on iPhone.")
		return
	push_warning("StoreKit request_review is not in this build. Export a new iOS build after the plugin rebuilds.")


func _begin_op() -> void:
	_op_id += 1
	_busy = true
	busy_changed.emit(true)


func _finish_op() -> void:
	_op_id += 1
	_busy = false
	busy_changed.emit(false)


func _await_timeout(message: String) -> void:
	var op := _op_id
	await get_tree().create_timer(STORE_TIMEOUT_SEC).timeout
	if op != _op_id:
		return
	_finish_op()
	purchase_failed.emit(message)


func _refresh_price_from_plugin() -> void:
	if _plugin == null or not _plugin.has_method("get_price"):
		return
	if _plugin.has_method("is_price_ready") and not bool(_plugin.call("is_price_ready")):
		return
	var price: String = str(_plugin.call("get_price")).strip_edges()
	if price.is_empty() or price == "null":
		return
	_price_display = price
	_price_ready = true
	products_loaded.emit()


func _sync_entitlements() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("has_lifetime"):
		var unlocked: bool = bool(_plugin.call("has_lifetime"))
		EntitlementStore.set_lifetime_unlocked(unlocked)
	_refresh_price_from_plugin()


func _on_native_purchase_updated(_product_id: String = "") -> void:
	EntitlementStore.set_lifetime_unlocked(true)
	_finish_op()
	purchase_succeeded.emit()


func _on_native_purchase_failed(message: String = "") -> void:
	_finish_op()
	if message.is_empty():
		message = "Purchase could not be completed."
	purchase_failed.emit(message)


func _on_native_entitlements_updated(unlocked: bool = false) -> void:
	EntitlementStore.set_lifetime_unlocked(unlocked)
	_finish_op()
	restore_finished.emit(unlocked)


func _on_native_products_loaded(price: String = "") -> void:
	var localized := price.strip_edges()
	if localized.is_empty():
		_refresh_price_from_plugin()
		return
	_price_display = localized
	_price_ready = true
	products_loaded.emit()


func _on_native_products_failed(message: String = "") -> void:
	_price_ready = false
	_price_display = ""
	if message.is_empty():
		message = "Could not load App Store products. Check your connection."
	products_failed.emit(message)


func _init_android_billing() -> void:
	_price_display = ""
	_price_ready = false
	_billing = BillingClient.new()
	_billing.name = "BillingClient"
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.connect_error.connect(_on_billing_connect_error)
	_billing.on_purchase_updated.connect(_on_android_purchase_updated)
	_billing.start_connection()


func _on_billing_connect_error(_response_code: int, debug_message: String) -> void:
	_billing_ready = false
	push_warning("IAPManager billing connect error: %s" % debug_message)
	products_failed.emit("Could not load Google Play products. Check your connection.")


func _on_billing_connected() -> void:
	if _billing_setup_running:
		return
	_billing_setup_running = true
	_run_billing_setup()


func _run_billing_setup() -> void:
	if _billing == null:
		_billing_setup_running = false
		return
	_billing.query_product_details(PackedStringArray([PRODUCT_LIFETIME]), BillingClient.ProductType.INAPP)
	var details_result: Dictionary = await _billing.query_product_details_response
	if _billing == null:
		_billing_setup_running = false
		return
	if int(details_result.get("response_code", BillingClient.BillingResponseCode.ERROR)) == BillingClient.BillingResponseCode.OK:
		_cache_android_price(details_result.get("product_details", []))
		if _price_ready:
			_billing_ready = true
		else:
			products_failed.emit("Could not load Google Play products. Check your connection.")
	else:
		push_warning(
			"IAPManager: product details query failed: %s"
			% str(details_result.get("debug_message", "unknown error"))
		)
		products_failed.emit("Could not load Google Play products. Check your connection.")
	var owned := await _query_owned_purchases(false)
	_billing_setup_running = false
	if _android_restore_after_setup:
		_android_restore_after_setup = false
		if owned:
			_finish_op()
			restore_finished.emit(true)
		else:
			await _query_owned_purchases(true)


func _purchase_android() -> void:
	if _billing == null or not _billing_ready:
		purchase_failed.emit("Google Play isn't ready yet. Check your connection and try again.")
		return
	_begin_op()
	purchase_started.emit()
	_pending_android_purchase = true
	_android_purchase_pending = false
	_android_purchase_timed_out = false
	var result: Dictionary = _billing.purchase(PRODUCT_LIFETIME)
	var code := int(result.get("response_code", BillingClient.BillingResponseCode.ERROR))
	if code != BillingClient.BillingResponseCode.OK:
		_pending_android_purchase = false
		_finish_op()
		var message := str(result.get("debug_message", "")).strip_edges()
		if message.is_empty():
			message = "Purchase could not be completed."
		purchase_failed.emit(message)
		return
	_monitor_android_purchase_timeout()


func _monitor_android_purchase_timeout() -> void:
	var op := _op_id
	await get_tree().create_timer(STORE_TIMEOUT_SEC).timeout
	if op != _op_id or not _pending_android_purchase or _android_purchase_pending:
		return
	_pending_android_purchase = false
	_android_purchase_timed_out = true
	_finish_op()
	purchase_failed.emit("The store did not respond. Check your connection and try again.")


func _restore_android() -> void:
	if _billing == null or not _billing_ready:
		if _billing_setup_running:
			_android_restore_after_setup = true
			_begin_op()
			purchase_started.emit()
			return
		purchase_failed.emit("Google Play isn't ready yet. Check your connection and try again.")
		return
	_begin_op()
	purchase_started.emit()
	await _query_owned_purchases(true)


func _query_owned_purchases(report_empty: bool) -> bool:
	while _purchase_query_lock:
		await get_tree().process_frame
	_purchase_query_lock = true
	var owned := false
	if _billing == null:
		if report_empty:
			_finish_op()
			restore_finished.emit(false)
		_purchase_query_lock = false
		return false
	_billing.query_purchases(BillingClient.ProductType.INAPP)
	var result: Dictionary = await _billing.query_purchases_response
	if int(result.get("response_code", BillingClient.BillingResponseCode.ERROR)) == BillingClient.BillingResponseCode.OK:
		for purchase in result.get("purchases", []):
			if typeof(purchase) != TYPE_DICTIONARY:
				continue
			if _purchase_was_revoked(purchase):
				print("[IAPManager] Play reports Lifetime refunded or revoked — clearing unlock")
				EntitlementStore.set_lifetime_unlocked(false)
				continue
			if await _apply_owned_purchase(purchase):
				owned = true
		# An empty list is not a refund. Only a purchase record that says so clears the unlock.
	if report_empty:
		_finish_op()
		restore_finished.emit(owned)
	_purchase_query_lock = false
	return owned


func _purchase_was_revoked(purchase: Dictionary) -> bool:
	if not _purchase_contains_lifetime(purchase):
		return false
	var state_name := str(purchase.get("purchase_state_name", "")).strip_edges().to_upper()
	return state_name == "REFUNDED" or state_name == "REVOKED" or state_name == "CANCELED"


func _apply_owned_purchase(purchase: Dictionary) -> bool:
	if not _purchase_contains_lifetime(purchase):
		return false
	var state := int(purchase.get("purchase_state", BillingClient.PurchaseState.UNSPECIFIED_STATE))
	if state != BillingClient.PurchaseState.PURCHASED:
		return false
	if not bool(purchase.get("is_acknowledged", false)):
		if not await _acknowledge_purchase(purchase):
			return false
	EntitlementStore.set_lifetime_unlocked(true)
	return true


func _on_android_purchase_updated(result: Dictionary) -> void:
	var code := int(result.get("response_code", BillingClient.BillingResponseCode.ERROR))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		_pending_android_purchase = false
		_android_purchase_pending = false
		if _busy:
			_finish_op()
		purchase_failed.emit("Purchase cancelled.")
		return
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		_pending_android_purchase = false
		_android_purchase_pending = false
		var owned := await _query_owned_purchases(false)
		if _busy:
			_finish_op()
		restore_finished.emit(owned)
		return
	if code != BillingClient.BillingResponseCode.OK:
		if _purchase_list_has_pending(result.get("purchases", [])):
			_android_purchase_pending = true
			if _busy:
				_finish_op()
			purchase_failed.emit("Payment pending. Taptico unlocks when Google Play confirms it.")
			return
		if _pending_android_purchase:
			_pending_android_purchase = false
			if _busy:
				_finish_op()
			var message := str(result.get("debug_message", "")).strip_edges()
			if message.is_empty():
				message = "Purchase could not be completed."
			purchase_failed.emit(message)
		return
	for purchase in result.get("purchases", []):
		if typeof(purchase) != TYPE_DICTIONARY:
			continue
		if not _purchase_contains_lifetime(purchase):
			continue
		var state := int(purchase.get("purchase_state", BillingClient.PurchaseState.UNSPECIFIED_STATE))
		if state == BillingClient.PurchaseState.PENDING:
			_android_purchase_pending = true
			if _busy:
				_finish_op()
			purchase_failed.emit("Payment pending. Taptico unlocks when Google Play confirms it.")
			continue
		if state != BillingClient.PurchaseState.PURCHASED:
			continue
		await _finish_android_purchase(purchase)


func _finish_android_purchase(purchase: Dictionary) -> void:
	if not bool(purchase.get("is_acknowledged", false)):
		if not await _acknowledge_purchase(purchase):
			if _pending_android_purchase and not _android_purchase_timed_out:
				_pending_android_purchase = false
				if _busy:
					_finish_op()
				purchase_failed.emit("Purchase could not be completed.")
			return
	EntitlementStore.set_lifetime_unlocked(true)
	if _android_purchase_timed_out:
		return
	_pending_android_purchase = false
	_android_purchase_pending = false
	if _busy:
		_finish_op()
	purchase_succeeded.emit()


func _acknowledge_purchase(purchase: Dictionary) -> bool:
	var token := str(purchase.get("purchase_token", ""))
	if token.is_empty() or _billing == null:
		return false
	while _ack_lock:
		await get_tree().process_frame
	_ack_lock = true
	_billing.acknowledge_purchase(token)
	var result: Dictionary = await _billing.acknowledge_purchase_response
	var ok := int(result.get("response_code", BillingClient.BillingResponseCode.ERROR)) == BillingClient.BillingResponseCode.OK
	_ack_lock = false
	return ok


func _purchase_contains_lifetime(purchase: Dictionary) -> bool:
	var ids: Variant = purchase.get("product_ids", [])
	if ids is Array or ids is PackedStringArray:
		for product_id in ids:
			if str(product_id) == PRODUCT_LIFETIME:
				return true
	return str(purchase.get("product_id", "")) == PRODUCT_LIFETIME


func _purchase_list_has_pending(purchases: Variant) -> bool:
	if not (purchases is Array):
		return false
	for purchase in purchases:
		if typeof(purchase) != TYPE_DICTIONARY:
			continue
		if not _purchase_contains_lifetime(purchase):
			continue
		if int(purchase.get("purchase_state", -1)) == BillingClient.PurchaseState.PENDING:
			return true
	return false


func _cache_android_price(product_details: Variant) -> void:
	if not (product_details is Array):
		return
	for entry in product_details:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var detail: Dictionary = entry
		var play_id := str(detail.get("product_id", detail.get("id", "")))
		if not play_id.is_empty() and play_id != PRODUCT_LIFETIME:
			continue
		var price := _extract_formatted_price(detail)
		if price.is_empty():
			continue
		_price_display = price
		_price_ready = true
		products_loaded.emit()
		return


func _extract_formatted_price(detail: Dictionary) -> String:
	var offer: Variant = detail.get("one_time_purchase_offer_details", null)
	if offer is Dictionary:
		var price := str((offer as Dictionary).get("formatted_price", ""))
		if not price.is_empty():
			return price
	var offer_list: Variant = detail.get("one_time_purchase_offer_details_list", null)
	if offer_list is Array:
		for item in offer_list:
			if item is Dictionary:
				var list_price := str((item as Dictionary).get("formatted_price", ""))
				if not list_price.is_empty():
					return list_price
	return str(detail.get("formatted_price", detail.get("price", "")))


func _start_android_review() -> void:
	if _android_review_active:
		return
	if not Engine.has_singleton("InappReviewPlugin"):
		_request_review_bridge()
		return
	var node := _ensure_android_review()
	if node == null:
		_request_review_bridge()
		return
	_android_review_active = true
	node.generate_review_info()
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		_android_review_active = false
	, CONNECT_ONE_SHOT)


func _ensure_android_review() -> InappReview:
	if _inapp_review != null and is_instance_valid(_inapp_review):
		return _inapp_review
	var node := InappReview.new()
	node.name = "InappReview"
	add_child(node)
	_inapp_review = node
	node.review_info_generated.connect(_on_android_review_info_generated)
	node.review_info_generation_failed.connect(_on_android_review_failed)
	node.review_flow_launched.connect(_on_android_review_launched)
	node.review_flow_launch_failed.connect(_on_android_review_failed)
	return node


func _on_android_review_info_generated() -> void:
	if not _android_review_active or _inapp_review == null:
		return
	_inapp_review.launch_review_flow()


func _on_android_review_launched() -> void:
	_android_review_active = false


func _on_android_review_failed() -> void:
	# A Play quota miss or a failed sheet is quiet. Do not open a browser.
	_android_review_active = false


func _request_review_bridge() -> void:
	var jcw: Object = Engine.get_singleton("JavaClassWrapper")
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if jcw == null or runtime == null:
		return
	var bridge: Variant = jcw.call("wrap", "com.godot.game.InAppReviewBridge")
	if bridge == null:
		return
	var activity: Variant = runtime.call("getActivity")
	if activity == null:
		return
	bridge.call("requestReview", activity)
