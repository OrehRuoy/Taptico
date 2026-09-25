extends Node
## User preferences: sound, haptics, tilt/shake. Saved on device.

signal changed

const SAVE_PATH := "user://settings.cfg"

enum OutputMode { BOTH, HEADPHONES, HAPTICS }

var sound_on: bool = true
var sound_volume: float = 0.75
var haptic_strength: float = 1.0
var shake_strength: float = 1.0
var output_mode: int = OutputMode.BOTH

var _save_queued: bool = false


func _ready() -> void:
	_load()
	apply_audio()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	sound_on = bool(cfg.get_value("feel", "sound_on", true))
	sound_volume = clampf(float(cfg.get_value("feel", "sound_volume", 0.75)), 0.0, 1.0)
	haptic_strength = clampf(float(cfg.get_value("feel", "haptic_strength", 1.0)), 0.0, 1.0)
	shake_strength = clampf(float(cfg.get_value("feel", "shake_strength", 1.0)), 0.0, 1.0)
	if cfg.has_section_key("feel", "output_mode"):
		output_mode = clampi(int(cfg.get_value("feel", "output_mode", OutputMode.BOTH)), OutputMode.BOTH, OutputMode.HAPTICS)
	elif not sound_on and haptic_strength > 0.04:
		output_mode = OutputMode.HAPTICS
	elif sound_on and haptic_strength <= 0.04:
		output_mode = OutputMode.HEADPHONES
	else:
		output_mode = OutputMode.BOTH


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("feel", "sound_on", sound_on)
	cfg.set_value("feel", "sound_volume", sound_volume)
	cfg.set_value("feel", "haptic_strength", haptic_strength)
	cfg.set_value("feel", "shake_strength", shake_strength)
	cfg.set_value("feel", "output_mode", output_mode)
	cfg.save(SAVE_PATH)
	_save_queued = false


func _save_soon() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(0.25).timeout.connect(save, CONNECT_ONE_SHOT)


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Ambient")
	if bus == -1:
		bus = AudioServer.get_bus_index("Master")
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, not sound_on or output_mode == OutputMode.HAPTICS)
	var vol := clampf(sound_volume, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(vol))


func set_sound_on(value: bool) -> void:
	if sound_on == value:
		return
	sound_on = value
	apply_audio()
	changed.emit()
	save()


func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	changed.emit()
	_save_soon()


func set_haptic_strength(value: float) -> void:
	haptic_strength = clampf(value, 0.0, 1.0)
	changed.emit()
	_save_soon()


func set_output_mode(mode: int) -> void:
	output_mode = clampi(mode, OutputMode.BOTH, OutputMode.HAPTICS)
	sound_on = output_mode != OutputMode.HAPTICS
	apply_audio()
	changed.emit()
	save()


func effective_haptic_strength() -> float:
	if output_mode == OutputMode.HEADPHONES:
		return 0.0
	return haptic_strength


func reduce_motion() -> bool:
	if DisplayServer.has_method("accessibility_should_reduce_animation"):
		return bool(DisplayServer.call("accessibility_should_reduce_animation"))
	return false


func set_shake_strength(value: float) -> void:
	shake_strength = clampf(value, 0.0, 1.0)
	changed.emit()
	_save_soon()


func haptic_label() -> String:
	if haptic_strength <= 0.04:
		return "Off"
	if haptic_strength < 0.34:
		return "Low"
	if haptic_strength < 0.67:
		return "Medium"
	return "High"


func shake_label() -> String:
	if shake_strength <= 0.04:
		return "Off"
	if shake_strength < 0.34:
		return "Low"
	if shake_strength < 0.67:
		return "Medium"
	return "High"
