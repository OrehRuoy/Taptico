extends FidgetModule
## Two taped rows of teeth. Below the slider they mesh; above it they part in a V.
## Slider at the top is fully closed; drag it down to open. Only a drag that
## starts on the slider moves it.

const TAPE_PATH := "res://assets/modules/zipper_open.png"
const PULL_TEX := preload("res://assets/modules/zipper_pull.png")

# Leather-only columns of zipper_open.png (683 x 1024), teeth excluded.
const TAPE_TEX_W := 683.0
const TAPE_L_PX := Vector2(174.0, 238.0)
const TAPE_R_PX := Vector2(446.0, 510.0)

# zipper_pull.png (768 x 768): the body spans y 140..318 and is 156 px at its widest.
# The meshed chain leaves the body at PULL_MESH; the tab ends at PULL_BOTTOM.
const PULL_PX := 768.0
const PULL_CX := 382.0
const PULL_TOP := 140.0
const PULL_MESH := 318.0
const PULL_BOTTOM := 632.0
const PULL_LEFT := 300.0
const PULL_RIGHT := 470.0
const PULL_BODY_W := 156.0

# Sizes at the reference tape length; everything scales with _k.
const REF_LEN := 280.0
const TAPE_W := 34.0
const TOOTH_LEN := 13.0
const TOOTH_H := 4.6
const PITCH := 7.0
const INTERLOCK := 2.5
const CORD_GRIP := 3.0
const SPREAD_LIN := 0.16
const SPREAD_CURVE := 0.10
const STOP_TOP_H := 4.5
const STOP_BOTTOM_H := 7.0
const END_MARGIN := 6.0
const SEG := 4.0

const HIT_MIN_DP := 48.0
const HIT_MIN_UNITS := 64.0
const MOVE_EPS := 0.5
const SPEED_FULL := 900.0

const BRASS_HI := Color(0.99, 0.88, 0.56)
const BRASS := Color(0.86, 0.68, 0.32)
const BRASS_LO := Color(0.50, 0.36, 0.14)
const BRASS_EDGE := Color(0.16, 0.10, 0.03, 0.8)
const CORD := Color(0.045, 0.04, 0.035)
const STITCH := Color(0.36, 0.36, 0.38, 0.55)

var _open: float = 0.0
var _dragging: bool = false
var _grab_dy: float = 0.0
var _last_tooth: int = -1
var _anchor_y: float = 0.0
var _anchor_ms: int = 0
var _last_move_ms: int = 0
var _speed: float = 0.0
var _tape_tex: Texture2D
var _pull_tex: Texture2D

var _k: float = 1.0
var _cx: float = 0.0
var _y_top: float = 0.0
var _y_bot: float = 0.0
var _mesh_min: float = 0.0
var _mesh_max: float = 0.0
var _pull_scale: float = 0.0

var _tooth_poly: PackedVector2Array
var _tooth_cols: PackedColorArray
var _tooth_outline: PackedVector2Array


func _ready() -> void:
	module_id = "zipper"
	display_name = "Zipper"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tape_tex = _load_png(TAPE_PATH)
	_pull_tex = Chroma.tex(PULL_TEX)
	_build_tooth()
	resized.connect(_layout)
	_layout()


func on_deactivate() -> void:
	_end_drag()


func _end_drag() -> void:
	_dragging = false
	_speed = 0.0
	AudioFeel.stop_zip()


