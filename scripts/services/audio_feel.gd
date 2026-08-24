extends Node
## Fidget audio. Lock and spinner keep the procedural tick; everything else
## uses recorded CC0 one-shots from BigSoundBank (Joseph Sardin / DavidGreck).

const AMBIENT_BUS := "Ambient"
const POOL := 10
const AUDIO_DIR := "res://assets/audio"
const WAV_THUD := preload("res://assets/audio/thud.wav")
const WAV_SWITCH := preload("res://assets/audio/switch.wav")
const WAV_CLACK := preload("res://assets/audio/clack.wav")
const WAV_KEY_SOFT := preload("res://assets/audio/key_soft.wav")
const WAV_KEY_CLICK := preload("res://assets/audio/key_click.wav")
const WAV_CLICK := preload("res://assets/audio/click.wav")
const WAV_POP := preload("res://assets/audio/pop.wav")
const WAV_PEN := preload("res://assets/audio/pen_click.wav")
const WAV_ZIP := preload("res://assets/audio/zip.wav")
const WAV_FOLD := preload("res://assets/audio/fold.wav")
const WAV_RUB := preload("res://assets/audio/rub.wav")

var _pitch_effect: AudioEffectPitchShift
var _lowpass_effect: AudioEffectLowPassFilter
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _held: Dictionary = {}
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
	_streams["thud"] = _sample_or("thud.wav", _make_thud)
	_streams["switch"] = _sample_or("switch.wav", _make_thud)
	_streams["clack"] = _sample_or("clack.wav", _tone_clack)
	_streams["soft"] = _sample_or("key_soft.wav", _tone_soft)
	_streams["key_click"] = _sample_or("key_click.wav", _tone_key)
	_streams["mech"] = _sample_or("click.wav", _tone_mech)
	_streams["snap"] = _sample_or("snap.wav", _tone_snap)
	_streams["pop"] = _sample_or("pop.wav", _tone_pop)
	_streams["pen_click"] = _sample_or("pen_click.wav", _make_pen_click)
	_streams["squelch"] = _make_putty()
	_streams["zip"] = _loop_wav(_sample_or("zip.wav", _make_zip_tooth))
	_streams["fold"] = _sample_or("fold.wav", _make_paper_fold)
	_streams["rub"] = _loop_wav(_sample_or("rub.wav", _make_rub))


func _sample_or(file_name: String, fallback: Callable) -> AudioStream:
	var packed := _packed_wav(file_name)
	if packed:
		return packed
	var path := "%s/%s" % [AUDIO_DIR, file_name]
	var parsed := _load_wav(path)
	if parsed:
		return parsed
	return fallback.call()


func _packed_wav(file_name: String) -> AudioStream:
	match file_name:
		"thud.wav":
			return WAV_THUD
		"switch.wav":
			return WAV_SWITCH
		"clack.wav":
			return WAV_CLACK
		"key_soft.wav":
			return WAV_KEY_SOFT
		"key_click.wav":
			return WAV_KEY_CLICK
		"click.wav":
			return WAV_CLICK
		"pop.wav":
			return WAV_POP
		"pen_click.wav":
			return WAV_PEN
		"zip.wav":
			return WAV_ZIP
		"fold.wav":
			return WAV_FOLD
		"rub.wav":
			return WAV_RUB
		_:
			return null


