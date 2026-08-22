extends FidgetModule
## Eight hinged cubes. Drag from the top, bottom, or a side to fold, like a real infinity cube.

const GOLD := Color(0.86, 0.70, 0.40)
const GOLD_HI := Color(0.94, 0.82, 0.55)
const STEEL := Color(0.42, 0.44, 0.46)
const STEEL_DK := Color(0.22, 0.23, 0.24)
const EDGE := Color(0.10, 0.09, 0.07, 0.85)

var _pos: Array[Vector3] = []
var _moving: Array[int] = []
var _mode: String = ""
var _hx: float = 2.0
var _hy: float = 1.0
var _hz: float = 2.0
var _t: float = 0.0
var _dragging: bool = false
var _grab := Vector2.ZERO
var _origin := Vector2.ZERO
var _s: float = 48.0


func _ready() -> void:
	module_id = "infinity_cube"
	display_name = "Infinity Cube"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pos.clear()
	for iy in 2:
		for iz in 2:
			for ix in 2:
				_pos.append(Vector3(float(ix), float(iy), float(iz)))
	resized.connect(_layout)
	_layout()


func on_activate() -> void:
	queue_redraw()


func _layout() -> void:
	if size.x < 8.0:
		return
	_origin = ReachSettings.play_center(size) + Vector2(0, 12.0)
	_s = minf(size.x, size.y) * 0.12
	queue_redraw()


func _is_cube() -> bool:
	var b := _extent()
	return b.x < 2.6 and b.y < 2.6 and b.z < 2.6


func _extent() -> Vector3:
	var mn := _pos[0]
	var mx := _pos[0]
	for p in _pos:
		mn = Vector3(minf(mn.x, p.x), minf(mn.y, p.y), minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), maxf(mx.y, p.y), maxf(mx.z, p.z))
	return mx - mn + Vector3.ONE


func _limits() -> Array[Vector3]:
	var mn := _pos[0]
	var mx := _pos[0]
	for p in _pos:
		mn = Vector3(minf(mn.x, p.x), minf(mn.y, p.y), minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), maxf(mx.y, p.y), maxf(mx.z, p.z))
	var out: Array[Vector3] = []
	out.append(mn)
	out.append(mx)
	return out


func _setup_layer(which: String, side: String) -> void:
	var lim := _limits()
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	_moving.clear()
	var prefix := "top_"
	if which == "bot":
		prefix = "bot_"
		_hy = mn.y + 1.0
		for i in 8:
			if _pos[i].y <= mn.y + 0.05:
				_moving.append(i)
	else:
		_hy = mx.y
		for i in 8:
			if _pos[i].y >= mx.y - 0.05:
				_moving.append(i)
	match side:
		"px":
			_mode = prefix + "px"
			_hx = mx.x + 1.0
		"nx":
			_mode = prefix + "nx"
			_hx = mn.x
		"pz":
			_mode = prefix + "pz"
			_hz = mx.z + 1.0
		_:
			_mode = prefix + "nz"
			_hz = mn.z


func _setup_top(side: String) -> void:
	_setup_layer("top", side)


func _setup_slab(side: String) -> void:
	var lim := _limits()
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	var ext := mx - mn + Vector3.ONE
	_moving.clear()
	_hy = mn.y + 1.0
	# A stick/tower is long on Y. Fold that 4+4 or the piece cannot move.
	if ext.y >= 3.6 and ext.y >= ext.x and ext.y >= ext.z:
		_setup_y_slab(side)
		return
	var want_x: bool = side == "px" or side == "nx"
	if want_x and ext.x < 1.9:
		want_x = false
	if (not want_x) and ext.z < 1.9:
		want_x = ext.x >= ext.z
	if want_x:
		var mid: float = mn.x + ext.x * 0.5
		if side == "nx" or side == "nz":
			_mode = "slab_nx"
			_hx = mid
			for i in 8:
				if _pos[i].x <= mid - 0.95:
					_moving.append(i)
		else:
			_mode = "slab_px"
			_hx = mid
			for i in 8:
				if _pos[i].x >= mid - 0.05:
					_moving.append(i)
	else:
		var midz: float = mn.z + ext.z * 0.5
		if side == "nz" or side == "nx":
			_mode = "slab_nz"
			_hz = midz
			for i in 8:
				if _pos[i].z <= midz - 0.95:
					_moving.append(i)
		else:
			_mode = "slab_pz"
			_hz = midz
			for i in 8:
				if _pos[i].z >= midz - 0.05:
					_moving.append(i)
	if _moving.size() != 4:
		_setup_y_slab(side)


