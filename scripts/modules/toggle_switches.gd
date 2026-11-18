extends FidgetModule
## Plate and screws never move. Only the rocker texture swaps in place.
## Each switch lights its own bulb in a row along the top of the toy.

const SWITCH_COUNT := 4
const HOUSING_TEX := preload("res://assets/modules/switch_housing.png")
const PADDLE_OFF := preload("res://assets/modules/switch_paddle_off.png")
const PADDLE_ON := preload("res://assets/modules/switch_paddle_on.png")
const BULB_OFF := preload("res://assets/modules/bulb_off.png")
const BULB_ON := preload("res://assets/modules/bulb_on.png")

const SWITCH_GAP := 22.0
const SIDE_PAD := 10.0
const MIN_PLATE_H := 72.0

# Bulbs hang base-up from the top edge, like a ceiling fixture.
const BULBS_HANG := true
const BULB_TOP_PAD := 10.0
const BULB_PITCH_FILL := 0.62
const BULB_MAX_W := 84.0
const BULB_MIN_DP := 44.0
const BULB_ON_FADE_SEC := 0.12
const BULB_OFF_FADE_SEC := 0.15
# Centre of the glass as a fraction of the image height, measured from the glass tip.
const BULB_GLASS_CY := 0.32
const GLOW_RADIUS := 0.95
const GLOW_GAP := 8.0
const GLOW_TEX_SIZE := 256
const FLICKER_DEPTH := 0.03

var _springs: Array[Spring2D] = []
var _states: Array[bool] = []
var _housings: Array[Sprite2D] = []
var _paddles: Array[Sprite2D] = []
var _paddle_sc: float = 1.0

var _bulbs_off: Array[Sprite2D] = []
var _bulbs_on: Array[Sprite2D] = []
var _glows: Array[Sprite2D] = []
var _lit: Array[float] = []
var _flicker_phase: Array[float] = []
var _glow_r: Array[float] = []
var _clock: float = 0.0

var _slots: Array[Rect2] = []
var _bulb_w: float = 0.0
var _bulb_h: float = 0.0
var _a11y_ids: Array[RID] = []


func _ready() -> void:
	module_id = "toggle_switches"
	display_name = "Toggle Switches"
	is_premium = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glow_tex := _make_glow_texture()
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in SWITCH_COUNT:
		var spring := Spring2D.new()
		spring.stiffness = 720.0
		spring.damping = 22.0
		_springs.append(spring)
		_states.append(false)
		_slots.append(Rect2())
		_a11y_ids.append(RID())
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.material = glow_mat
		glow.centered = true
		glow.modulate = Color(1, 1, 1, 0)
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(glow)
		_glows.append(glow)
		_glow_r.append(0.0)
		var off := _bulb_sprite(BULB_OFF)
		add_child(off)
		_bulbs_off.append(off)
		var on := _bulb_sprite(BULB_ON)
		on.modulate = Color(1, 1, 1, 0)
		add_child(on)
		_bulbs_on.append(on)
		_lit.append(0.0)
		_flicker_phase.append(float(i) * 2.399)
		var housing := Sprite2D.new()
		Chroma.apply(housing, HOUSING_TEX)
		housing.centered = true
		housing.z_index = 0
		housing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(housing)
		_housings.append(housing)
		var paddle := Sprite2D.new()
		Chroma.apply(paddle, PADDLE_OFF)
		paddle.centered = true
		paddle.z_index = 1
		paddle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(paddle)
		_paddles.append(paddle)
	resized.connect(_layout)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		for i in _a11y_ids.size():
			_a11y_ids[i] = RID()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		_update_accessibility()


func _update_accessibility() -> void:
	var ae := get_accessibility_element()
	if not ae.is_valid():
		return
	DisplayServer.accessibility_update_set_role(ae, DisplayServer.ROLE_CONTAINER)
	DisplayServer.accessibility_update_set_name(ae, display_name)
	for i in SWITCH_COUNT:
		if not _a11y_ids[i].is_valid():
			_a11y_ids[i] = DisplayServer.accessibility_create_sub_element(ae, DisplayServer.ROLE_CHECK_BUTTON, -1)
		var id := _a11y_ids[i]
		DisplayServer.accessibility_update_set_name(id, switch_label(i))
		DisplayServer.accessibility_update_set_value(id, light_text(i))
		DisplayServer.accessibility_update_set_checked(id, _states[i])
		DisplayServer.accessibility_update_set_bounds(id, _slots[i])
		DisplayServer.accessibility_update_add_action(id, DisplayServer.ACTION_CLICK, _a11y_toggle.bind(i))