func _load_png(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _build_tooth() -> void:
	var h := TOOTH_H * 0.5
	_tooth_poly = PackedVector2Array([
		Vector2(0.0, -h), Vector2(TOOTH_LEN - 1.4, -h), Vector2(TOOTH_LEN, -h + 1.2),
		Vector2(TOOTH_LEN, h - 1.2), Vector2(TOOTH_LEN - 1.4, h), Vector2(0.0, h),
	])
	_tooth_cols = PackedColorArray([BRASS_HI, BRASS_HI, BRASS, BRASS_LO.lerp(BRASS, 0.3), BRASS_LO, BRASS_LO])
	_tooth_outline = _tooth_poly.duplicate()
	_tooth_outline.append(_tooth_poly[0])


func _layout() -> void:
	if size.y < 8.0:
		return
	var c := ReachSettings.play_center(size)
	var length := minf(size.y * 0.50, REF_LEN)
	_k = length / REF_LEN
	_cx = c.x
	_y_top = c.y - length * 0.54
	_y_bot = _y_top + length
	_pull_scale = (_chain_half() * 2.0 + 12.0 * _k) / PULL_BODY_W
	_mesh_min = _y_top + (END_MARGIN + STOP_TOP_H) * _k + (PULL_MESH - PULL_TOP) * _pull_scale
	_mesh_max = _y_bot - (END_MARGIN + STOP_BOTTOM_H) * _k
	queue_redraw()


func _chain_half() -> float:
	return (TOOTH_LEN - INTERLOCK) * _k


func _mesh_y() -> float:
	return lerpf(_mesh_min, _mesh_max, _open)


func _spread(y: float, mesh_y: float) -> float:
	var d := mesh_y - y
	if d <= 0.0:
		return 0.0
	return SPREAD_LIN * d + SPREAD_CURVE * d * d / maxf(1.0, _y_bot - _y_top)


func _spread_slope(y: float, mesh_y: float) -> float:
	var d := mesh_y - y
	if d <= 0.0:
		return 0.0
	return SPREAD_LIN + 2.0 * SPREAD_CURVE * d / maxf(1.0, _y_bot - _y_top)


func _root_x(side: float, y: float, mesh_y: float) -> float:
	return _cx + side * (_chain_half() + _spread(y, mesh_y))


func _row_ys(mesh_y: float) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	var stop_at := minf(mesh_y, _y_bot)
	var y := _y_top
	while y < stop_at:
		ys.append(y)
		y += SEG * _k
	ys.append(stop_at)
	if stop_at < _y_bot:
		ys.append(_y_bot)
	return ys


func _first_tooth_y() -> float:
	return _y_top + (END_MARGIN + STOP_TOP_H + 2.5) * _k


func _last_tooth_y() -> float:
	return _y_bot - (END_MARGIN + STOP_BOTTOM_H + 2.5) * _k


func _tooth_at(mesh_y: float) -> int:
	return int(floor((mesh_y - _mesh_min) / (PITCH * _k)))


func _draw() -> void:
	if _pull_scale <= 0.0:
		return
	var mesh_y := _mesh_y()
	var ys := _row_ys(mesh_y)
	for side in [-1.0, 1.0]:
		_draw_tape(side, ys, mesh_y)
	for side in [-1.0, 1.0]:
		_draw_cord(side, ys, mesh_y)
	for side in [-1.0, 1.0]:
		_draw_top_stop(side, mesh_y)
	_draw_teeth(mesh_y)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_bottom_stop()
	_draw_slider(mesh_y)


func _draw_tape(side: float, ys: PackedFloat32Array, mesh_y: float) -> void:
	var inner_off := _chain_half() - CORD_GRIP * _k
	var w := TAPE_W * _k
	var px := TAPE_L_PX if side < 0.0 else TAPE_R_PX
	var u_inner := (px.y if side < 0.0 else px.x) / TAPE_TEX_W
	var u_outer := (px.x if side < 0.0 else px.y) / TAPE_TEX_W
	# Keep the leather grain near its photo aspect instead of stretching the full height.
	var v_span := (_y_bot - _y_top) / w * (px.y - px.x) / 1024.0
	var v0 := 0.18 if side < 0.0 else 0.30
	var shade := Color(0.78, 0.78, 0.80)
	var stitch := PackedVector2Array()
	for i in ys.size() - 1:
		var ya := ys[i]
		var yb := ys[i + 1]
		var ia := Vector2(_cx + side * (inner_off + _spread(ya, mesh_y)), ya)
		var ib := Vector2(_cx + side * (inner_off + _spread(yb, mesh_y)), yb)
		var oa := ia + Vector2(side * w, 0.0)
		var ob := ib + Vector2(side * w, 0.0)
		var va := v0 + v_span * (ya - _y_top) / (_y_bot - _y_top)
		var vb := v0 + v_span * (yb - _y_top) / (_y_bot - _y_top)
		var pts := PackedVector2Array([ia, oa, ob, ib])
		var cols := PackedColorArray([Color.WHITE, shade, shade, Color.WHITE])
		if _tape_tex:
			var uvs := PackedVector2Array([Vector2(u_inner, va), Vector2(u_outer, va), Vector2(u_outer, vb), Vector2(u_inner, vb)])
			draw_primitive(pts, cols, uvs, _tape_tex)
		else:
			draw_primitive(pts, PackedColorArray([DrawKit.CHAR, DrawKit.CHAR, DrawKit.CHAR, DrawKit.CHAR]), PackedVector2Array())
		if i == 0:
			stitch.append(ia.lerp(oa, 0.62))
		stitch.append(ib.lerp(ob, 0.62))
	draw_polyline(stitch, STITCH, 0.8 * _k, true)


func _draw_cord(side: float, ys: PackedFloat32Array, mesh_y: float) -> void:
	var inner := (_chain_half() - CORD_GRIP * _k - 1.0 * _k)
	var reach := (_chain_half() - TOOTH_LEN * 0.85 * _k)
	for i in ys.size() - 1:
		var ya := ys[i]
		var yb := ys[i + 1]
		var sa := _spread(ya, mesh_y)
		var sb := _spread(yb, mesh_y)
		var pts := PackedVector2Array([
			Vector2(_cx + side * (inner + sa), ya),
			Vector2(_cx + side * (reach + sa), ya),
			Vector2(_cx + side * (reach + sb), yb),
			Vector2(_cx + side * (inner + sb), yb),
		])
		draw_primitive(pts, PackedColorArray([CORD, CORD, CORD, CORD]), PackedVector2Array())


func _set_tooth_frame(side: float, y: float, mesh_y: float) -> void:
	var slope := _spread_slope(y, mesh_y)
	var root := Vector2(_root_x(side, y, mesh_y), y)
	draw_set_transform(root, atan2(side * slope, 1.0), Vector2(-side * _k, _k))


func _draw_teeth(mesh_y: float) -> void:
	var pitch := PITCH * _k
	var first := _first_tooth_y()
	var last := _last_tooth_y()
	var y := first
	while y <= last:
		_draw_tooth(-1.0, y, mesh_y)
		if y + pitch * 0.5 <= last:
			_draw_tooth(1.0, y + pitch * 0.5, mesh_y)
		y += pitch


func _draw_tooth(side: float, y: float, mesh_y: float) -> void:
	_set_tooth_frame(side, y, mesh_y)
	var h := TOOTH_H * 0.5
	draw_polygon(_tooth_poly, _tooth_cols)
	draw_polyline(_tooth_outline, BRASS_EDGE, 0.6, true)
	draw_line(Vector2(0.8, -h + 0.75), Vector2(TOOTH_LEN - 2.2, -h + 0.75), Color(1.0, 0.97, 0.82, 0.85), 0.6)
	draw_rect(Rect2(TOOTH_LEN - 4.4, -0.9, 2.6, 1.8), Color(0.36, 0.24, 0.08, 0.7))
	draw_line(Vector2(CORD_GRIP, -h), Vector2(CORD_GRIP, h), Color(0.30, 0.20, 0.07, 0.55), 0.6)


func _draw_top_stop(side: float, mesh_y: float) -> void:
	var y := _y_top + (END_MARGIN + STOP_TOP_H * 0.5) * _k
	_set_tooth_frame(side, y, mesh_y)
	var h := STOP_TOP_H * 0.5
	var x0 := -CORD_GRIP - 0.8
	var x1 := TOOTH_LEN * 0.6
	var pts := PackedVector2Array([
		Vector2(x0 + 0.8, -h), Vector2(x1 - 0.8, -h), Vector2(x1, -h + 0.8),
		Vector2(x1, h - 0.8), Vector2(x1 - 0.8, h), Vector2(x0 + 0.8, h), Vector2(x0, h - 0.8), Vector2(x0, -h + 0.8),
	])
	var cols := PackedColorArray([BRASS_HI, BRASS_HI, BRASS, BRASS_LO, BRASS_LO, BRASS_LO, BRASS_LO, BRASS])
	draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, BRASS_EDGE, 0.6, true)
	draw_line(Vector2(x0 + 1.0, -h + 0.7), Vector2(x1 - 1.0, -h + 0.7), Color(1.0, 0.97, 0.82, 0.8), 0.6)


