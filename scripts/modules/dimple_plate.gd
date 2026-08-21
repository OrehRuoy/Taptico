extends FidgetModule
## Metal dimple plate. Tap to pop; Reset flips them back.

const COLS := 4
const ROWS := 5
const PLATE_TEX := preload("res://assets/modules/dimple_plate.png")
const UP_TEX := preload("res://assets/modules/dimple_up.png")
const DOWN_TEX := preload("res://assets/modules/dimple_down.png")
const HOLE_D := 180.0
const TEX_W := 1024.0
const TEX_H := 1536.0

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


func _hole_x(col: int) -> float:
	match col:
		0:
			return 194.0
		1:
			return 406.0
		2:
			return 618.0
		_:
			return 830.0


func _hole_y(row: int) -> float:
	match row:
		0:
			return 211.0
		1:
			return 427.0
		2:
			return 643.0
		3:
			return 859.0
		_:
			return 1075.0


func _place_domes() -> void:
	var sc: float = _plate.scale.x
	for row in ROWS:
		for col in COLS:
			var i := row * COLS + col
			var d := _domes[i]
			var down: bool = _popped[i]
			var content: float = 560.0 if down else 928.0
			d.scale = Vector2.ONE * ((HOLE_D * sc) / content)
			d.offset = Vector2(-1.0, -19.0) if down else Vector2(-12.0, -23.0)
			d.position = _plate.position + Vector2(
				(_hole_x(col) - TEX_W * 0.5) * sc,
				(_hole_y(row) - TEX_H * 0.5) * sc
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
		Haptics.impact(0.55)
		AudioFeel.play_pop(0.75)
	else:
		Haptics.soft()
		AudioFeel.play_pop(0.4)
	_place_domes()


func _index_at(pos: Vector2) -> int:
	var sc: float = _plate.scale.x
	var best := -1
	var best_d := HOLE_D * sc * 0.55
	for row in ROWS:
		for col in COLS:
			var i := row * COLS + col
			var d: float = pos.distance_to(_domes[i].position)
			if d < best_d:
				best_d = d
				best = i
	return best
