extends FidgetModule
## Plate and screws never move. Only the rocker texture swaps in place.

const SWITCH_COUNT := 4
const HOUSING_TEX := preload("res://assets/modules/switch_housing.png")
const PADDLE_OFF := preload("res://assets/modules/switch_paddle_off.png")
const PADDLE_ON := preload("res://assets/modules/switch_paddle_on.png")

var _springs: Array[Spring2D] = []
var _states: Array[bool] = []
var _housings: Array[Sprite2D] = []
var _paddles: Array[Sprite2D] = []
var _paddle_sc: float = 1.0


func _ready() -> void:
	module_id = "toggle_switches"
	display_name = "Toggle Switches"
	is_premium = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in SWITCH_COUNT:
		var spring := Spring2D.new()
		spring.stiffness = 720.0
		spring.damping = 22.0
		_springs.append(spring)
		_states.append(false)
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


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0 or HOUSING_TEX == null:
		return
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


func _process(delta: float) -> void:
	if not _active:
		return
	for i in SWITCH_COUNT:
		_springs[i].step(delta)
		_apply_rocker(i)
		var t := _springs[i].position
		var was_on := _states[i]
		var is_on := t > 0.82
		if is_on and not was_on:
			Haptics.heavy()
			AudioFeel.play_thud()
			_states[i] = true
		elif (not is_on) and was_on and t < 0.18:
			Haptics.medium()
			AudioFeel.play_thud()
			_states[i] = false


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
	var gap := 22.0
	var side_pad := 10.0
	var avail_w := maxf(40.0, size.x - side_pad * 2.0)
	var aspect := float(HOUSING_TEX.get_width()) / float(HOUSING_TEX.get_height())
	var plate_h := minf(200.0, size.y * 0.76)
	var plate_w := plate_h * aspect
	var total := SWITCH_COUNT * plate_w + (SWITCH_COUNT - 1) * gap
	if total > avail_w:
		var s := avail_w / total
		plate_w *= s
		plate_h *= s
	var total_w := SWITCH_COUNT * plate_w + (SWITCH_COUNT - 1) * gap
	var origin := ReachSettings.cluster_origin(size, Vector2(total_w, plate_h))
	return Rect2(origin.x + index * (plate_w + gap), origin.y, plate_w, plate_h)
