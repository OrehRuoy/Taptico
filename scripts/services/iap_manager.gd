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


func _ready() -> void:
	if OS.get_name() == "iOS" and Engine.has_singleton("StoreKit"):
		_plugin = Engine.get_singleton("StoreKit")
		_connect_plugin_signals()
		_init_store()
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
	return FALLBACK_PRICE


func can_purchase() -> bool:
	if _busy:
		return false
	if _plugin == null:
		return OS.has_feature("editor")
	return is_price_ready()


func purchase_lifetime() -> void:
	if _busy:
		return
	if _plugin == null:
		if OS.has_feature("editor"):
			_begin_op()
			EntitlementStore.set_lifetime_unlocked(true)
			_finish_op()
			purchase_succeeded.emit()
		else:
			purchase_failed.emit("Purchases are only available on iOS.")
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
