extends FidgetModule
## Combination lock — static bezel, only the inner dial spins.

const DETENT_COUNT := 40
const DETENT_ANGLE := TAU / float(DETENT_COUNT)
const DIAL_TEX := preload("res://assets/modules/lock_dial.png")
const BEZEL_TEX := preload("res://assets/modules/lock_bezel.png")

var _angle: float = 0.0
var _last_detent: int = 0
var _dragging: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _bezel: Sprite2D
var _dial: Sprite2D


func _ready() -> void:
	module_id = "combination_lock"
	display_name = "Combination Lock"
	is_premium = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_art()
	resized.connect(_layout)
	_layout()


func _build_art() -> void:
	_dial = Sprite2D.new()
	Chroma.apply(_dial, DIAL_TEX)
	_dial.z_index = 1
	_dial.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_dial)
	_bezel = Sprite2D.new()
	Chroma.apply(_bezel, BEZEL_TEX)
	_bezel.z_index = 2
	_bezel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_bezel)


func _center() -> Vector2:
	return ReachSettings.play_center(size)


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var c := _center()
	var target := minf(size.x, size.y) * 0.82
	if _bezel and _bezel.texture:
		var bezel_sc := target / float(_bezel.texture.get_width())
		_bezel.scale = Vector2(bezel_sc, bezel_sc)
		_bezel.position = c
	if _dial and _dial.texture:
		# Sit inside the bezel opening so only the numbered disc turns.
		var dial_sc := (target * 0.80) / float(_dial.texture.get_width())
		_dial.scale = Vector2(dial_sc, dial_sc)
		_dial.position = c
		_dial.rotation = _angle


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _near_dial(event.position):
			_dragging = true
			_last_pos = event.position
			accept_event()
		else:
			_dragging = false


func _input(event: InputEvent) -> void:
	if not _active or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event is InputEventMouseMotion:
		_spin_from(get_local_mouse_position())


func _spin_from(pos: Vector2) -> void:
	var center := _center()
	var delta_angle := wrapf((pos - center).angle() - (_last_pos - center).angle(), -PI, PI)
	_angle += delta_angle
	_last_pos = pos
	if _dial:
		_dial.rotation = _angle
	_check_detent()


func _near_dial(pos: Vector2) -> bool:
	return pos.distance_to(_center()) < minf(size.x, size.y) * 0.42


func _check_detent() -> void:
	var detent := int(floor((_angle / DETENT_ANGLE) + 0.5))
	if detent != _last_detent:
		_last_detent = detent
		Haptics.selection()
		AudioFeel.play_tick(randf_range(0.96, 1.08))
