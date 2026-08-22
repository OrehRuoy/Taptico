extends FidgetModule
## Four-face desk cube: joystick, gear, worry stone, clicker dots.

enum Face { JOYSTICK, GEAR, WORRY, DOTS }

const TEX_JOY := preload("res://assets/modules/cube_joy.png")
const TEX_GEAR := preload("res://assets/modules/cube_gear.png")
const TEX_WORRY := preload("res://assets/modules/cube_worry.png")
const TEX_DOTS := preload("res://assets/modules/cube_dots.png")
const NUB_TEX := preload("res://assets/modules/cube_nub.png")
const STEM_TEX := preload("res://assets/modules/cube_stick.png")
const BTN_TEX := preload("res://assets/modules/cube_dot_btn.png")
const DIAL_PATH := "res://assets/modules/cube_gear_dial.png"
const WELL_R := 0.225
const NUB_IN_WELL := 0.36
const NUB_VIS := 0.84
const NUB_THROW := 0.56
const STEM_H := 784.0

var _face: int = Face.JOYSTICK
var _joy := Vector2.ZERO
var _joy_target := Vector2.ZERO
var _gear: float = 0.0
var _gear_detent: int = 0
var _worry_heat: float = 0.0
var _dots: Array[bool] = [false, false, false, false]
var _drag: String = ""
var _last := Vector2.ZERO
var _last_worry_ms: int = 0
var _rub_pos := Vector2.ZERO
var _rub_glow: float = 0.0
var _joy_rim: bool = false
var _cube: Sprite2D
var _nub: Sprite2D
var _stem: Sprite2D
var _dial: Sprite2D
var _btns: Array[Sprite2D] = []
var _dial_tex: Texture2D
var _btn_sc: float = 1.0


func _ready() -> void:
	module_id = "desk_cube"
	display_name = "Desk Cube"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cube = Sprite2D.new()
	Chroma.apply(_cube, TEX_JOY)
	_cube.centered = true
	add_child(_cube)
	_nub = Sprite2D.new()
	Chroma.apply(_nub, NUB_TEX)
	_nub.centered = true
	_nub.z_index = 6
	add_child(_nub)
	_stem = Sprite2D.new()
	Chroma.apply(_stem, STEM_TEX)
	_stem.centered = true
	_stem.z_index = 5
	_stem.visible = false
	add_child(_stem)
	_dial_tex = Chroma.tex(load(DIAL_PATH) as Texture2D)
	_dial = Sprite2D.new()
	_dial.texture = _dial_tex
	_dial.material = null
	_dial.centered = true
	_dial.z_index = 3
	_dial.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_dial)
	for i in 4:
		var b := Sprite2D.new()
		Chroma.apply(b, BTN_TEX)
		b.centered = true
		b.z_index = 5
		add_child(b)
		_btns.append(b)
	_cube.show_behind_parent = true
	_dial.show_behind_parent = true
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if size.x < 8.0 or _cube.texture == null:
		return
	var c := ReachSettings.play_center(size) + Vector2(0, -18.0)
	var target := minf(size.x, size.y) * 0.62
	var sc := target / float(_cube.texture.get_width())
	_cube.scale = Vector2(sc, sc)
	_cube.position = c
	var well: float = _well_r()
	var nub_d: float = well * NUB_IN_WELL * 2.0
	_nub.scale = Vector2.ONE * (nub_d / (float(NUB_TEX.get_width()) * NUB_VIS))
	if _dial_tex:
		var dial_d: float = _cube_size() * 0.61
		_dial.scale = Vector2.ONE * (dial_d / float(_dial_tex.get_width()))
		_dial.position = c
	_btn_sc = (_cube_size() * 0.205) / (float(BTN_TEX.get_width()) * 0.72)
	_apply_face()


func _cube_size() -> float:
	return float(_cube.texture.get_width()) * _cube.scale.x


func _well_r() -> float:
	return _cube_size() * WELL_R


func _nub_r() -> float:
	return _well_r() * NUB_IN_WELL


func _max_nub() -> float:
	return maxf(8.0, _well_r() * NUB_THROW)


