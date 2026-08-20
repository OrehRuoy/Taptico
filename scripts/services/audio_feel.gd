extends Node
## Procedural ticks/clicks for fidgets. Respects AppSettings sound on/volume.

const AMBIENT_BUS := "Ambient"
const POOL := 8

var _pitch_effect: AudioEffectPitchShift
var _lowpass_effect: AudioEffectLowPassFilter
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	_setup_ambient_bus()
	_build_streams()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = AMBIENT_BUS
		add_child(p)
		_players.append(p)
	AppSettings.apply_audio()


func _setup_ambient_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(AMBIENT_BUS)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, AMBIENT_BUS)
		AudioServer.set_bus_send(bus_idx, "Master")
	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		_pitch_effect = AudioEffectPitchShift.new()
		_pitch_effect.pitch_scale = 1.0
		AudioServer.add_bus_effect(bus_idx, _pitch_effect)
		_lowpass_effect = AudioEffectLowPassFilter.new()
		_lowpass_effect.cutoff_hz = 8000.0
		AudioServer.add_bus_effect(bus_idx, _lowpass_effect)
	else:
		_pitch_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectPitchShift
		if AudioServer.get_bus_effect_count(bus_idx) > 1:
			_lowpass_effect = AudioServer.get_bus_effect(bus_idx, 1) as AudioEffectLowPassFilter


func _build_streams() -> void:
	_streams["tick"] = _make_tone(1900.0, 0.032, 55.0, 0.55)
	_streams["thud"] = _make_thud()
	_streams["clack"] = _make_tone(820.0, 0.045, 28.0, 0.42)
	_streams["soft"] = _make_tone(1100.0, 0.022, 48.0, 0.35)
	_streams["click"] = _make_tone(2400.0, 0.018, 70.0, 0.62)


func _make_tone(freq: float, seconds: float, decay: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := maxi(32, int(float(rate) * seconds))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * decay)
		var s := sin(TAU * freq * t) * env * amp
		var v := clampi(int(s * 32767.0), -32767, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_thud() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.06)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 32.0)
		var s := (sin(TAU * 130.0 * t) * 0.7 + sin(TAU * 280.0 * t) * 0.3) * env * 0.7
		var v := clampi(int(s * 32767.0), -32767, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _play(name: String, pitch: float = 1.0, gain: float = 1.0) -> void:
	if not AppSettings.sound_on:
		return
	if not _streams.has(name) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.7, 1.4)
	p.volume_db = linear_to_db(clampf(AppSettings.sound_volume * gain, 0.0001, 1.0))
	p.play()


func play_tick(pitch_scale: float = 1.0) -> void:
	_play("tick", pitch_scale, 0.7)


func play_thud() -> void:
	_play("thud", randf_range(0.92, 1.08), 0.85)


func play_clack(gain: float = 0.55) -> void:
	_play("clack", randf_range(0.88, 1.14), gain)


func play_key_soft() -> void:
	_play("soft", randf_range(0.96, 1.05), 0.4)


func play_key_click() -> void:
	_play("click", randf_range(0.94, 1.08), 0.8)


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
