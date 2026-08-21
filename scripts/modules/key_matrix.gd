extends FidgetModule
## Numpad. One feel at a time: Smooth, Bump, or Click.

enum SwitchStyle { LINEAR, TACTILE, CLICKY }

const KEYCAP_RAW := preload("res://assets/modules/keycap.png")
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
	var track := PanelContainer.new()
	track.name = "FeelRow"
	track.mouse_filter = Control.MOUSE_FILTER_STOP
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = Color(0.10, 0.13, 0.18, 0.96)
	track_box.set_corner_radius_all(22)
	track_box.border_width_left = 1
	track_box.border_width_top = 1
	track_box.border_width_right = 1
	track_box.border_width_bottom = 1
	track_box.border_color = Color(0.84, 0.70, 0.44, 0.70)
	track_box.content_margin_left = 4
	track_box.content_margin_right = 4
	track_box.content_margin_top = 4
	track_box.content_margin_bottom = 4
	track.add_theme_stylebox_override("panel", track_box)
	var row := HBoxContainer.new()
	row.name = "Segments"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.add_child(row)
	add_child(track)
	for i in FEEL_NAMES.size():
		var btn := Button.new()
		btn.text = FEEL_NAMES[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_NONE
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
			Chroma.apply(cap, KEYCAP_RAW)
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
	AudioFeel.play_tick()


func _style_feel_buttons() -> void:
	var last := _feel_buttons.size() - 1
	for i in _feel_buttons.size():
		var btn := _feel_buttons[i]
		var box := StyleBoxFlat.new()
		var rad_l := 18 if i == 0 else 4
		var rad_r := 18 if i == last else 4
		box.corner_radius_top_left = rad_l
		box.corner_radius_bottom_left = rad_l
		box.corner_radius_top_right = rad_r
		box.corner_radius_bottom_right = rad_r
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		if i == _feel:
			box.bg_color = Color(0.84, 0.70, 0.44)
			box.border_color = Color(0.96, 0.86, 0.58)
			btn.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
		else:
			box.bg_color = Color(0.0, 0.0, 0.0, 0)
			box.border_color = Color(0, 0, 0, 0)
			btn.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal", box)
		btn.add_theme_stylebox_override("hover", box)
		btn.add_theme_stylebox_override("pressed", box)


func _layout() -> void:
	if size.x < 8.0:
		return
	var last := _key_rect(3, 1)
	var row := get_node("FeelRow") as Control
	var row_h := 48.0
	var y := last.position.y + last.size.y + 16.0
	var max_y := size.y - row_h - 8.0
	if y > max_y:
		y = max_y
	var bar_w := minf(size.x - 28.0, 340.0)
	row.position = Vector2((size.x - bar_w) * 0.5, y)
	row.size = Vector2(bar_w, row_h)
	row.z_index = 8
	row.move_to_front()
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
	var feel_h := 62.0
	var side := minf(size.x, maxf(size.y - feel_h, 80.0))
	var key_len := clampf(side * 0.18, 56.0, 96.0)
	var key_s := Vector2(key_len, key_len)
	var gap := Vector2(key_len * 0.12, key_len * 0.14)
	var total := Vector2(3.0 * key_s.x + 2.0 * gap.x, 4.0 * key_s.y + 3.0 * gap.y)
	var usable := Vector2(size.x, maxf(size.y - feel_h, total.y))
	var origin := ReachSettings.cluster_origin(usable, total) + Vector2(0, 4)
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
			AudioFeel.play_key_soft()
		SwitchStyle.TACTILE:
			Haptics.medium()
			AudioFeel.play_thud()
		SwitchStyle.CLICKY:
			Haptics.rigid()
			AudioFeel.play_key_click()


func _fire_up() -> void:
	if FEEL_STYLES[_feel] == SwitchStyle.CLICKY:
		Haptics.double_pulse()
		AudioFeel.play_key_click()
	else:
		Haptics.selection()
