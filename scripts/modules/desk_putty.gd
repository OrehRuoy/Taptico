extends FidgetModule
## Gray thinking putty in a gold tin. Slow, thick clay you can slide, stretch, and smoosh.

const TIN_PATH := "res://assets/modules/putty_tin.png"
const PUTTY_PATH := "res://assets/modules/putty_lump.png"
const STRETCH_SHADER := preload("res://shaders/putty_stretch.gdshader")
const TIN_D := 920.0
const WELL_D := 560.0
const MOUSE_ID := 0
const GRID_X := 28
const GRID_Y := 22
const MOLD_HZ := 2.6
const SLIDE_HZ := 3.8
const OOZE_PPS := 42.0
const REST_ROUND := 1.08


var _tin: Sprite2D
var _tex: Texture2D
var _mesh: MeshInstance2D
var _mat: ShaderMaterial
var _uvs: PackedVector2Array = PackedVector2Array()
var _indices: PackedInt32Array = PackedInt32Array()
var _reset: Button
var _tin_c := Vector2.ZERO
var _tin_r := 140.0
var _well_r := 96.0
var _home_r := 48.0
var _home_c := Vector2.ZERO
var _area := 1.0
var _com := Vector2.ZERO
var _axis := 0.0
var _rad_a := 48.0
var _rad_b := 48.0
var _grab_u := 0.0
var _grab_v := 0.0
var _placed := false
var _resetting := false
var _reset_t := 1.0
var _feel_acc := 0.0
var _haptic_cd := 0.0
var _audio_cd := 0.0
var _fingers: Dictionary = {}
var _finger_pos: Dictionary = {}
var _mouse_down := false


func _ready() -> void:
	module_id = "desk_putty"
	display_name = "Desk Putty"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_grid()
	_tin = Sprite2D.new()
	Chroma.apply(_tin, _load_png(TIN_PATH))
	_tin.centered = true
	_tin.z_index = 0
	add_child(_tin)
	_tex = Chroma.tex(_load_png(PUTTY_PATH))
	_mat = ShaderMaterial.new()
	_mat.shader = STRETCH_SHADER
	_mesh = MeshInstance2D.new()
	_mesh.texture = _tex
	_mesh.material = _mat
	_mesh.z_index = 1
	_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_mesh)
	_reset = Button.new()
	_reset.text = "Reset"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.pressed.connect(_knead_reset)
	_reset.z_index = 20
	add_child(_reset)
	resized.connect(_layout)
	_layout()


func _build_grid() -> void:
	_uvs.clear()
	_indices.clear()
	for j in GRID_Y + 1:
		for i in GRID_X + 1:
			_uvs.append(Vector2(float(i) / float(GRID_X), float(j) / float(GRID_Y)))
	for j in GRID_Y:
		for i in GRID_X:
			var a := j * (GRID_X + 1) + i
			var b := a + 1
			var c := a + GRID_X + 1
			var d := c + 1
			_indices.append(a)
			_indices.append(c)
			_indices.append(b)
			_indices.append(b)
			_indices.append(c)
			_indices.append(d)


func _layout() -> void:
	if size.x < 8.0 or _tin.texture == null:
		return
	var prev_c := _tin_c
	var prev_home := _home_r
	_tin_c = ReachSettings.play_center(size) + Vector2(0, -22.0)
	var target := minf(size.x * 0.82, size.y * 0.62)
	var sc := target / TIN_D
	_tin.scale = Vector2(sc, sc)
	_tin.position = _tin_c
	_tin_r = TIN_D * sc * 0.5
	_well_r = WELL_D * sc * 0.5
	_home_r = _well_r * 0.46
	_home_c = _tin_c
	if not _placed:
		_placed = true
		_com = _home_c
		_rad_a = _home_r
		_rad_b = _home_r * 0.96
		_axis = 0.0
		_area = _rad_a * _rad_b
	else:
		var s := _home_r / maxf(prev_home, 1.0)
		_com = _tin_c + (_com - prev_c) * s
		_rad_a *= s
		_rad_b *= s
		_area = _rad_a * _rad_b
	_sync_blob()
	var bw := 96.0
	var bh := 36.0
	_reset.position = Vector2(_tin_c.x - bw * 0.5, _tin_c.y + _tin_r + 10.0)
	_reset.size = Vector2(bw, bh)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.15, 0.10)
	sb.border_color = DrawKit.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	_reset.add_theme_stylebox_override("normal", sb)
	_reset.add_theme_color_override("font_color", DrawKit.GOLD)
	_reset.add_theme_font_size_override("font_size", 14)


