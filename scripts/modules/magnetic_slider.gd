extends FidgetModule
## Magnetic EDC slider. Drag the inner plate; it snaps to either end.

const FRAME_TEX := preload("res://assets/modules/slider_frame.png")
const PLATE_TEX := preload("res://assets/modules/slider_plate.png")

var _t: float = 0.0
var _vel: float = 0.0
var _dragging: bool = false
var _last_detent: int = 0
var _last_end: int = 0
var _grab: float = 0.0
var _frame_spr: Sprite2D
var _plate_spr: Sprite2D


func _ready() -> void:
	module_id = "magnetic_slider"
	display_name = "Magnetic Slider"
	is_premium = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame_spr = _sprite(FRAME_TEX, 0)
	_plate_spr = _sprite(PLATE_TEX, 1)
	resized.connect(_layout)
	_layout()


func _sprite(tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	Chroma.apply(s, tex)
	s.centered = true
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	return s


func _layout() -> void:
	if size.x < 8.0 or FRAME_TEX == null:
		return
	var c := ReachSettings.play_center(size)
	var target_w := minf(size.x * 0.94, 420.0)
	var fsc := target_w / float(FRAME_TEX.get_width())
	_frame_spr.scale = Vector2(fsc, fsc)
	_frame_spr.position = c
	var inner_w: float = _inner_width()
	var plate_visual: float = inner_w * 0.52
	var plate_content: float = float(PLATE_TEX.get_width()) * 0.653
	_plate_spr.scale = Vector2.ONE * (plate_visual / maxf(8.0, plate_content))
	_place_plate()


func _inner_width() -> float:
	return float(FRAME_TEX.get_width()) * _frame_spr.scale.x * 0.668


func _plate_width() -> float:
	return float(PLATE_TEX.get_width()) * _plate_spr.scale.x * 0.58


func _max_offset() -> float:
	return maxf(0.0, (_inner_width() - _plate_width()) * 0.5)


func _place_plate() -> void:
	var y: float = _frame_spr.position.y + 24.0 * _plate_spr.scale.y
	_plate_spr.position = Vector2(_frame_spr.position.x + lerpf(-_max_offset(), _max_offset(), _t), y)


func _process(delta: float) -> void:
	if not _active or _dragging:
		return
	var target := 0.0 if _t < 0.5 else 1.0
	var dist := target - _t
	_vel += dist * 18.0 * delta
	_vel *= exp(-9.0 * delta)
	_t = clampf(_t + _vel * delta, 0.0, 1.0)
	var end := 0 if _t < 0.08 else (1 if _t > 0.92 else -1)
	if end != -1 and end != _last_end:
		_last_end = end
		_vel *= 0.2
		Haptics.rigid()
		AudioFeel.play_tick(0.82)
	_place_plate()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed and _hit(button.position):
			_dragging = true
			_grab = button.position.x - _plate_spr.position.x
			_vel = 0.0
			accept_event()
		else:
			_release()


func _input(event: InputEvent) -> void:
	if not _active or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var x: float = motion.position.x - _grab
		var x0: float = _frame_spr.position.x - _max_offset()
		var x1: float = _frame_spr.position.x + _max_offset()
		_t = clampf(inverse_lerp(x0, x1, x), 0.0, 1.0)
		var detent := int(round(_t * 6.0))
		if detent != _last_detent:
			_last_detent = detent
			Haptics.selection()
			AudioFeel.play_tick(lerpf(0.88, 1.16, _t))
		_place_plate()
		accept_event()


func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	_last_end = -1


func _hit(pos: Vector2) -> bool:
	var w := FRAME_TEX.get_width() * _frame_spr.scale.x
	var h := FRAME_TEX.get_height() * _frame_spr.scale.y
	return Rect2(_frame_spr.position - Vector2(w, h) * 0.5, Vector2(w, h)).grow(12.0).has_point(pos)
