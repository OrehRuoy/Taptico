extends Node
## Haptics facade — wraps native iOS plugin with desktop/editor stubs.
## Android uses TapticoHapticsBridge (primitive / predefined / one-shot). iOS path is unchanged.

var _plugin: Object = null
var _initialized: bool = false
var _android_bridge: Object = null
var _android_tier: int = 0
var _android_bridge_ready: bool = false
var _last_android_ms: int = -100000
var _charging_cached: bool = false
var _charging_checked_ms: int = -100000
var _touch_feedback_off: bool = false


func _ready() -> void:
	init()


func init() -> void:
	if _initialized:
		return
	if OS.get_name() == "iOS":
		if Engine.has_singleton("Haptics"):
			_plugin = Engine.get_singleton("Haptics")
			if _plugin.has_method("configurePlaybackAudioSession"):
				_plugin.call("configurePlaybackAudioSession")
	elif Platform.is_android():
		_init_android()
	_initialized = true


func _init_android() -> void:
	# configurePlaybackAudioSession is iOS-only. Android is a no-op.
	var jcw: Object = Engine.get_singleton("JavaClassWrapper")
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if jcw == null or runtime == null:
		return
	var bridge: Variant = jcw.call("wrap", "com.godot.game.TapticoHapticsBridge")
	if _java_exception(jcw) != null or bridge == null:
		push_warning("TapticoHaptics bridge missing: %s" % str(_java_exception(jcw)))
		return
	var activity: Variant = runtime.call("getActivity")
	if activity == null:
		return
	bridge.call("init", activity)
	if _java_exception(jcw) != null:
		push_warning("TapticoHaptics init failed: %s" % str(_java_exception(jcw)))
		return
	_android_bridge = bridge
	_android_bridge_ready = true
	_android_tier = int(bridge.call("getTier"))
	_touch_feedback_off = not bool(bridge.call("isTouchFeedbackEnabled"))


func _java_exception(jcw: Object) -> Variant:
	if jcw == null or not jcw.has_method("get_exception"):
		return null
	return jcw.call("get_exception")


func _call_native(method: String, args: Array = []) -> Variant:
	if _plugin == null:
		return null
	return _plugin.callv(method, args)


func _haptic_ok() -> bool:
	return AppSettings.effective_haptic_strength() > 0.04


func _scaled(intensity: float) -> float:
	return clampf(intensity * AppSettings.effective_haptic_strength(), 0.0, 1.0)


func _android_gap_ms() -> int:
	if _android_tier >= 3:
		return 18
	return 28


func _android_rate_ok() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_android_ms < _android_gap_ms():
		return false
	_last_android_ms = now
	return true


func _play_android(kind: String, scale: float) -> void:
	if _android_bridge_ready and _android_tier <= 0:
		return
	if not _android_rate_ok():
		return
	if _android_bridge != null:
		_android_bridge.call("play", kind, scale)
		var jcw: Object = Engine.get_singleton("JavaClassWrapper")
		if _java_exception(jcw) != null:
			push_warning("TapticoHaptics play failed: %s" % str(_java_exception(jcw)))
			_fallback_vibrate(kind, scale)
		return
	_fallback_vibrate(kind, scale)


func _fallback_vibrate(kind: String, scale: float) -> void:
	scale = clampf(scale, 0.0, 1.0)
	if kind == "double":
		_vibrate_ms(15, int(round(180.0 * scale)))
		var second := int(round(90.0 * scale))
		get_tree().create_timer(0.05).timeout.connect(func() -> void:
			_vibrate_ms(10, second)
		, CONNECT_ONE_SHOT)
		return
	var ms := 0
	var amp := 1
	match kind:
		"selection":
			ms = 8
			amp = int(round(60.0 * scale))
		"soft":
			ms = 12
			amp = int(round(70.0 * scale))
		"light":
			ms = 12
			amp = int(round(100.0 * scale))
		"medium":
			ms = 18
			amp = int(round(160.0 * scale))
		"rigid":
			ms = 10
			amp = int(round(230.0 * scale))
		"heavy":
			ms = 25
			amp = int(round(255.0 * scale))
		"impact":
			ms = int(round(8.0 + 17.0 * scale))
			amp = int(round(40.0 + 215.0 * scale))
		_:
			return
	_vibrate_ms(ms, amp)


func _vibrate_ms(ms: int, amp: int) -> void:
	Input.vibrate_handheld(maxi(ms, 1), float(clampi(amp, 1, 255)) / 255.0)


func light() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		if AppSettings.effective_haptic_strength() < 0.45:
			_call_native("soft")
		else:
			_call_native("light")
	elif Platform.is_android():
		var kind := "soft" if AppSettings.effective_haptic_strength() < 0.45 else "light"
		_play_android(kind, AppSettings.effective_haptic_strength())
	elif OS.is_debug_build():
		pass


func medium() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		if AppSettings.effective_haptic_strength() < 0.4:
			_call_native("light")
		else:
			_call_native("medium")
	elif Platform.is_android():
		var kind := "light" if AppSettings.effective_haptic_strength() < 0.4 else "medium"
		_play_android(kind, AppSettings.effective_haptic_strength())


func heavy() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		if AppSettings.effective_haptic_strength() < 0.35:
			_call_native("medium")
		else:
			_call_native("heavy")
	elif Platform.is_android():
		var kind := "medium" if AppSettings.effective_haptic_strength() < 0.35 else "heavy"
		_play_android(kind, AppSettings.effective_haptic_strength())


func soft() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		_call_native("soft")
	elif Platform.is_android():
		_play_android("soft", AppSettings.effective_haptic_strength())


func rigid() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		_call_native("rigid")
	elif Platform.is_android():
		_play_android("rigid", AppSettings.effective_haptic_strength())


func selection() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		_call_native("selection")
	elif Platform.is_android():
		_play_android("selection", AppSettings.effective_haptic_strength())


func impact(intensity: float) -> void:
	if not _haptic_ok():
		return
	intensity = _scaled(intensity)
	if _plugin:
		_call_native("impact", [intensity])
	elif Platform.is_android():
		_play_android("impact", intensity)


func double_pulse() -> void:
	if not _haptic_ok():
		return
	if _plugin:
		_call_native("double_pulse")
	elif Platform.is_android():
		_play_android("double", AppSettings.effective_haptic_strength())


func is_supported() -> bool:
	if Platform.is_android():
		return _android_tier > 0
	if _plugin:
		return bool(_call_native("is_supported"))
	return false


func has_vibrator() -> bool:
	if Platform.is_android():
		if not _android_bridge_ready:
			return true
		return _android_tier > 0
	return is_supported()


func android_touch_feedback_off() -> bool:
	if not Platform.is_android() or _android_bridge == null:
		return false
	_touch_feedback_off = not bool(_android_bridge.call("isTouchFeedbackEnabled"))
	return _touch_feedback_off


func is_charging() -> bool:
	if Platform.is_android():
		var now := Time.get_ticks_msec()
		if _android_bridge != null and now - _charging_checked_ms >= 2000:
			_charging_checked_ms = now
			_charging_cached = bool(_android_bridge.call("isCharging"))
		return _charging_cached
	if _plugin:
		return bool(_call_native("is_charging"))
	return false


func has_crash_reports() -> bool:
	if _plugin == null or _plugin == self or not _plugin.has_method("has_crash_reports"):
		return false
	return bool(_plugin.call("has_crash_reports"))


func get_latest_crash_report() -> String:
	if _plugin == null or _plugin == self or not _plugin.has_method("get_latest_crash_report"):
		return ""
	return str(_plugin.call("get_latest_crash_report"))
