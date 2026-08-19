extends Node
## Haptics facade — wraps native iOS plugin with desktop/editor stubs.

var _plugin: Object = null
var _initialized: bool = false


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
	_initialized = true


func _call_native(method: String, args: Array = []) -> Variant:
	if _plugin == null:
		return null
	return _plugin.callv(method, args)


func light() -> void:
	if _plugin:
		_call_native("light")
	elif OS.is_debug_build():
		pass


func medium() -> void:
	if _plugin:
		_call_native("medium")


func heavy() -> void:
	if _plugin:
		_call_native("heavy")


func soft() -> void:
	if _plugin:
		_call_native("soft")


func rigid() -> void:
	if _plugin:
		_call_native("rigid")


func selection() -> void:
	if _plugin:
		_call_native("selection")


func impact(intensity: float) -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	if _plugin:
		_call_native("impact", [intensity])


func double_pulse() -> void:
	if _plugin:
		_call_native("double_pulse")


func is_supported() -> bool:
	if _plugin:
		return bool(_call_native("is_supported"))
	return false


func is_charging() -> bool:
	if _plugin:
		return bool(_call_native("is_charging"))
	return false