func switch_label(index: int) -> String:
	return "Switch %d" % (index + 1)


## Spoken value: the switch's own light.
func light_text(index: int) -> String:
	return "light on" if _states[index] else "light off"


func _a11y_toggle(_data: Variant, index: int) -> void:
	if _active:
		_springs[index].target = 0.0 if _springs[index].target > 0.5 else 1.0


func _bulb_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.flip_v = BULBS_HANG
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _make_glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.55, 0.75, 0.9, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.32),
		Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = GLOW_TEX_SIZE
	tex.height = GLOW_TEX_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0 or HOUSING_TEX == null:
		return
	_compute_geometry()
	for i in SWITCH_COUNT:
		var r := _slot_rect(i)
		var center := r.get_center()
		var hsc := minf(r.size.x / float(HOUSING_TEX.get_width()), r.size.y / float(HOUSING_TEX.get_height()))
		_housings[i].scale = Vector2(hsc, hsc)
		_housings[i].position = center
		_housings[i].rotation = 0.0
		_housings[i].flip_v = false
		_housings[i].flip_h = false
		var recess_h := (HOUSING_TEX.get_height() * hsc) * 0.56
		_paddle_sc = recess_h / float(PADDLE_OFF.get_height())
		_paddles[i].position = center
		_paddles[i].rotation = 0.0
		_paddles[i].flip_v = false
		_paddles[i].flip_h = false
		_apply_rocker(i)
		_place_bulb(i)
		_apply_bulb(i)
	queue_accessibility_update()


func _compute_geometry() -> void:
	var avail_w := maxf(40.0, size.x - SIDE_PAD * 2.0)
	var aspect := float(HOUSING_TEX.get_width()) / float(HOUSING_TEX.get_height())
	var bulb_aspect := float(BULB_OFF.get_height()) / float(BULB_OFF.get_width())
	var plate_h := minf(200.0, size.y * 0.76)
	var plate_w := plate_h * aspect
	var gaps := (SWITCH_COUNT - 1) * SWITCH_GAP
	if SWITCH_COUNT * plate_w + gaps > avail_w:
		var s := maxf(1.0, avail_w - gaps) / (SWITCH_COUNT * plate_w)
		plate_w *= s
		plate_h *= s
	var clear_y := 0.0
	for pass_i in 3:
		var pitch := plate_w + SWITCH_GAP
		_bulb_w = maxf(BULB_MIN_DP * _units_per_dp(), minf(pitch * BULB_PITCH_FILL, BULB_MAX_W))
		_bulb_h = _bulb_w * bulb_aspect
		var glow_bottom := BULB_TOP_PAD + _glass_offset() + _bulb_w * GLOW_RADIUS
		clear_y = maxf(glow_bottom, BULB_TOP_PAD + _bulb_h) + GLOW_GAP
		var room := size.y - SIDE_PAD - clear_y
		if plate_h <= room:
			break
		plate_h = maxf(MIN_PLATE_H, room)
		plate_w = plate_h * aspect
	var total_w := SWITCH_COUNT * plate_w + (SWITCH_COUNT - 1) * SWITCH_GAP
	var origin := ReachSettings.cluster_origin(size, Vector2(total_w, plate_h))
	origin.y = maxf(origin.y, clear_y)
	for i in SWITCH_COUNT:
		_slots[i] = Rect2(origin.x + i * (plate_w + SWITCH_GAP), origin.y, plate_w, plate_h)


func _glass_offset() -> float:
	return _bulb_h * ((1.0 - BULB_GLASS_CY) if BULBS_HANG else BULB_GLASS_CY)


