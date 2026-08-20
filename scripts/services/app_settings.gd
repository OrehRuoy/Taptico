extends Node
## User preferences: sound, haptics, tilt/shake. Saved on device.

signal changed

const SAVE_PATH := "user://settings.cfg"

var sound_on: bool = true
var sound_volume: float = 0.75
var haptic_strength: float = 1.0
var shake_strength: float = 1.0

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


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("feel", "sound_on", sound_on)
	cfg.set_value("feel", "sound_volume", sound_volume)
	cfg.set_value("feel", "haptic_strength", haptic_strength)
	cfg.set_value("feel", "shake_strength", shake_strength)
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
	AudioServer.set_bus_mute(bus, not sound_on)
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