func _draw_bottom_stop() -> void:
	var w := (_chain_half() + CORD_GRIP * _k + 3.0 * _k) * 2.0
	var h := STOP_BOTTOM_H * _k
	var top := _y_bot - (END_MARGIN + STOP_BOTTOM_H) * _k
	var r := Rect2(_cx - w * 0.5, top, w, h)
	var bevel := 1.4 * _k
	var pts := PackedVector2Array([
		r.position + Vector2(bevel, 0.0), Vector2(r.end.x - bevel, r.position.y), Vector2(r.end.x, r.position.y + bevel),
		Vector2(r.end.x, r.end.y - bevel), Vector2(r.end.x - bevel, r.end.y), Vector2(r.position.x + bevel, r.end.y),
		Vector2(r.position.x, r.end.y - bevel), r.position + Vector2(0.0, bevel),
	])
	draw_rect(Rect2(r.position + Vector2(1.5, 2.0) * _k, r.size), Color(0.0, 0.0, 0.0, 0.35))
	draw_polygon(pts, PackedColorArray([BRASS_HI, BRASS_HI, BRASS, BRASS_LO, BRASS_LO, BRASS_LO, BRASS_LO, BRASS]))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, BRASS_EDGE, 0.8 * _k, true)
	draw_line(r.position + Vector2(bevel + _k, 1.0 * _k), Vector2(r.end.x - bevel - _k, r.position.y + 1.0 * _k), Color(1.0, 0.97, 0.82, 0.85), 0.7 * _k)
	draw_line(Vector2(r.position.x + 2.0 * _k, r.get_center().y + 0.6 * _k), Vector2(r.end.x - 2.0 * _k, r.get_center().y + 0.6 * _k), Color(0.36, 0.24, 0.08, 0.6), 0.7 * _k)