func _load_png(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var img := Image.new()
	if img.load(path) != OK:
		push_error("Desk Putty: could not load %s" % path)
		return null
	return ImageTexture.create_from_image(img)


func _min_rad() -> float:
	return _home_r * 0.42


func _max_rad() -> float:
	return _well_r * 0.92


func _clamp_in_well(p: Vector2, margin: float) -> Vector2:
	var d: Vector2 = p - _tin_c
	var lim := maxf(4.0, _well_r - margin)
	var m := d.length()
	if m > lim:
		return _tin_c + d * (lim / m)
	return p


func _pull_amount() -> float:
	var aspect := maxf(_rad_a, _rad_b) / maxf(minf(_rad_a, _rad_b), 1.0)
	return clampf((aspect - REST_ROUND) / 1.6, 0.0, 1.0)


func _sync_blob() -> void:
	_rad_a = clampf(_rad_a, _min_rad(), _max_rad())
	_rad_b = clampf(_rad_b, _min_rad(), _max_rad())
	var reach := maxf(_rad_a, _rad_b) * 0.78
	_com = _clamp_in_well(_com, reach)
	_mesh.position = _com
	_mesh.rotation = _axis
	_deform()
	_mat.set_shader_parameter("stretch", _pull_amount())
	_mat.set_shader_parameter("neck", 0.0)


func _deform() -> void:
	var verts := PackedVector3Array()
	var tex_uvs := PackedVector2Array()
	verts.resize(_uvs.size())
	tex_uvs.resize(_uvs.size())
	for i in _uvs.size():
		var uv: Vector2 = _uvs[i]
		var u := uv.x * 2.0 - 1.0
		var v := uv.y * 2.0 - 1.0
		verts[i] = Vector3(u * _rad_a, v * _rad_b, 0.0)
		tex_uvs[i] = Vector2(0.5, 0.5) + Vector2(u, v) * 0.34
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.mesh = mesh


func _knead_reset() -> void:
	_resetting = true
	_reset_t = 0.0
	_fingers.clear()
	_finger_pos.clear()
	_mouse_down = false
	Haptics.heavy()
	AudioFeel.play_thud()


func _process(delta: float) -> void:
	super._process(delta)
	if not _active:
		return
	_haptic_cd = maxf(0.0, _haptic_cd - delta)
	_audio_cd = maxf(0.0, _audio_cd - delta)
	if _resetting:
		_reset_t = minf(1.0, _reset_t + delta * 2.2)
		var k := _reset_t * _reset_t * (3.0 - 2.0 * _reset_t)
		_com = _com.lerp(_home_c, k)
		_rad_a = lerpf(_rad_a, _home_r, k)
		_rad_b = lerpf(_rad_b, _home_r * 0.96, k)
		_axis = lerp_angle(_axis, 0.0, k)
		if _reset_t >= 1.0:
			_resetting = false
			_com = _home_c
			_rad_a = _home_r
			_rad_b = _home_r * 0.96
			_axis = 0.0
			_area = _rad_a * _rad_b
		_sync_blob()
		return
	_tick_putty(delta)
	_sync_blob()


func _grab_world() -> Vector2:
	return _com + Vector2(_grab_u * _rad_a, _grab_v * _rad_b).rotated(_axis)


func _tick_putty(delta: float) -> void:
	var ids: Array = _fingers.keys()
	var ooze := OOZE_PPS * delta
	if ids.size() >= 2:
		var p0: Vector2 = _finger_pos[ids[0]]
		var p1: Vector2 = _finger_pos[ids[1]]
		var mid: Vector2 = (p0 + p1) * 0.5
		var span: Vector2 = p1 - p0
		var ks := 1.0 - exp(-SLIDE_HZ * delta)
		_com = _com.lerp(_clamp_in_well(mid, 12.0), ks)
		if span.length() > 8.0:
			_axis = lerp_angle(_axis, span.angle(), 1.0 - exp(-MOLD_HZ * delta))
			var target_a := clampf(span.length() * 0.48, _min_rad(), _max_rad())
			_rad_a = move_toward(_rad_a, target_a, ooze)
			_rad_b = move_toward(_rad_b, clampf(_area / maxf(_rad_a, 8.0), _min_rad(), _max_rad()), ooze * 0.85)
		_feel_from(p0.distance_to(p1) * 0.08)
		return
	if ids.size() != 1:
		return
	var finger: Vector2 = _finger_pos[ids[0]]
	var grab_w := _grab_world()
	var step: Vector2 = grab_w.move_toward(finger, ooze * 1.35)
	var err: Vector2 = step - grab_w
	var err_l: Vector2 = err.rotated(-_axis)
	var au := absf(_grab_u)
	var av := absf(_grab_v)
	var w_slide := clampf(1.0 - maxf(au, av), 0.12, 1.0)
	var w_a := au
	var w_b := av
	var wsum := w_slide + w_a + w_b
	w_slide /= wsum
	w_a /= wsum
	w_b /= wsum
	_com = _clamp_in_well(_com + err * w_slide, 10.0)
	var sa := 1.0
	if absf(_grab_u) > 0.08:
		sa = signf(_grab_u)
	var sb := 1.0
	if absf(_grab_v) > 0.08:
		sb = signf(_grab_v)
	var da := err_l.x * sa * w_a
	var db := err_l.y * sb * w_b
	if au < 0.18:
		da *= 0.15
	if av < 0.18:
		db *= 0.15
	_rad_a = clampf(_rad_a + da, _min_rad(), _max_rad())
	_rad_b = clampf(_rad_b + db, _min_rad(), _max_rad())
	var now_area := _rad_a * _rad_b
	if w_b < 0.38:
		var target_b := clampf(_area / maxf(_rad_a, 8.0), _min_rad(), _max_rad())
		_rad_b = move_toward(_rad_b, target_b, ooze * 0.55)
	elif w_a < 0.38:
		var target_a := clampf(_area / maxf(_rad_b, 8.0), _min_rad(), _max_rad())
		_rad_a = move_toward(_rad_a, target_a, ooze * 0.55)
	else:
		_area = lerpf(_area, now_area, 0.08)
	_area = clampf(_rad_a * _rad_b, _min_rad() * _min_rad(), _max_rad() * _home_r * 1.4)
	var torque := _grab_u * err_l.y - _grab_v * err_l.x
	_axis += torque * 0.012
	_feel_from(err.length() / maxf(delta, 0.001) * 0.02)


func _hit_blob(p: Vector2) -> bool:
	var d: Vector2 = (p - _com).rotated(-_axis)
	var rx := maxf(14.0, _rad_a * 1.22)
	var ry := maxf(14.0, _rad_b * 1.22)
	return (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0


func _over_reset() -> bool:
	return _reset.get_global_rect().has_point(_reset.get_global_mouse_position())


func _input(event: InputEvent) -> void:
	if not _active or _resetting:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index == MOUSE_ID and _mouse_down:
			return
		var local_ev := make_input_local(event) as InputEventScreenTouch
		if touch.pressed:
			_set_finger(touch.index, true, local_ev.position)
			if _fingers.has(touch.index):
				accept_event()
		elif _fingers.has(touch.index):
			_set_finger(touch.index, false, local_ev.position)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == MOUSE_ID and _mouse_down:
			return
		if not _fingers.has(drag.index):
			return
		var local_ev := make_input_local(event) as InputEventScreenDrag
		_move_finger(drag.index, local_ev.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _over_reset():
			return
		if _fingers.has(MOUSE_ID) and not _mouse_down:
			return
		var local_ev := make_input_local(event) as InputEventMouseButton
		if event.pressed:
			_set_finger(MOUSE_ID, true, local_ev.position)
			if _fingers.has(MOUSE_ID):
				_mouse_down = true
				accept_event()
		else:
			if _fingers.has(MOUSE_ID) or _mouse_down:
				_mouse_down = false
				_set_finger(MOUSE_ID, false, local_ev.position)
				accept_event()
	elif event is InputEventMouseMotion and _mouse_down:
		var local_ev := make_input_local(event) as InputEventMouseMotion
		_move_finger(MOUSE_ID, local_ev.position)
		accept_event()


func _set_finger(id: int, pressed: bool, pos: Vector2) -> void:
	if pressed:
		if _fingers.is_empty() and pos.distance_to(_tin_c) > _tin_r + 10.0:
			if id == MOUSE_ID:
				_mouse_down = false
			return
		if _fingers.is_empty() and not _hit_blob(pos) and pos.distance_to(_com) > _home_r * 1.7:
			if id == MOUSE_ID:
				_mouse_down = false
			return
		_fingers[id] = true
		_finger_pos[id] = pos
		if _fingers.size() == 1:
			var local: Vector2 = (pos - _com).rotated(-_axis)
			_grab_u = clampf(local.x / maxf(_rad_a, 8.0), -1.15, 1.15)
			_grab_v = clampf(local.y / maxf(_rad_b, 8.0), -1.15, 1.15)
			Haptics.impact(0.26)
			AudioFeel.play_squelch(0.14)
	else:
		if not _fingers.has(id):
			return
		_fingers.erase(id)
		_finger_pos.erase(id)
		if id == MOUSE_ID:
			_mouse_down = false
		if _fingers.size() == 1:
			var leftover: int = _fingers.keys()[0]
			_finger_pos[leftover] = _finger_pos[leftover]
			var p: Vector2 = _finger_pos[leftover]
			var local: Vector2 = (p - _com).rotated(-_axis)
			_grab_u = clampf(local.x / maxf(_rad_a, 8.0), -1.15, 1.15)
			_grab_v = clampf(local.y / maxf(_rad_b, 8.0), -1.15, 1.15)
		Haptics.soft()


func _move_finger(id: int, pos: Vector2) -> void:
	if not _fingers.has(id):
		_set_finger(id, true, pos)
		return
	_finger_pos[id] = pos


func _feel_from(speed: float) -> void:
	_feel_acc += speed
	if _feel_acc > 14.0 and _haptic_cd <= 0.0:
		_feel_acc = 0.0
		_haptic_cd = 0.09
		Haptics.impact(clampf(speed / 22.0, 0.10, 0.32))
	if speed > 5.0 and _audio_cd <= 0.0:
		_audio_cd = 0.24
		AudioFeel.play_squelch(clampf(speed / 120.0, 0.06, 0.14))
