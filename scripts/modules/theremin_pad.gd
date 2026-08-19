extends FidgetModule
## Ambient Pad — circular touch plate. X = tone, Y = brightness.

const PLATE_TEX := preload("res://assets/modules/ambient_pad.png")
const CHROMA := preload("res://shaders/chroma_key.gdshader")

@onready var pad: TextureRect = $Pad
@onready var glow: ColorRect = $Glow
@onready var noise_player: AudioStreamPlayer = $NoisePlayer

var _touching: bool = false
var _pointer := Vector2(0.5, 0.5)
var _glow_pos := Vector2(0.5, 0.5)
var _phase: float = 0.0
var _brown: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _plate: Sprite2D
var _fx: Control
var _plate_radius: float = 140.0
var _labels: Dictionary = {}
const AXIS_GAP := 18.0
const AXIS_COLOR := Color(0.92, 0.80, 0.54, 1.0)


func _ready() -> void:
	module_id = "theremin_pad"
	display_name = "Ambient Pad"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if pad:
		pad.hide()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow:
		glow.hide()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = Sprite2D.new()
	_plate.texture = PLATE_TEX
	var mat := ShaderMaterial.new()
	mat.shader = CHROMA
	_plate.material = mat
	_plate.z_index = 0
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_plate)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = 12
	_fx.draw.connect(_draw_finger_fx)
	add_child(_fx)
	_labels["brighter"] = _make_axis_label("BRIGHTER")
	_labels["warmer"] = _make_axis_label("WARMER")
	_labels["lower"] = _make_axis_label("LOWER")
	_labels["higher"] = _make_axis_label("HIGHER")
	_setup_noise()
	resized.connect(_layout)
	_layout()


func _make_axis_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", AXIS_COLOR)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	lab.add_theme_constant_override("outline_size", 5)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.z_index = 14
	add_child(lab)
	return lab


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var c := ReachSettings.play_center(size)
	var well_d := minf(size.x, size.y) * 0.68
	if _plate and _plate.texture:
		var sc := well_d / float(_plate.texture.get_width())
		_plate.scale = Vector2(sc, sc)
		_plate.position = c
	_plate_radius = well_d * 0.46
	_place_axis_labels(c)
	if _fx:
		_fx.queue_redraw()


func _place_axis_labels(center: Vector2) -> void:
	var r := _plate_radius
	var gap := AXIS_GAP
	var w := 110.0
	var h := 22.0
	var brighter: Label = _labels["brighter"]
	brighter.size = Vector2(w, h)
	brighter.position = Vector2(center.x - w * 0.5, center.y - r - gap - h)
	var warmer: Label = _labels["warmer"]
	warmer.size = Vector2(w, h)
	warmer.position = Vector2(center.x - w * 0.5, center.y + r + gap)
	var lower: Label = _labels["lower"]
	lower.size = Vector2(w, h)
	lower.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lower.position = Vector2(center.x - r - gap - w, center.y - h * 0.5)
	var higher: Label = _labels["higher"]
	higher.size = Vector2(w, h)
	higher.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	higher.position = Vector2(center.x + r + gap, center.y - h * 0.5)


func _setup_noise() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.1
	noise_player.stream = gen
	noise_player.bus = "Ambient"


func on_activate() -> void:
	if not noise_player.playing:
		noise_player.play()
		_playback = noise_player.get_stream_playback()


func on_deactivate() -> void:
	noise_player.stop()
	_playback = null
	AudioFeel.reset_modulation()


func _process(delta: float) -> void:
	if not _active:
		return
	_glow_pos = _glow_pos.lerp(_pointer, clampf(delta * 14.0, 0.0, 1.0))
	if _playback:
		var to_fill := _playback.get_frames_available()
		for i in to_fill:
			_brown += randf_range(-0.04, 0.04)
			_brown = clampf(_brown, -0.25, 0.25)
			_phase += 0.002
			var sample := _brown + sin(_phase) * 0.012
			_playback.push_frame(Vector2(sample, sample * 0.92))
	if _fx:
		_fx.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_touching = event.pressed
		_update_from_pos(event.position)
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_touching = true
		_update_from_pos(event.position)
		accept_event()


func _update_from_pos(pos: Vector2) -> void:
	var center := _plate.position if _plate else size * 0.5
	var local := pos - center
	if local.length() > _plate_radius:
		local = local.normalized() * _plate_radius
	_pointer = Vector2(
		clampf(0.5 + local.x / maxf(_plate_radius * 2.0, 1.0), 0.0, 1.0),
		clampf(0.5 + local.y / maxf(_plate_radius * 2.0, 1.0), 0.0, 1.0)
	)
	AudioFeel.set_lowpass_from_position(_pointer.y)
	AudioFeel.set_pitch_from_velocity(absf(_pointer.x - 0.5) * 2200.0)


func _draw_finger_fx() -> void:
	if _plate == null:
		return
	var center: Vector2 = _plate.position
	var glow_pos := center + Vector2((_glow_pos.x - 0.5) * _plate_radius * 2.0, (_glow_pos.y - 0.5) * _plate_radius * 2.0)
	var a := 0.95 if _touching else 0.28
	_fx.draw_circle(glow_pos, 52.0, Color(0.95, 0.78, 0.32, a * 0.10))
	_fx.draw_circle(glow_pos, 34.0, Color(0.98, 0.86, 0.42, a * 0.22))
	_fx.draw_circle(glow_pos, 18.0, Color(1.0, 0.94, 0.72, a * 0.55))
	_fx.draw_circle(glow_pos, 7.0, Color(1.0, 0.98, 0.92, a * 0.95))
	if _touching:
		_fx.draw_arc(glow_pos, 26.0, 0.0, TAU, 48, Color(1.0, 0.90, 0.55, 0.45), 1.5, true)
