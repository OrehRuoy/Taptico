extends Node
## Firebase / Google Analytics (iOS via GodotFirebaseiOS → GA4).
##
## Events are queued until Firebase is ready (iOS bind is delayed ~10s).
## View them in Firebase: Analytics → Events → fidget_open.
## Register the custom dimensions listed in docs/ANALYTICS.md or
## item_name / fidget_tier / user_type will not appear as breakdowns.

const QUEUE_CAP := 48

var _initialized: bool = false
var _native = null
var _queue: Array[Dictionary] = []
var _user_type: String = "free"


func _ready() -> void:
	_user_type = "paid" if EntitlementStore.has_lifetime() else "free"
	if not EntitlementStore.entitlements_changed.is_connected(_on_entitlements_changed):
		EntitlementStore.entitlements_changed.connect(_on_entitlements_changed)
	if OS.has_feature("mobile") and OS.get_name() == "iOS":
		get_tree().create_timer(10.0).timeout.connect(_initialize_analytics, CONNECT_ONE_SHOT)
	else:
		call_deferred("_initialize_analytics")


func _on_entitlements_changed() -> void:
	_user_type = "paid" if EntitlementStore.has_lifetime() else "free"
	_apply_user_context()


func log_event(event_name: String, params: Dictionary = {}) -> void:
	var clean := _sanitize(event_name, params)
	if OS.has_feature("editor") or not OS.has_feature("mobile"):
		print("[Analytics] %s %s" % [clean["name"], clean["params"]])
	if not _initialized:
		if _queue.size() >= QUEUE_CAP:
			_queue.pop_front()
		_queue.append(clean)
		return
	_send(clean["name"], clean["params"])


func log_screen(screen_name: String) -> void:
	log_event("screen_view", {"screen_name": screen_name, "firebase_screen": screen_name})


func log_fidget_open(mod: Dictionary) -> void:
	log_event("fidget_open", _fidget_params(mod))


func log_fidget_play(mod: Dictionary, seconds: int) -> void:
	if seconds < 2:
		return
	var params := _fidget_params(mod)
	params["value"] = seconds
	log_event("fidget_play", params)


func log_paywall(module_name: String) -> void:
	log_event("paywall_shown", {
		"item_name": module_name if not module_name.is_empty() else "header",
		"user_type": _user_type,
	})


func log_purchase() -> void:
	_user_type = "paid"
	_apply_user_context()
	log_event("purchase", {
		"item_id": IAPManager.PRODUCT_LIFETIME,
		"item_name": "Lifetime Unlock",
		"value": 4.99,
		"currency": "USD",
		"user_type": "paid",
	})


func _fidget_params(mod: Dictionary) -> Dictionary:
	var premium := bool(mod.get("premium", false))
	return {
		"item_id": str(mod.get("id", "")),
		"item_name": str(mod.get("name", "")),
		"fidget_tier": "premium" if premium else "free",
		"user_type": _user_type,
	}


func _initialize_analytics() -> void:
	_native = _resolve_native()
	if _native == null and OS.has_feature("mobile"):
		push_warning("AnalyticsService: Firebase Analytics not found — events stay local/print only.")
		_initialized = true
		_flush_queue()
		return
	if OS.has_feature("ios") and has_node("/root/FirebaseIOS"):
		var ios: Node = get_node("/root/FirebaseIOS")
		if ios.has_signal("firebase_initialized") and not ios.is_connected("firebase_initialized", _on_firebase_ready):
			ios.firebase_initialized.connect(_on_firebase_ready, CONNECT_ONE_SHOT)
			get_tree().create_timer(8.0).timeout.connect(func() -> void:
				if not _initialized:
					_initialized = true
					_apply_user_context()
					_flush_queue()
			, CONNECT_ONE_SHOT)
			return
	_initialized = true
	_apply_user_context()
	_flush_queue()


func _on_firebase_ready() -> void:
	_native = _resolve_native()
	_initialized = true
	_apply_user_context()
	_flush_queue()
	print("AnalyticsService: Firebase initialized")


func _apply_user_context() -> void:
	if _native == null:
		return
	# GodotFirebaseiOS: set_user_property(value, name)
	if _native.has_method("set_user_property"):
		_native.set_user_property(_user_type, "user_type")
	if _native.has_method("set_default_event_parameters"):
		_native.set_default_event_parameters({"user_type": _user_type})


func _resolve_native():
	if has_node("/root/FirebaseIOS"):
		var ios = get_node("/root/FirebaseIOS")
		if ios != null and ios.get("analytics") != null:
			return ios.analytics
	for n in ["GodotxFirebaseAnalytics", "FirebaseAnalytics", "FirebaseIOS"]:
		if Engine.has_singleton(n):
			return Engine.get_singleton(n)
	if has_node("/root/FirebaseAnalytics"):
		return get_node("/root/FirebaseAnalytics")
	return null


func _flush_queue() -> void:
	for item in _queue:
		_send(str(item["name"]), item["params"])
	_queue.clear()


func _send(event_name: String, params: Dictionary) -> void:
	if _native == null:
		return
	var bridge_params := {}
	for k in params.keys():
		var v = params[k]
		if typeof(v) == TYPE_BOOL:
			bridge_params[str(k)] = 1 if v else 0
		elif typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			bridge_params[str(k)] = v
		else:
			bridge_params[str(k)] = str(v)
	if _native.has_method("log_event"):
		_native.log_event(event_name, bridge_params)
	elif _native.has_method("logEvent"):
		_native.logEvent(event_name, bridge_params)


func _sanitize(event_name: String, params: Dictionary) -> Dictionary:
	var name := event_name.to_lower().replace(" ", "_")
	if name.length() > 40:
		name = name.substr(0, 40)
	var out := {}
	for k in params.keys():
		var key := str(k).to_lower().replace(" ", "_")
		if key.length() > 40:
			key = key.substr(0, 40)
		var v = params[k]
		if typeof(v) == TYPE_STRING:
			var s := str(v)
			if s.length() > 100:
				s = s.substr(0, 100)
			out[key] = s
		else:
			out[key] = v
	out["user_type"] = _user_type
	return {"name": name, "params": out}