func _pull_rect(mesh_y: float) -> Rect2:
	var s := _pull_scale
	return Rect2(Vector2(_cx - PULL_CX * s, mesh_y - PULL_MESH * s), Vector2(PULL_PX * s, PULL_PX * s))


func _draw_slider(mesh_y: float) -> void:
	if _pull_tex == null:
		return
	var r := _pull_rect(mesh_y)
	draw_texture_rect(_pull_tex, Rect2(r.position + Vector2(1.6, 2.6) * _k, r.size), false, Color(0.0, 0.0, 0.0, 0.5))
	draw_texture_rect(_pull_tex, r, false)


func _units_per_dp() -> float:
	var win_h := float(DisplayServer.window_get_size().y)
	var vis_h := get_viewport_rect().size.y
	var dpi := float(DisplayServer.screen_get_dpi())
	if win_h < 1.0 or vis_h < 1.0 or dpi < 1.0:
		return 1.0
	var dp_per_unit := (win_h / vis_h) * (160.0 / dpi)
	return clampf(1.0 / dp_per_unit, 0.75, 2.0)


func _slider_hit_rect() -> Rect2:
	var s := _pull_scale
	var mesh_y := _mesh_y()
	var r := Rect2(
		Vector2(_cx + (PULL_LEFT - PULL_CX) * s, mesh_y + (PULL_TOP - PULL_MESH) * s),
		Vector2((PULL_RIGHT - PULL_LEFT) * s, (PULL_BOTTOM - PULL_TOP) * s))
	var min_side := maxf(HIT_MIN_UNITS, HIT_MIN_DP * _units_per_dp())
	var gx := maxf(0.0, (min_side - r.size.x) * 0.5) + 4.0
	var gy := maxf(0.0, (min_side - r.size.y) * 0.5) + 4.0
	return r.grow_individual(gx, gy, gx, gy)


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			if _slider_hit_rect().has_point(button.position):
				var mesh_y := _mesh_y()
				_dragging = true
				_grab_dy = button.position.y - mesh_y
				_last_tooth = _tooth_at(mesh_y)
				_anchor_y = mesh_y
				_anchor_ms = Time.get_ticks_msec()
				accept_event()
		else:
			_end_drag()


func _input(event: InputEvent) -> void:
	if not _active or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0 and not event.pressed:
		_end_drag()
	elif event is InputEventMouseMotion:
		_drag_to((make_input_local(event) as InputEventMouseMotion).position.y)
		accept_event()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		# Absolute position, so the mouse-emulated copy of this touch lands on the same spot.
		_drag_to((make_input_local(event) as InputEventScreenDrag).position.y)
		accept_event()


func _drag_to(finger_y: float) -> void:
	var mesh_y := clampf(finger_y - _grab_dy, _mesh_min, _mesh_max)
	var next := (mesh_y - _mesh_min) / maxf(1.0, _mesh_max - _mesh_min)
	if is_equal_approx(next, _open):
		return
	_open = next
	var tooth := _tooth_at(mesh_y)
	if tooth != _last_tooth:
		_last_tooth = tooth
		Haptics.selection()
	queue_redraw()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	var now := Time.get_ticks_msec()
	var mesh_y := _mesh_y()
	var moved := mesh_y - _anchor_y
	if absf(moved) >= MOVE_EPS * _k:
		var dt := clampf(float(now - _anchor_ms) / 1000.0, 1.0 / 120.0, 0.12)
		_speed = lerpf(_speed, absf(moved) / dt, 0.4)
		_anchor_y = mesh_y
		_anchor_ms = now
		_last_move_ms = now
		var t := clampf(_speed / (SPEED_FULL * _k), 0.0, 1.0)
		AudioFeel.play_zip(moved < 0.0, lerpf(0.94, 1.08, t), lerpf(0.30, 0.58, t))
	elif now - _last_move_ms > AudioFeel.held_quiet_msec():
		_speed = 0.0
		_anchor_ms = now
		AudioFeel.stop_zip()
