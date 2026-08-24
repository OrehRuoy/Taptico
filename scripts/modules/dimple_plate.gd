extends FidgetModule
## Metal dimple plate. Tap to pop; Reset flips them back.

const COLS := 4
const ROWS := 5
const PLATE_TEX := preload("res://assets/modules/dimple_plate.png")
const UP_TEX := preload("res://assets/modules/dimple_up.png")
const DOWN_TEX := preload("res://assets/modules/dimple_down.png")
const HOLE_D := 156.0
const TEX_W := 1024.0
const TEX_H := 1536.0
const UP_CONTENT := 931.0
const DOWN_CONTENT := 554.0
## Placed by hand in the editor.
const HOLE_X := [
	[199.0, 407.0, 615.0, 823.0],
	[197.0, 408.0, 615.0, 822.0],
	[195.0, 406.0, 616.0, 822.0],
	[197.0, 407.0, 614.0, 822.0],
	[198.0, 406.0, 614.0, 823.0],
]
const HOLE_Y := [
	[269.0, 269.0, 270.0, 269.0],
	[491.0, 492.0, 492.0, 493.0],
	[711.0, 709.0, 710.0, 712.0],
	[930.0, 930.0, 930.0, 932.0],
	[1153.0, 1151.0, 1150.0, 1149.0],
]

var _popped: Array[bool] = []
var _drag_pop: bool = false
var _stroke: Array[int] = []
var _plate: Sprite2D
var _domes: Array[Sprite2D] = []
var _reset: Button


func _ready() -> void:
	module_id = "dimple_plate"
	display_name = "Dimple Plate"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_plate = Sprite2D.new()
	Chroma.apply(_plate, PLATE_TEX)
	_plate.centered = true
	add_child(_plate)
	_popped.resize(COLS * ROWS)
	for i in COLS * ROWS:
		_popped[i] = false
		var d := Sprite2D.new()
		Chroma.apply(d, UP_TEX)
		d.centered = true
		d.z_index = 1
		add_child(d)
		_domes.append(d)
	_reset = Button.new()
	_reset.text = "Reset"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.pressed.connect(_reset_pops)
	add_child(_reset)
	_reset.z_index = 20
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if size.x < 8.0 or PLATE_TEX == null:
		return
	var c := ReachSettings.play_center(size) + Vector2(0, -18.0)
	var target := minf(size.x * 0.78, size.y * 0.68)
	var sc := target / float(TEX_H)
	_plate.scale = Vector2(sc, sc)
	_plate.position = c
	_place_domes()
	var bw := 96.0
	var bh := 36.0
	_reset.position = Vector2(c.x - bw * 0.5, c.y + TEX_H * sc * 0.46)
	_reset.size = Vector2(bw, bh)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.15, 0.10)
	sb.border_color = DrawKit.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	_reset.add_theme_stylebox_override("normal", sb)
	_reset.add_theme_color_override("font_color", DrawKit.GOLD)
	_reset.add_theme_font_size_override("font_size", 14)


func _hole_x(col: int, row: int) -> float:
	return float(HOLE_X[clampi(row, 0, ROWS - 1)][clampi(col, 0, COLS - 1)])


func _hole_y(col: int, row: int) -> float:
	return float(HOLE_Y[clampi(row, 0, ROWS - 1)][clampi(col, 0, COLS - 1)])


func _place_domes() -> void:
	var sc: float = _plate.scale.x
	for row in ROWS:
		for col in COLS:
			var i := row * COLS + col
			var d := _domes[i]
			var down: bool = _popped[i]
			var content: float = DOWN_CONTENT if down else UP_CONTENT
			d.scale = Vector2.ONE * ((HOLE_D * sc) / content)
			d.offset = Vector2.ZERO
			d.position = _plate.position + Vector2(
				(_hole_x(col, row) - TEX_W * 0.5) * sc,
				(_hole_y(col, row) - TEX_H * 0.5) * sc
			)
			d.texture = Chroma.tex(DOWN_TEX) if down else Chroma.tex(UP_TEX)


func _reset_pops() -> void:
	var any := false
	for i in _popped.size():
		if _popped[i]:
			any = true
		_popped[i] = false
	if any:
		Haptics.heavy()
		AudioFeel.play_thud()
		_place_domes()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			if _reset.get_global_rect().has_point(_reset.get_global_mouse_position()):
				return
			_drag_pop = true
			_stroke.clear()
			_pop_at(button.position)
			accept_event()
		else:
			_drag_pop = false
	elif event is InputEventMouseMotion and _drag_pop:
		var motion := event as InputEventMouseMotion
		_pop_at(motion.position)
		accept_event()


func _pop_at(pos: Vector2) -> void:
	var i := _index_at(pos)
	if i < 0 or _stroke.has(i):
		return
	_stroke.append(i)
	_popped[i] = not _popped[i]
	if _popped[i]:
		Haptics.soft()
		Haptics.impact(0.20)
		AudioFeel.play_pop(0.16)
	else:
		Haptics.soft()
		AudioFeel.play_pop(0.10)
	_place_domes()


func _index_at(pos: Vector2) -> int:
	var sc: float = _plate.scale.x
	var best := -1
	var best_d := HOLE_D * sc * 0.62
	for row in ROWS:
		for col in COLS:
			var i := row * COLS + col
			var d: float = pos.distance_to(_domes[i].position)
			if d < best_d:
				best_d = d
				best = i
	return best