func _setup_y_slab(side: String) -> void:
	var lim := _limits()
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	var ext := mx - mn + Vector3.ONE
	_moving.clear()
	_mode = ""
	if ext.y < 3.6:
		return
	var mid: float = mn.y + ext.y * 0.5
	_hy = mid
	for i in 8:
		if _pos[i].y >= mid - 0.05:
			_moving.append(i)
	if _moving.size() != 4:
		_moving.clear()
		for i in 8:
			if _pos[i].y <= mid - 0.95:
				_moving.append(i)
	if _moving.size() != 4:
		_moving.clear()
		_mode = ""
		return
	match side:
		"px":
			_mode = "top_px"
			_hx = mx.x + 1.0
		"nx":
			_mode = "top_nx"
			_hx = mn.x
		"pz":
			_mode = "top_pz"
			_hz = mx.z + 1.0
		_:
			_mode = "top_nz"
			_hz = mn.z


func _setup_x_layer(hi: bool, side: String) -> void:
	var lim := _limits()
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	_moving.clear()
	if hi:
		_hx = mx.x
		for i in 8:
			if _pos[i].x >= mx.x - 0.05:
				_moving.append(i)
	else:
		_hx = mn.x + 1.0
		for i in 8:
			if _pos[i].x <= mn.x + 0.05:
				_moving.append(i)
	var prefix := "xhi_" if hi else "xlo_"
	match side:
		"px":
			_mode = prefix + "px"
			_hy = mx.y + 1.0
		"nx":
			_mode = prefix + "nx"
			_hy = mn.y
		"pz":
			_mode = prefix + "pz"
			_hz = mx.z + 1.0
		_:
			_mode = prefix + "nz"
			_hz = mn.z


func _setup_z_layer(hi: bool, side: String) -> void:
	var lim := _limits()
	var mn: Vector3 = lim[0]
	var mx: Vector3 = lim[1]
	_moving.clear()
	if hi:
		_hz = mx.z
		for i in 8:
			if _pos[i].z >= mx.z - 0.05:
				_moving.append(i)
	else:
		_hz = mn.z + 1.0
		for i in 8:
			if _pos[i].z <= mn.z + 0.05:
				_moving.append(i)
	var prefix := "zhi_" if hi else "zlo_"
	match side:
		"px":
			_mode = prefix + "px"
			_hx = mx.x + 1.0
		"nx":
			_mode = prefix + "nx"
			_hx = mn.x
		"pz":
			_mode = prefix + "pz"
			_hy = mx.y + 1.0
		_:
			_mode = prefix + "nz"
			_hy = mn.y


func _rotate_p(p: Vector3, ang: float) -> Vector3:
	var c := cos(ang)
	var s := sin(ang)
	var r: Vector3
	match _mode:
		"top_px", "bot_px", "slab_nx", "xhi_px", "xlo_px":
			r = p - Vector3(_hx, _hy, p.z)
			return Vector3(_hx, _hy, p.z) + Vector3(r.x * c - r.y * s, r.x * s + r.y * c, 0.0)
		"top_nx", "bot_nx", "slab_px", "xhi_nx", "xlo_nx":
			r = p - Vector3(_hx, _hy, p.z)
			return Vector3(_hx, _hy, p.z) + Vector3(r.x * c + r.y * s, -r.x * s + r.y * c, 0.0)
		"top_pz", "bot_pz", "slab_nz", "zhi_pz", "zlo_pz":
			r = p - Vector3(p.x, _hy, _hz)
			return Vector3(p.x, _hy, _hz) + Vector3(0.0, r.y * c - r.z * s, r.y * s + r.z * c)
		"top_nz", "bot_nz", "slab_pz", "zhi_nz", "zlo_nz":
			r = p - Vector3(p.x, _hy, _hz)
			return Vector3(p.x, _hy, _hz) + Vector3(0.0, r.y * c + r.z * s, -r.y * s + r.z * c)
		"xhi_pz", "xlo_pz", "zhi_px", "zlo_px":
			r = p - Vector3(_hx, p.y, _hz)
			return Vector3(_hx, p.y, _hz) + Vector3(r.x * c - r.z * s, 0.0, r.x * s + r.z * c)
		"xhi_nz", "xlo_nz", "zhi_nx", "zlo_nx":
			r = p - Vector3(_hx, p.y, _hz)
			return Vector3(_hx, p.y, _hz) + Vector3(r.x * c + r.z * s, 0.0, -r.x * s + r.z * c)
		_:
			return p


func _anim_corner(i: int, d: Vector3) -> Vector3:
	var p: Vector3 = _pos[i] + d
	if _mode == "" or not _moving.has(i) or _t <= 0.001:
		return p
	return _rotate_p(p, _t * PI)


func _commit_fold() -> void:
	for i in _moving:
		var mn := Vector3(999, 999, 999)
		for dz in 2:
			for dy in 2:
				for dx in 2:
					var q := _rotate_p(_pos[i] + Vector3(float(dx), float(dy), float(dz)), PI)
					mn = Vector3(minf(mn.x, q.x), minf(mn.y, q.y), minf(mn.z, q.z))
		_pos[i] = Vector3(round(mn.x), round(mn.y), round(mn.z))
	_moving.clear()
	_mode = ""
	_t = 0.0
	var lim := _limits()
	var mn: Vector3 = lim[0]
	for i in 8:
		_pos[i] -= Vector3(roundf(mn.x), roundf(mn.y), roundf(mn.z))
	Haptics.medium()
	AudioFeel.play_snap(0.72)