func _cube_rect() -> Rect2:
	var s := _cube_size()
	return Rect2(_cube.position - Vector2(s, s) * 0.5, Vector2(s, s))


func _process(delta: float) -> void:
	if not _active:
		return
	if _drag != "joy":
		_joy_target = Vector2.ZERO
	_joy = _joy.lerp(_joy_target, 1.0 - exp(-18.0 * delta))
	_worry_heat = maxf(0.0, _worry_heat - delta * 0.55)
	_rub_glow = maxf(0.0, _rub_glow - delta * 1.8)
	_nub.visible = _face == Face.JOYSTICK
	if _stem:
		_stem.visible = false
	if _face == Face.JOYSTICK:
		var mag := _joy.length()
		var throw_v: Vector2 = _joy * _max_nub()
		_nub.position = _cube.position + throw_v
		var base_sc: float = (_well_r() * NUB_IN_WELL * 2.0) / (float(NUB_TEX.get_width()) * NUB_VIS)
		_nub.rotation = 0.0
		_nub.scale = Vector2.ONE * (base_sc * lerpf(1.0, 0.94, mag))
		_nub.modulate = Color.WHITE.lerp(Color(0.84, 0.74, 0.52), mag * 0.22)
		if mag > 0.06 and _stem:
			var dir: Vector2 = _joy.normalized()
			var cap_at: Vector2 = _cube.position + throw_v
			var stem_a: Vector2 = _cube.position + dir * (_well_r() * 0.05)
			var stem_b: Vector2 = cap_at - dir * (_nub_r() * 0.58)
			var stem_len: float = stem_a.distance_to(stem_b)
			if stem_len > 4.0:
				_stem.visible = true
				_stem.position = stem_a.lerp(stem_b, 0.5)
				_stem.rotation = dir.angle() + PI * 0.5
				_stem.scale = Vector2.ONE * (stem_len / STEM_H)
		var at_rim := mag > 0.92
		if at_rim and not _joy_rim and _drag == "joy":
			Haptics.selection()
			AudioFeel.play_tick(1.05)
		_joy_rim = at_rim
	else:
		_nub.visible = false
		_nub.modulate = Color.WHITE
		_joy_rim = false
	if _dial:
		_dial.visible = _face == Face.GEAR
		_dial.position = _cube.position
		_dial.rotation = _gear
	var spots := _dot_spots()
	for i in _btns.size():
		var down: bool = _dots[i]
		_btns[i].visible = _face == Face.DOTS and down
		if not _btns[i].visible:
			continue
		_btns[i].position = spots[i] + Vector2(0.0, 5.0)
		_btns[i].scale = Vector2.ONE * (_btn_sc * 0.52)
		_btns[i].modulate = Color(0.50, 0.38, 0.18)
		_btns[i].z_index = 4
	_cube.modulate = Color.WHITE.lerp(Color(1.08, 0.95, 0.75), _worry_heat * 0.35 if _face == Face.WORRY else 0.0)
	queue_redraw()


func _apply_face() -> void:
	match _face:
		Face.GEAR:
			_cube.texture = Chroma.tex(TEX_GEAR)
		Face.WORRY:
			_cube.texture = Chroma.tex(TEX_WORRY)
		Face.DOTS:
			_cube.texture = Chroma.tex(TEX_DOTS)
		_:
			_cube.texture = Chroma.tex(TEX_JOY)
	_nub.visible = _face == Face.JOYSTICK
	if _stem and _face != Face.JOYSTICK:
		_stem.visible = false
	if _dial:
		_dial.visible = _face == Face.GEAR
	queue_redraw()


func _cycle_face(dir: int) -> void:
	_face = posmod(_face + dir, 4)
	Haptics.medium()
	AudioFeel.play_snap(0.9)
	_apply_face()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_last = button.position
			if _cube_rect().grow(-10.0).has_point(button.position):
				match _face:
					Face.JOYSTICK:
						_drag = "joy"
						_aim_joy(button.position)
					Face.GEAR:
						_drag = "gear"
					Face.WORRY:
						_drag = "worry"
						_rub(button.position)
					Face.DOTS:
						_press_dot(button.position)
			else:
				_drag = "flip"
			accept_event()
		else:
			_release_at(button.position)