func _loop_wav(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	var frames := int(round(wav.get_length() * float(wav.mix_rate)))
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		var bytes_per_frame := 4 if wav.stereo else 2
		frames = maxi(1, int(wav.data.size() / bytes_per_frame))
	wav.loop_end = maxi(1, frames - 1)
	return wav


func _load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return null
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return null
	var mix_rate := 44100
	var channels := 1
	var bits := 16
	var data := PackedByteArray()
	while f.get_position() + 8 <= f.get_length():
		var chunk := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var next := f.get_position() + size
		if chunk == "fmt ":
			f.get_16()
			channels = f.get_16()
			mix_rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
		elif chunk == "data":
			data = f.get_buffer(size)
			break
		f.seek(next + (size % 2))
	if data.is_empty() or bits != 16:
		return null
	if channels == 2:
		data = _downmix_s16(data)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _downmix_s16(stereo: PackedByteArray) -> PackedByteArray:
	var n := stereo.size() / 4
	var mono := PackedByteArray()
	mono.resize(n * 2)
	for i in n:
		var l := stereo.decode_s16(i * 4)
		var r := stereo.decode_s16(i * 4 + 2)
		mono.encode_s16(i * 2, clampi(int((l + r) / 2.0), -32767, 32767))
	return mono


func _tone_clack() -> AudioStreamWAV:
	return _make_tone(820.0, 0.045, 28.0, 0.42)


func _tone_soft() -> AudioStreamWAV:
	return _make_tone(1100.0, 0.022, 48.0, 0.35)


func _tone_key() -> AudioStreamWAV:
	return _make_tone(2400.0, 0.018, 70.0, 0.62)


func _tone_mech() -> AudioStreamWAV:
	return _make_tone(1800.0, 0.02, 60.0, 0.5)


func _tone_snap() -> AudioStreamWAV:
	return _make_tone(1550.0, 0.028, 62.0, 0.58)


func _tone_pop() -> AudioStreamWAV:
	return _make_tone(980.0, 0.05, 36.0, 0.5)


func _encode_pcm(data: PackedByteArray, i: int, sample: float) -> void:
	var v := clampi(int(sample * 32767.0), -32767, 32767)
	data[i * 2] = v & 0xFF
	data[i * 2 + 1] = (v >> 8) & 0xFF


func _pcm_stream(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_zip_tooth() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.26)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hits := [0.0, 0.032, 0.061, 0.094, 0.128, 0.162, 0.196, 0.228]
	for i in n:
		var t := float(i) / float(rate)
		var s := 0.0
		for h in hits:
			var dt: float = t - float(h)
			if dt < 0.0 or dt > 0.04:
				continue
			s += sin(TAU * 2650.0 * dt) * exp(-dt * 140.0) * 0.26
			s += sin(TAU * 1480.0 * dt) * exp(-dt * 90.0) * 0.20
			s += sin(TAU * 420.0 * dt) * exp(-dt * 48.0) * 0.14
			s += (rng.randf() * 2.0 - 1.0) * exp(-dt * 70.0) * 0.16
		_encode_pcm(data, i, s)
	return _pcm_stream(data, rate)


func _make_paper_fold() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var rustle := 0.0
	for i in n:
		var t := float(i) / float(rate)
		rustle += (rng.randf() * 2.0 - 1.0) * 0.35
		rustle *= 0.72
		var env := 0.0
		if t < 0.045:
			env = t / 0.045
		elif t < 0.12:
			env = 1.0 - (t - 0.045) / 0.075 * 0.55
		else:
			env = 0.45 * exp(-(t - 0.12) * 18.0)
		var s := rustle * env * 0.42
		s += sin(TAU * 190.0 * t) * exp(-t * 22.0) * 0.18
		s += sin(TAU * 90.0 * t) * exp(-t * 16.0) * 0.22
		var crease := t - 0.028
		if crease > 0.0:
			s += sin(TAU * 620.0 * crease) * exp(-crease * 48.0) * 0.16
			s += (rng.randf() * 2.0 - 1.0) * exp(-crease * 55.0) * 0.12
		_encode_pcm(data, i, s)
	return _pcm_stream(data, rate)


func _make_rub() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var brown := 0.0
	for i in n:
		var t := float(i) / float(rate)
		brown += (rng.randf() * 2.0 - 1.0) * 0.045
		brown *= 0.91
		var fade := 1.0
		if t < 0.012:
			fade = t / 0.012
		elif t > 0.208:
			fade = (0.22 - t) / 0.012
		var 		s := brown * fade * 0.42
		s += sin(TAU * 64.0 * t) * fade * 0.06
		_encode_pcm(data, i, s)
	return _pcm_stream(data, rate)


func _make_putty() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.11)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var brown := 0.0
	for i in n:
		var t := float(i) / float(rate)
		brown += (rng.randf() * 2.0 - 1.0) * 0.045
		brown *= 0.96
		var env := exp(-t * 14.0) * (1.0 - exp(-t * 70.0))
		var s := brown * env * 0.55
		s += sin(TAU * 46.0 * t) * env * 0.16
		s += sin(TAU * 78.0 * t) * exp(-t * 20.0) * 0.08
		_encode_pcm(data, i, s * 0.72)
	return _pcm_stream(data, rate)


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