func _units_per_dp() -> float:
	var win_h := float(DisplayServer.window_get_size().y)
	var vis_h := get_viewport_rect().size.y
	var dpi := float(DisplayServer.screen_get_dpi())
	if win_h < 1.0 or vis_h < 1.0 or dpi < 1.0:
		return 1.0
	var dp_per_unit := (win_h / vis_h) * (160.0 / dpi)
	return clampf(1.0 / dp_per_unit, 0.75, 2.0)


func _place_bulb(index: int) -> void:
	var cx := _slot_rect(index).get_center().x
	var sc := _bulb_w / float(BULB_OFF.get_width())
	var pos := Vector2(cx, BULB_TOP_PAD + _bulb_h * 0.5)
	for s in [_bulbs_off[index], _bulbs_on[index]]:
		(s as Sprite2D).scale = Vector2(sc, sc)
		(s as Sprite2D).position = pos
	var glass := Vector2(cx, BULB_TOP_PAD + _glass_offset())
	# Keep the glow inside the toy so it never spills past the stage edges.
	var r := minf(_bulb_w * GLOW_RADIUS, minf(minf(cx, size.x - cx), glass.y))
	_glow_r[index] = r
	_glows[index].position = glass
	_glows[index].scale = Vector2.ONE * (2.0 * r / float(GLOW_TEX_SIZE))


func _process(delta: float) -> void:
	if not _active:
		return
	_clock += delta
	for i in SWITCH_COUNT:
		if AppSettings.reduce_motion():
			if not is_equal_approx(_springs[i].position, _springs[i].target):
				_springs[i].snap_to(_springs[i].target)
		else:
			_springs[i].step(delta)
		_apply_rocker(i)
		var t := _springs[i].position
		var was_on := _states[i]
		var is_on := t > 0.82
		if is_on and not was_on:
			_states[i] = true
			Haptics.heavy()
			AudioFeel.play_switch()
			UnlockNudge.note_switch()
			queue_accessibility_update()
		elif (not is_on) and was_on and t < 0.18:
			_states[i] = false
			Haptics.medium()
			AudioFeel.play_switch()
			UnlockNudge.note_switch()
			queue_accessibility_update()
		_step_bulb(i, delta)
		_apply_bulb(i)


func _step_bulb(index: int, delta: float) -> void:
	if _states[index]:
		_lit[index] = minf(1.0, _lit[index] + delta / BULB_ON_FADE_SEC)
	else:
		_lit[index] = maxf(0.0, _lit[index] - delta / BULB_OFF_FADE_SEC)


func _flicker(index: int) -> float:
	if AppSettings.reduce_motion():
		return 1.0
	var p := _flicker_phase[index]
	var n := 0.6 * sin(_clock * 13.1 + p) + 0.4 * sin(_clock * 29.7 + p * 1.7)
	return 1.0 - FLICKER_DEPTH * (0.5 + 0.5 * n)


func _apply_bulb(index: int) -> void:
	var lit := _lit[index]
	var f := _flicker(index) if lit > 0.0 else 1.0
	_bulbs_off[index].modulate = Color(1, 1, 1, 1.0 - lit)
	_bulbs_on[index].modulate = Color(f, f, f, lit)
	_glows[index].modulate = Color(1, 1, 1, lit * f)
	_glows[index].visible = lit > 0.0


func _apply_rocker(index: int) -> void:
	var t := clampf(_springs[index].position, 0.0, 1.0)
	var center := _slot_rect(index).get_center()
	var housing := _housings[index]
	housing.position = center
	housing.rotation = 0.0
	housing.flip_v = false
	housing.flip_h = false
	var paddle := _paddles[index]
	paddle.position = center
	paddle.rotation = 0.0
	paddle.scale = Vector2(_paddle_sc, _paddle_sc)
	paddle.flip_v = false
	paddle.flip_h = false
	paddle.texture = Chroma.tex(PADDLE_ON) if t > 0.5 else Chroma.tex(PADDLE_OFF)


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in SWITCH_COUNT:
			if _slot_rect(i).grow(10.0).has_point(event.position):
				_springs[i].target = 0.0 if _springs[i].target > 0.5 else 1.0
				accept_event()
				break


func _slot_rect(index: int) -> Rect2:
	return _slots[index]
