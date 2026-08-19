extends FidgetModule
## Numpad. One feel at a time: Smooth, Bump, or Click.

enum SwitchStyle { LINEAR, TACTILE, CLICKY }

const KEYCAP_RAW := preload("res://assets/modules/keycap.png")
const CHROMA := preload("res://shaders/chroma_key.gdshader")
const LAYOUT := [
	[{"label": "7"}, {"label": "8"}, {"label": "9"}],
	[{"label": "4"}, {"label": "5"}, {"label": "6"}],
	[{"label": "1"}, {"label": "2"}, {"label": "3"}],
	[{"label": "", "empty": true}, {"label": "0"}, {"label": "", "empty": true}],
]
const FEEL_NAMES := ["Smooth", "Bump", "Click"]
const FEEL_STYLES := [SwitchStyle.LINEAR, SwitchStyle.TACTILE, SwitchStyle.CLICKY]

var _pressed_key: Dictionary = {}
var _caps: Array[Sprite2D] = []
var _cap_keys: Array[Dictionary] = []
var _num_labels: Array[Label] = []
var _feel_buttons: Array[Button] = []
var _feel: int = 2


func _ready() -> void:
	module_id = "key_matrix"
	display_name = "Key Matrix"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var chroma := ShaderMaterial.new()
	chroma.shader = CHROMA
	var row := HBoxContainer.new()
	row.name = "FeelRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	for i in FEEL_NAMES.size():
		var btn := Button.new()
		btn.text = FEEL_NAMES[i]
		btn.custom_minimum_size = Vector2(108, 44)
		btn.pressed.connect(_set_feel.bind(i))
		row.add_child(btn)
		_feel_buttons.append(btn)
	_style_feel_buttons()
	for row_idx in LAYOUT.size():
		for col in LAYOUT[row_idx].size():
			var key: Dictionary = LAYOUT[row_idx][col]
			if key.get("empty", false):
				continue
			var cap := Sprite2D.new()
			cap.texture = KEYCAP_RAW
			cap.material = chroma
			cap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(cap)
			_caps.append(cap)
			_cap_keys.append({"row": row_idx, "col": col})
			var lab := Label.new()
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.add_theme_font_size_override("font_size", 22)
			lab.add_theme_color_override("font_color", Color(0.18, 0.18, 0.20, 0.88))
			lab.text = str(key["label"])
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(lab)
			_num_labels.append(lab)
	resized.connect(_layout)
	_layout()


func _set_feel(index: int) -> void:
	_feel = index
	_style_feel_buttons()
	Haptics.selection()


func _style_feel_buttons() -> void:
	for i in _feel_buttons.size():
		var btn := _feel_buttons[i]
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(18)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		box.border_width_left = 1
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		if i == _feel:
			box.bg_color = Color(0.84, 0.70, 0.44)
			box.border_color = Color(0.96, 0.86, 0.58)
			btn.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
		else:
			box.bg_color = Color(0.10, 0.11, 0.13, 0.96)
			box.border_color = Color(0.84, 0.70, 0.44, 0.45)
			btn.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_stylebox_override("normal", box)
		btn.add_theme_stylebox_override("hover", box)
		btn.add_theme_stylebox_override("pressed", box)


func _layout() -> void:
	if size.x < 8.0:
		return
	var first := _key_rect(0, 0)
	var row := get_node("FeelRow") as HBoxContainer
	row.position = Vector2(8, first.position.y - 78)
	row.size = Vector2(size.x - 16, 48)
	for i in _caps.size():
		_place_cap(i)


func _place_cap(i: int) -> void:
	var meta: Dictionary = _cap_keys[i]
	var r := _key_rect(int(meta["row"]), int(meta["col"]))
	var active: bool = false
	if not _pressed_key.is_empty():
		active = int(_pressed_key.get("row", -1)) == int(meta["row"]) and int(_pressed_key.get("col", -1)) == int(meta["col"])
	var draw_r := r.grow(-1.0)
	if active:
		draw_r.position.y += 6
		draw_r.size *= 0.96
		draw_r.position.x += r.size.x * 0.02
		_caps[i].modulate = Color(0.72, 0.72, 0.74)
	else:
		_caps[i].modulate = Color.WHITE
	if _caps[i].texture:
		var sc := draw_r.size.x / float(_caps[i].texture.get_width())
		_caps[i].scale = Vector2(sc, sc)
		_caps[i].position = draw_r.get_center()
	_num_labels[i].position = draw_r.position
	_num_labels[i].size = draw_r.size


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var row := get_node_or_null("FeelRow") as Control
		if row and Rect2(row.position, row.size).grow(4.0).has_point(event.position):
			return
		if event.pressed:
			_press_at(event.position)
		else:
			_release()
		accept_event()


func _press_at(pos: Vector2) -> void:
	var data := _key_at(pos)
	if data.is_empty():
		return
	_pressed_key = data
	_fire_down()
	_layout()


func _release() -> void:
	if not _pressed_key.is_empty():
		_fire_up()
		_pressed_key = {}
		_layout()


func _metrics() -> Dictionary:
	var key_s := Vector2(72, 72)
	var gap := Vector2(10, 12)
	var total := Vector2(3.0 * key_s.x + 2.0 * gap.x, 4.0 * key_s.y + 3.0 * gap.y + 58.0)
	var origin := ReachSettings.cluster_origin(size, total) + Vector2(0, 8)
	return {"key": key_s, "gap": gap, "origin": origin}


func _key_rect(row: int, col: int) -> Rect2:
	var m := _metrics()
	var key_s: Vector2 = m["key"]
	var gap: Vector2 = m["gap"]
	var origin: Vector2 = m["origin"]
	return Rect2(origin.x + col * (key_s.x + gap.x), origin.y + row * (key_s.y + gap.y), key_s.x, key_s.y)


func _key_at(pos: Vector2) -> Dictionary:
	for row_idx in LAYOUT.size():
		for col in LAYOUT[row_idx].size():
			var key: Dictionary = LAYOUT[row_idx][col]
			if key.get("empty", false):
				continue
			if _key_rect(row_idx, col).has_point(pos):
				return {"row": row_idx, "col": col, "label": key["label"]}
	return {}


func _fire_down() -> void:
	match FEEL_STYLES[_feel]:
		SwitchStyle.LINEAR:
			Haptics.light()
		SwitchStyle.TACTILE:
			Haptics.medium()
		SwitchStyle.CLICKY:
			Haptics.rigid()


func _fire_up() -> void:
	if FEEL_STYLES[_feel] == SwitchStyle.CLICKY:
		Haptics.double_pulse()
	else:
		Haptics.selection()