func _make_pen_click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.052)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t := float(i) / float(rate)
		var s := 0.0
		s += sin(TAU * 2550.0 * t) * exp(-t * 95.0) * 0.52
		s += sin(TAU * 1120.0 * t) * exp(-t * 58.0) * 0.36
		s += sin(TAU * 380.0 * t) * exp(-t * 36.0) * 0.24
		s += (rng.randf() * 2.0 - 1.0) * exp(-t * 150.0) * 0.30
		var t2 := t - 0.012
		if t2 > 0.0:
			s += sin(TAU * 1980.0 * t2) * exp(-t2 * 110.0) * 0.34
			s += (rng.randf() * 2.0 - 1.0) * exp(-t2 * 170.0) * 0.14
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


func _make_squelch() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var brown := 0.0
	for i in n:
		var t := float(i) / float(rate)
		brown += (rng.randf() * 2.0 - 1.0) * 0.08
		brown *= 0.94
		var env := exp(-t * 22.0)
		var s := sin(TAU * 72.0 * t) * env * 0.38
		s += sin(TAU * 118.0 * t) * exp(-t * 28.0) * 0.22
		s += brown * env * 0.55
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


func _play_held(name: String, pitch: float = 1.0, gain: float = 1.0) -> void:
	if not AppSettings.sound_on or not _streams.has(name):
		return
	var p: AudioStreamPlayer
	if _held.has(name):
		p = _held[name]
	else:
		p = AudioStreamPlayer.new()
		p.bus = AMBIENT_BUS
		add_child(p)
		_held[name] = p
	if p.stream != _streams[name]:
		p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.7, 1.4)
	p.volume_db = linear_to_db(clampf(AppSettings.sound_volume * gain, 0.0001, 1.0))
	if not p.playing:
		p.play()


func stop_held(name: String) -> void:
	if not _held.has(name):
		return
	(_held[name] as AudioStreamPlayer).stop()


func play_tick(pitch_scale: float = 1.0) -> void:
	_play("tick", pitch_scale, 0.7)


func play_thud() -> void:
	_play("thud", randf_range(0.92, 1.08), 0.9)


func play_switch() -> void:
	_play("switch", randf_range(0.94, 1.08), 0.95)


func play_pen_click(tip_out: bool = true) -> void:
	var pitch: float = (1.06 if tip_out else 0.90) * randf_range(0.98, 1.02)
	_play("pen_click", pitch, 1.0)


func play_clack(gain: float = 0.55) -> void:
	_play("clack", randf_range(0.88, 1.14), gain)


func play_click(pitch_scale: float = 1.0) -> void:
	_play("mech", pitch_scale, 0.62)


func play_key_soft() -> void:
	_play("soft", randf_range(0.96, 1.05), 0.55)


func play_key_click() -> void:
	_play("key_click", randf_range(0.94, 1.08), 0.85)


func play_snap(gain: float = 0.7) -> void:
	_play("snap", randf_range(0.92, 1.12), gain)


func play_pop(gain: float = 0.6) -> void:
	_play("pop", randf_range(0.88, 1.18), gain)


func play_squelch(gain: float = 0.3) -> void:
	_play("squelch", randf_range(0.88, 1.08), gain)


func play_zip(pitch_scale: float = 1.0, gain: float = 0.48) -> void:
	_play_held("zip", pitch_scale, gain)


func play_fold(gain: float = 0.72) -> void:
	_play("fold", randf_range(0.94, 1.08), gain)


func play_rub(gain: float = 0.42) -> void:
	_play_held("rub", 1.0, gain)


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
