extends Node

## Firebase / Google Analytics bridge (iOS via GodotFirebaseiOS → GA4).
## Delayed bind on iOS — cold-start races crashed TestFlight on StimPad / Circuit Sort.

var _initialized: bool = false
var _native = null


func _ready() -> void:
	if OS.has_feature("mobile") and OS.get_name() == "iOS":
		get_tree().create_timer(10.0).timeout.connect(_initialize_analytics, CONNECT_ONE_SHOT)
	else:
		call_deferred("_initialize_analytics")


func log_event(event_name: String, params: Dictionary = {}) -> void:
	var clean := _stringify_params(params)
	if OS.has_feature("editor") or not OS.has_feature("mobile"):
		print("[Analytics] %s %s" % [event_name, clean])
	if not _initialized:
		return
	_log_event_native(event_name, clean)


func log_screen(screen_name: String) -> void:
	log_event("screen_view", {"screen_name": screen_name, "firebase_screen": screen_name})


func _initialize_analytics() -> void:
	_native = _resolve_native()
	if _native == null and OS.has_feature("mobile"):
		push_warning("AnalyticsService: Firebase Analytics not found — events stay local/print only.")
		_initialized = true
		return
	if OS.has_feature("ios") and has_node("/root/FirebaseIOS"):
		var ios: Node = get_node("/root/FirebaseIOS")
		if ios.has_signal("firebase_initialized") and not ios.is_connected("firebase_initialized", _on_firebase_ready):
			ios.firebase_initialized.connect(_on_firebase_ready, CONNECT_ONE_SHOT)
			get_tree().create_timer(8.0).timeout.connect(func() -> void:
				if not _initialized:
					_initialized = true
			, CONNECT_ONE_SHOT)
			return
	_initialized = true


func _on_firebase_ready() -> void:
	_native = _resolve_native()
	_initialized = true
	print("AnalyticsService: Firebase initialized")


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


func _log_event_native(event_name: String, params: Dictionary) -> void:
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


func _stringify_params(params: Dictionary) -> Dictionary:
	var out := {}
	for k in params.keys():
		out[str(k)] = params[k]
	return out
