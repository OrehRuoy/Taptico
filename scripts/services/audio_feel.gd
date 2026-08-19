extends Node
## Dynamic audio modulation for tactile feedback.

const AMBIENT_BUS := "Ambient"

var _pitch_effect: AudioEffectPitchShift
var _lowpass_effect: AudioEffectLowPassFilter
var _pitch_index: int = -1
var _lowpass_index: int = -1


func _ready() -> void:
	_setup_ambient_bus()


func _setup_ambient_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(AMBIENT_BUS)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, AMBIENT_BUS)

	_pitch_effect = AudioEffectPitchShift.new()
	_pitch_effect.pitch_scale = 1.0
	_pitch_index = AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, _pitch_effect, _pitch_index)

	_lowpass_effect = AudioEffectLowPassFilter.new()
	_lowpass_effect.cutoff_hz = 8000.0
	_lowpass_index = AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, _lowpass_effect, _lowpass_index)


func set_pitch_from_velocity(velocity: float, max_velocity: float = 1200.0) -> void:
	if _pitch_effect == null:
		return
	var t := clampf(velocity / max_velocity, 0.0, 1.0)
	_pitch_effect.pitch_scale = lerpf(0.85, 1.35, t)


func set_lowpass_from_position(normalized_y: float) -> void:
	if _lowpass_effect == null:
		return
	normalized_y = clampf(normalized_y, 0.0, 1.0)
	_lowpass_effect.cutoff_hz = lerpf(400.0, 12000.0, 1.0 - normalized_y)


func set_lowpass_cutoff(hz: float) -> void:
	if _lowpass_effect:
		_lowpass_effect.cutoff_hz = clampf(hz, 200.0, 16000.0)


func reset_modulation() -> void:
	if _pitch_effect:
		_pitch_effect.pitch_scale = 1.0
	if _lowpass_effect:
		_lowpass_effect.cutoff_hz = 8000.0


func play_tick(pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = AMBIENT_BUS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.05
	player.stream = gen
	add_child(player)
	player.play()
	if _pitch_effect:
		_pitch_effect.pitch_scale = pitch_scale
	await get_tree().create_timer(0.06).timeout
	player.queue_free()