func _input(event: InputEvent) -> void:
	if not _active or _drag == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var button := event as InputEventMouseButton
		_release_at(button.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		match _drag:
			"joy":
				_aim_joy(motion.position)
			"gear":
				var a0: float = (_last - _cube.position).angle()
				var a1: float = (motion.position - _cube.position).angle()
				var da: float = wrapf(a1 - a0, -PI, PI)
				_gear = wrapf(_gear + da, 0.0, TAU)
				_last = motion.position
				var d := int(floor(_gear / 0.35))
				if d != _gear_detent:
					_gear_detent = d
					Haptics.selection()
					AudioFeel.play_tick(randf_range(0.9, 1.1))
			"worry":
				_rub(motion.position)
			"flip":
				pass
		accept_event()


func _release_at(pos: Vector2) -> void:
	if _drag == "":
		return
	if _drag == "flip":
		var dx: float = pos.x - _last.x
		if absf(dx) > 36.0:
			_cycle_face(-1 if dx > 0.0 else 1)
	_drag = ""


func _aim_joy(pos: Vector2) -> void:
	var maxr := _max_nub()
	if maxr < 1.0:
		_joy_target = Vector2.ZERO
		return
	_joy_target = (pos - _cube.position).limit_length(maxr) / maxr


func _rub(pos: Vector2) -> void:
	var dist := pos.distance_to(_last)
	_last = pos
	_worry_heat = minf(1.0, _worry_heat + dist * 0.012)
	_rub_pos = pos
	_rub_glow = 1.0
	var now := Time.get_ticks_msec()
	if dist > 4.0 and now - _last_worry_ms > 40:
		_last_worry_ms = now
		Haptics.soft()
		AudioFeel.play_key_soft()


func _press_dot(pos: Vector2) -> void:
	var spots := _dot_spots()
	for i in spots.size():
		if pos.distance_to(spots[i]) < _cube_size() * 0.14:
			_dots[i] = not _dots[i]
			Haptics.medium()
			AudioFeel.play_key_click()
			break


func _dot_spots() -> Array[Vector2]:
	var c := _cube.position
	var s := _cube_size()
	var spots: Array[Vector2] = []
	spots.append(c + Vector2(-0.1484, -0.1536) * s)
	spots.append(c + Vector2(0.1506, -0.1532) * s)
	spots.append(c + Vector2(-0.1487, 0.1455) * s)
	spots.append(c + Vector2(0.1499, 0.1475) * s)
	return spots


func _draw() -> void:
	var cube := _cube_rect()
	if _face == Face.JOYSTICK:
		var mag := _joy.length()
		var well_c: Vector2 = _cube.position
		var well_r: float = _well_r()
		draw_circle(well_c + _joy * well_r * 0.10, well_r * 0.70, Color(0.03, 0.03, 0.04, 0.20 + mag * 0.18))
		if mag > 0.05:
			var cap_at: Vector2 = well_c + _joy * _max_nub()
			draw_circle(cap_at + Vector2(0.8, 1.4), _nub_r() * 0.92, Color(0.02, 0.02, 0.03, 0.16 + mag * 0.12))
	if _face == Face.DOTS:
		var spots := _dot_spots()
		var well_r: float = _cube_size() * 0.112
		for i in spots.size():
			if not _dots[i]:
				continue
			draw_circle(spots[i] + Vector2(0.0, 1.0), well_r, Color(0.05, 0.04, 0.03, 0.96))
			draw_circle(spots[i] + Vector2(0.0, 4.0), well_r * 0.78, Color(0.14, 0.10, 0.07, 0.9))
	if _face == Face.WORRY and _rub_glow > 0.02:
		draw_circle(_rub_pos, 26.0, Color(0.95, 0.82, 0.45, 0.22 * _rub_glow))
	var x0: float = cube.get_center().x - 27.0
	var y: float = cube.end.y + 18.0
	for i in 4:
		var on := i == _face
		draw_circle(Vector2(x0 + i * 18.0, y), 3.5, DrawKit.GOLD if on else DrawKit.GOLD_LO)