func _process(delta: float) -> void:
	if not _active or _dragging:
		return
	if _mode == "" or is_zero_approx(_t):
		return
	var target := 1.0 if _t > 0.34 else 0.0
	_t = move_toward(_t, target, delta * 4.0)
	if is_equal_approx(_t, 1.0):
		_commit_fold()
	elif is_zero_approx(_t):
		_moving.clear()
		_mode = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_dragging = true
			_grab = button.position
			if is_zero_approx(_t):
				_mode = ""
				_moving.clear()
			accept_event()
		else:
			_dragging = false


func _input(event: InputEvent) -> void:
	if not _active or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event is InputEventMouseMotion:
		var local_ev := make_input_local(event) as InputEventMouseMotion
		var d: Vector2 = local_ev.position - _grab
		if _mode == "" and d.length() > 12.0:
			var side := "px"
			if absf(d.x) >= absf(d.y):
				side = "px" if d.x > 0.0 else "nx"
			else:
				side = "pz" if d.y > 0.0 else "nz"
			if _is_cube():
				var lx: float = _grab.x - _origin.x
				var ly: float = _grab.y - _origin.y
				if absf(ly) > absf(lx) * 1.12:
					_setup_layer("bot" if ly > 8.0 else "top", side)
				elif absf(lx) > absf(ly) * 1.12:
					_setup_x_layer(lx > 0.0, side)
				else:
					_setup_z_layer(lx + ly > 0.0, side)
				if _moving.is_empty():
					_setup_layer("bot" if ly > 8.0 else "top", side)
			else:
				_setup_slab(side)
			if _moving.is_empty():
				_mode = ""
		if _mode != "":
			_t = _progress_from(d)
			queue_redraw()
		accept_event()


func _progress_from(d: Vector2) -> float:
	var span: float = maxf(72.0, _s * 5.0)
	if _mode.ends_with("px"):
		return clampf(d.x / span, 0.0, 1.0)
	if _mode.ends_with("nx"):
		return clampf(-d.x / span, 0.0, 1.0)
	if _mode.ends_with("pz"):
		return clampf(d.y / span, 0.0, 1.0)
	if _mode.ends_with("nz"):
		return clampf(-d.y / span, 0.0, 1.0)
	return clampf(d.length() / span, 0.0, 1.0)


func _centroid() -> Vector3:
	var s := Vector3.ZERO
	for i in 8:
		s += _anim_corner(i, Vector3(0.5, 0.5, 0.5))
	return s / 8.0


func _draw() -> void:
	var faces: Array[Dictionary] = []
	for i in 8:
		_collect_cubie(i, faces)
	faces.sort_custom(func(a, b): return float(a["depth"]) < float(b["depth"]))
	for f in faces:
		var pts: PackedVector2Array = f["pts"]
		draw_colored_polygon(pts, f["color"])
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), EDGE, 1.2, true)


func _collect_cubie(i: int, faces: Array[Dictionary]) -> void:
	var corners: Array[Vector3] = []
	for dz in 2:
		for dy in 2:
			for dx in 2:
				corners.append(_anim_corner(i, Vector3(float(dx), float(dy), float(dz))))
	_add_face(faces, corners, [2, 3, 7, 6], GOLD_HI)
	_add_face(faces, corners, [0, 2, 6, 4], STEEL_DK)
	_add_face(faces, corners, [1, 5, 7, 3], STEEL)
	_add_face(faces, corners, [4, 6, 7, 5], GOLD)
	_add_face(faces, corners, [0, 1, 3, 2], Color(0.32, 0.30, 0.28))


func _add_face(faces: Array[Dictionary], corners: Array[Vector3], idx: Array, col: Color) -> void:
	var a: Vector3 = corners[idx[0]]
	var b: Vector3 = corners[idx[1]]
	var c: Vector3 = corners[idx[2]]
	var n: Vector3 = (b - a).cross(c - a)
	var view := Vector3(-0.55, 0.8, -0.45)
	if n.dot(view) < 0.02:
		return
	var pts := PackedVector2Array()
	var depth := 0.0
	for k in idx:
		var p: Vector3 = corners[k]
		pts.append(_proj(p))
		depth += p.x + p.z + p.y
	faces.append({"pts": pts, "color": col, "depth": depth / 4.0})


func _proj(p: Vector3) -> Vector2:
	var c := _centroid()
	p -= c
	var x: float = (p.x - p.z) * 0.866
	var y: float = -p.y + (p.x + p.z) * 0.42
	return _origin + Vector2(x, y) * _s
