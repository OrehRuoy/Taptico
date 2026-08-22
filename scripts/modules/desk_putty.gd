extends FidgetModule
## Copper putty in a gold tin. Drag to move, two fingers / Shift to stretch slowly.

const TIN_PATH := "res://assets/modules/putty_tin.png"
const PUTTY_PATH := "res://assets/modules/putty_lump.png"
const STRETCH_SHADER := preload("res://shaders/putty_stretch.gdshader")
const TIN_D := 920.0
const WELL_D := 560.0
const PUTTY_D := 724.0
const MOUSE_ID := 0
const GRID_X := 32
const GRID_Y := 18
const MAX_BITS := 6
const STRETCH_PPS := 160.0
const BREAK_NECK := 0.96
const WAIST_PX := 34.0


class Bit:
	var mesh: MeshInstance2D
	var mat: ShaderMaterial
	var center := Vector2.ZERO
	var want := Vector2.ZERO
	var axis := 0.0
	var rad_a := 48.0
	var rad_b := 48.0
	var area := 1.0
	var area0 := 1.0
	var neck := 0.0
	var neck_rate := 0.0
	var grab_off := Vector2.ZERO
	var grabbed := false
	var still := 0.0
	var pinching := false
	var target_a := 48.0
	var target_axis := 0.0
	var target_center := Vector2.ZERO
	var pinch_mid0 := Vector2.ZERO
	var center0 := Vector2.ZERO
	var shift_stretch := false
	var hold_a := Vector2.ZERO
	var hold_b := Vector2.ZERO
	var goal_a := Vector2.ZERO
	var goal_b := Vector2.ZERO
	var has_ends := false
	var waist_travel := 0.0
	var grab_along := 0.0


var _tin: Sprite2D
var _tex: Texture2D
var _uvs: PackedVector2Array = PackedVector2Array()
var _indices: PackedInt32Array = PackedInt32Array()
var _reset: Button
var _bits: Array = []
var _tin_c := Vector2.ZERO
var _tin_r := 140.0
var _well_r := 96.0
var _home_r := 48.0
var _home_c := Vector2.ZERO
var _home_a := 48.0
var _home_b := 48.0
var _home_axis := 0.0
var _laid := false
var _resetting := false
var _reset_t := 1.0
var _feel_acc := 0.0
var _haptic_cd := 0.0
var _audio_cd := 0.0
var _fingers: Dictionary = {}
var _held: Dictionary = {}
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


func _add_bit(at: Vector2, rad_a: float, rad_b: float, axis: float, area: float) -> Bit:
	var bit := Bit.new()
	bit.mat = ShaderMaterial.new()
	bit.mat.shader = STRETCH_SHADER
	bit.mesh = MeshInstance2D.new()
	bit.mesh.texture = _tex
	bit.mesh.material = bit.mat
	bit.mesh.z_index = 1
	bit.mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(bit.mesh)
	bit.center = at
	bit.want = at
	bit.target_center = at
	bit.axis = axis
	bit.target_axis = axis
	bit.rad_a = rad_a
	bit.rad_b = rad_b
	bit.target_a = rad_a
	bit.area = area
	bit.area0 = area
	_bits.append(bit)
	return bit


func _drop_bit(bit: Bit) -> void:
	if bit.mesh:
		bit.mesh.queue_free()
	_bits.erase(bit)
	var drop: Array = []
	for id in _held.keys():
		if _held[id] == bit:
			drop.append(id)
	for id in drop:
		_held.erase(id)


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
	_home_a = _home_r
	_home_b = _home_r * 0.96
	_home_axis = 0.0
	if not _laid:
		_laid = true
		_clear_bits()
		_add_bit(_home_c, _home_a, _home_b, _home_axis, _home_a * _home_b)
	else:
		var s := _home_r / maxf(prev_home, 1.0)
		for bit in _bits:
			var b: Bit = bit
			b.center = _tin_c + (b.center - prev_c) * s
			b.want = b.center
			b.target_center = b.center
			b.rad_a *= s
			b.rad_b *= s
			b.target_a = b.rad_a
			b.area = b.rad_a * b.rad_b
			b.area0 = b.area
	_sync_bits()
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


func _clear_bits() -> void:
	for bit in _bits.duplicate():
		_drop_bit(bit)
	_bits.clear()
	_held.clear()


func _load_png(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var img := Image.new()
	if img.load(path) != OK:
		push_error("Desk Putty: could not load %s" % path)
		return null
	return ImageTexture.create_from_image(img)


func _min_thick() -> float:
	return _home_r * 0.11


func _max_long() -> float:
	return _well_r * 0.96


func _pull_amount(bit: Bit) -> float:
	var aspect := bit.rad_a / maxf(bit.rad_b, 1.0)
	return clampf((aspect - 1.02) / 2.05, 0.0, 1.0)


func _sync_bits() -> void:
	for bit in _bits:
		_clamp_bit(bit)
		bit.mesh.position = bit.center
		bit.mesh.rotation = bit.axis
		_deform_bit(bit)
		bit.mat.set_shader_parameter("stretch", _pull_amount(bit))
		bit.mat.set_shader_parameter("neck", bit.neck)


func _deform_bit(bit: Bit) -> void:
	var s := _pull_amount(bit)
	var n := bit.neck
	var verts := PackedVector3Array()
	verts.resize(_uvs.size())
	for i in _uvs.size():
		var uv: Vector2 = _uvs[i]
		var u := uv.x * 2.0 - 1.0
		var v := uv.y * 2.0 - 1.0
		var mid := 1.0 - u * u
		var neck := lerpf(1.0, 0.36, s * mid) * lerpf(1.0, 0.16, n * mid)
		var bulb := 1.0 + (s * 0.62 + n * 0.28) * (u * u)
		var x := u * bit.rad_a
		var y := v * bit.rad_b * neck * lerpf(1.0, bulb, clampf(s + n * 0.4, 0.0, 1.0))
		var sgn := 1.0 if v >= 0.0 else -1.0
		y += (s + n) * bit.rad_b * 0.10 * sin(u * 3.2) * mid * sgn
		x += s * bit.rad_a * 0.045 * sin(v * 3.7) * u
		y += s * bit.rad_b * 0.06 * u * u * u
		verts[i] = Vector3(x, y, 0.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	bit.mesh.mesh = mesh


func _clamp_bit(bit: Bit) -> void:
	bit.rad_a = clampf(bit.rad_a, _min_thick(), _max_long())
	bit.rad_b = clampf(bit.rad_b, _min_thick(), _max_long())
	var reach := maxf(bit.rad_a, bit.rad_b) * 0.90
	var lim := maxf(4.0, _well_r - reach)
	var d: Vector2 = bit.center - _tin_c
	var m := d.length()
	if m > lim:
		bit.center = _tin_c + d * (lim / m)
		bit.want = bit.center
		bit.target_center = bit.center


func _knead_reset() -> void:
	_resetting = true
	_reset_t = 0.0
	_fingers.clear()
	_held.clear()
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
		if _bits.is_empty():
			_add_bit(_home_c, _home_a, _home_b, _home_axis, _home_a * _home_b)
		var keep: Bit = _bits[0]
		keep.center = keep.center.lerp(_home_c, k)
		keep.want = keep.center
		keep.rad_a = lerpf(keep.rad_a, _home_a, k)
		keep.rad_b = lerpf(keep.rad_b, _home_b, k)
		keep.axis = lerp_angle(keep.axis, _home_axis, k)
		keep.neck = lerpf(keep.neck, 0.0, k)
		keep.pinching = false
		keep.shift_stretch = false
		for i in range(_bits.size() - 1, 0, -1):
			var extra: Bit = _bits[i]
			extra.center = extra.center.lerp(_home_c, k)
			extra.rad_a = lerpf(extra.rad_a, 4.0, k)
			extra.rad_b = lerpf(extra.rad_b, 4.0, k)
			if _reset_t >= 1.0:
				_drop_bit(extra)
		if _reset_t >= 1.0:
			_resetting = false
			keep.center = _home_c
			keep.want = _home_c
			keep.target_center = _home_c
			keep.rad_a = _home_a
			keep.rad_b = _home_b
			keep.axis = _home_axis
			keep.area = _home_a * _home_b
			keep.area0 = keep.area
			keep.neck = 0.0
		_sync_bits()
		return
	var split_list: Array = []
	for bit in _bits:
		_tick_bit(bit, delta)
		if bit.neck >= BREAK_NECK:
			split_list.append(bit)
	for bit in split_list:
		_split_bit(bit)
	_sync_bits()


func _tick_bit(bit: Bit, delta: float) -> void:
	if (bit.pinching or bit.shift_stretch) and bit.has_ends:
		_apply_ends(bit, delta)
		bit.want = bit.center
		bit.still = 0.0
	else:
		bit.has_ends = false
		bit.center = bit.center.lerp(bit.want, 1.0 - exp(-11.0 * delta))
	if bit.neck_rate > 0.35 and bit.waist_travel >= WAIST_PX:
		bit.neck = minf(1.0, bit.neck + bit.neck_rate * 0.22 * delta)
		bit.rad_b = maxf(_min_thick(), bit.rad_b - bit.neck_rate * 6.0 * delta)
		bit.area = bit.rad_a * bit.rad_b


func _apply_ends(bit: Bit, delta: float) -> void:
	var k := 1.0 - exp(-8.5 * delta)
	bit.hold_a = bit.hold_a.lerp(bit.goal_a, k)
	bit.hold_b = bit.hold_b.lerp(bit.goal_b, k)
	bit.hold_a = bit.hold_a.move_toward(bit.goal_a, STRETCH_PPS * delta)
	bit.hold_b = bit.hold_b.move_toward(bit.goal_b, STRETCH_PPS * delta)
	var span: Vector2 = bit.hold_b - bit.hold_a
	if span.length() < 4.0:
		return
	bit.axis = span.angle()
	bit.rad_a = clampf(span.length() * 0.5, _min_thick(), _max_long())
	bit.rad_b = clampf(bit.area0 / maxf(bit.rad_a, 8.0), _min_thick(), _max_long())
	bit.center = (bit.hold_a + bit.hold_b) * 0.5
	bit.area = bit.rad_a * bit.rad_b


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


func _bit_at(pos: Vector2) -> Bit:
	var best: Bit = null
	var best_d := INF
	for bit in _bits:
		var b: Bit = bit
		if not _hit_bit(b, pos):
			continue
		var d: float = pos.distance_to(b.center)
		if d < best_d:
			best_d = d
			best = b
	if best:
		return best
	var near: Bit = null
	var nd := _tin_r
	for bit in _bits:
		var b: Bit = bit
		var d: float = pos.distance_to(b.center)
		if d < nd:
			nd = d
			near = b
	return near


func _hit_bit(bit: Bit, p: Vector2) -> bool:
	var d: Vector2 = (p - bit.center).rotated(-bit.axis)
	var rx := maxf(8.0, bit.rad_a * 1.2)
	var ry := maxf(8.0, bit.rad_b * 1.25)
	return (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0


func _is_strand(bit: Bit) -> bool:
	return bit.rad_a / maxf(bit.rad_b, 1.0) > 2.05


func _is_waist_grab(bit: Bit) -> bool:
	return absf(bit.grab_along) < bit.rad_a * 0.20


func _set_finger(id: int, pressed: bool, pos: Vector2) -> void:
	if pressed:
		if _fingers.is_empty() and pos.distance_to(_tin_c) > _tin_r + 10.0:
			if id == MOUSE_ID:
				_mouse_down = false
			return
		_fingers[id] = true
		_finger_pos[id] = pos
		var bit := _bit_at(pos)
		if bit == null:
			_fingers.erase(id)
			_finger_pos.erase(id)
			return
		_held[id] = bit
		_begin_hold(id, bit, pos)
	else:
		if not _fingers.has(id):
			return
		_fingers.erase(id)
		_finger_pos.erase(id)
		var bit: Bit = _held.get(id, null)
		_held.erase(id)
		if id == MOUSE_ID:
			_mouse_down = false
		if bit:
			bit.pinching = false
			bit.shift_stretch = false
			bit.has_ends = false
			bit.neck_rate = 0.0
			_refresh_bit_mode(bit)
		Haptics.soft()


func _begin_hold(id: int, bit: Bit, pos: Vector2) -> void:
	bit.grabbed = _hit_bit(bit, pos)
	if bit.grabbed:
		bit.grab_off = pos - bit.center
	else:
		bit.grab_off = Vector2.ZERO
	bit.want = pos - bit.grab_off
	bit.still = 0.0
	bit.neck_rate = 0.0
	bit.waist_travel = 0.0
	bit.grab_along = (pos - bit.center).rotated(-bit.axis).x
	bit.shift_stretch = false
	bit.has_ends = false
	_refresh_bit_mode(bit)
	Haptics.impact(0.34)
	AudioFeel.play_squelch(0.22)


func _ids_on(bit: Bit) -> Array:
	var ids: Array = []
	for id in _held.keys():
		if _held[id] == bit:
			ids.append(id)
	return ids


func _refresh_bit_mode(bit: Bit) -> void:
	var ids := _ids_on(bit)
	if ids.size() >= 2:
		bit.pinching = true
		bit.shift_stretch = false
		var p0: Vector2 = _finger_pos[ids[0]]
		var p1: Vector2 = _finger_pos[ids[1]]
		bit.area0 = maxf(bit.rad_a * bit.rad_b, 16.0)
		_capture_ends(bit, p0, p1)
	else:
		bit.pinching = false


func _capture_ends(bit: Bit, p0: Vector2, p1: Vector2) -> void:
	var ang := (p1 - p0).angle()
	var proj := _radii_on_axis(bit, ang)
	bit.axis = ang
	bit.rad_a = proj.x
	bit.rad_b = proj.y
	var dir := Vector2.from_angle(ang)
	var a: Vector2 = bit.center - dir * bit.rad_a
	var b: Vector2 = bit.center + dir * bit.rad_a
	if p0.distance_to(a) <= p0.distance_to(b):
		bit.hold_a = a
		bit.hold_b = b
		bit.goal_a = p0
		bit.goal_b = p1
	else:
		bit.hold_a = b
		bit.hold_b = a
		bit.goal_a = p1
		bit.goal_b = p0
	bit.has_ends = true


func _begin_end_stretch(bit: Bit, pos: Vector2) -> void:
	var local: Vector2 = (pos - bit.center).rotated(-bit.axis)
	var dir := Vector2.from_angle(bit.axis)
	var sgn := 1.0 if local.x >= 0.0 else -1.0
	bit.hold_a = bit.center - dir * bit.rad_a * sgn
	bit.hold_b = bit.center + dir * bit.rad_a * sgn
	bit.goal_a = bit.hold_a
	bit.goal_b = pos
	bit.has_ends = true
	bit.shift_stretch = true
	bit.pinching = false
	bit.area0 = maxf(bit.rad_a * bit.rad_b, 16.0)


func _radii_on_axis(bit: Bit, ang: float) -> Vector2:
	var da := ang - bit.axis
	var c := cos(da)
	var s := sin(da)
	var a := maxf(bit.rad_a, 8.0)
	var b := maxf(bit.rad_b, 8.0)
	var along := 1.0 / sqrt((c * c) / (a * a) + (s * s) / (b * b))
	var across := 1.0 / sqrt((s * s) / (a * a) + (c * c) / (b * b))
	return Vector2(along, across)


func _move_finger(id: int, pos: Vector2) -> void:
	if not _fingers.has(id):
		_set_finger(id, true, pos)
		return
	_finger_pos[id] = pos
	if not _held.has(id):
		return
	var bit: Bit = _held[id]
	var ids := _ids_on(bit)
	if ids.size() >= 2:
		var p0: Vector2 = _finger_pos[ids[0]]
		var p1: Vector2 = _finger_pos[ids[1]]
		if not bit.has_ends:
			_capture_ends(bit, p0, p1)
		if p0.distance_to(bit.hold_a) <= p0.distance_to(bit.hold_b):
			bit.goal_a = p0
			bit.goal_b = p1
		else:
			bit.goal_a = p1
			bit.goal_b = p0
		bit.pinching = true
		bit.shift_stretch = false
		bit.has_ends = true
		bit.neck_rate = 0.0
		_feel_from(2.0)
		return
	if Input.is_key_pressed(KEY_SHIFT):
		if not bit.shift_stretch or not bit.has_ends:
			_begin_end_stretch(bit, pos)
		bit.goal_b = pos
		bit.neck_rate = 0.0
		_feel_from(2.0)
		return
	bit.shift_stretch = false
	bit.pinching = false
	bit.has_ends = false
	_smear_bit(bit, pos)
	_feel_from((pos - bit.center).length() * 0.02)


func _smear_bit(bit: Bit, finger: Vector2) -> void:
	if _is_strand(bit) and bit.grabbed and _is_waist_grab(bit):
		var local: Vector2 = (finger - bit.center).rotated(-bit.axis)
		var dperp := absf(local.y) - bit.rad_b * 0.7
		bit.waist_travel = maxf(bit.waist_travel, dperp)
		if bit.waist_travel >= WAIST_PX:
			bit.neck_rate = clampf(dperp / maxf(bit.rad_b, 8.0), 0.0, 1.8)
		else:
			bit.neck_rate = 0.0
		bit.want = bit.center.lerp(finger - bit.grab_off, 0.08)
	else:
		bit.neck_rate = 0.0
		bit.want = finger - bit.grab_off


func _split_bit(bit: Bit) -> void:
	if not _bits.has(bit):
		return
	if _bits.size() >= MAX_BITS:
		bit.neck = 0.72
		return
	var dir := Vector2.from_angle(bit.axis)
	var sep := bit.rad_a * 0.50
	var mass := maxf(bit.area * 0.5, _min_thick() * _min_thick() * 8.0)
	var r := clampf(sqrt(mass) * 0.72, _home_r * 0.22, _home_r * 0.62)
	var a_pos: Vector2 = bit.center - dir * sep
	var b_pos: Vector2 = bit.center + dir * sep
	var old_axis := bit.axis
	var ids := _ids_on(bit)
	_drop_bit(bit)
	var left := _add_bit(a_pos, r, r * 0.92, old_axis + 0.15, mass)
	var right := _add_bit(b_pos, r, r * 0.92, old_axis - 0.15, mass)
	for id in ids:
		var p: Vector2 = _finger_pos.get(id, left.center)
		_held[id] = left if p.distance_to(left.center) <= p.distance_to(right.center) else right
		var nxt: Bit = _held[id]
		nxt.grabbed = true
		nxt.grab_off = p - nxt.center
		nxt.want = p - nxt.grab_off
	Haptics.heavy()
	AudioFeel.play_squelch(0.42)
	AudioFeel.play_thud()


func _feel_from(speed: float) -> void:
	_feel_acc += speed
	if _feel_acc > 18.0 and _haptic_cd <= 0.0:
		_feel_acc = 0.0
		_haptic_cd = 0.07
		Haptics.impact(clampf(speed / 28.0, 0.10, 0.36))
	if speed > 4.0 and _audio_cd <= 0.0:
		_audio_cd = 0.12
		AudioFeel.play_squelch(clampf(speed / 90.0, 0.10, 0.30))
