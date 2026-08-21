extends FidgetModule
## Clicker pen. Short silver plunger seats with a stub; click again to pop out.

const BODY_TEX := preload("res://assets/modules/pen_body.png")
const CLICK_PATH := "res://assets/modules/pen_clicker.png"
const CUT := 0.048
const CLICK_W := 248.0
const CLICK_H := 300.0

var _click: Spring2D
var _latched: bool = false
var _body: Sprite2D
var _clicker: Sprite2D


func _ready() -> void:
	module_id = "clicker_pen"
	display_name = "Clicker Pen"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_click = Spring2D.new()
	_click.stiffness = 980.0
	_click.damping = 28.0
	_clicker = Sprite2D.new()
	var click_tex: Texture2D = load(CLICK_PATH) as Texture2D
	if click_tex == null:
		var img := Image.new()
		if img.load(CLICK_PATH) == OK:
			click_tex = ImageTexture.create_from_image(img)
	Chroma.apply(_clicker, click_tex)
	_clicker.centered = true
	_clicker.z_index = 0
	add_child(_clicker)
	_body = Sprite2D.new()
	Chroma.apply(_body, BODY_TEX, CUT)
	_body.centered = true
	_body.z_index = 1
	add_child(_body)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if size.y < 8.0 or BODY_TEX == null:
		return
	var c := ReachSettings.play_center(size)
	var target_h := minf(size.y * 0.78, 420.0)
	var sc := target_h / float(BODY_TEX.get_height())
	_body.scale = Vector2(sc, sc)
	_body.position = c
	_body.rotation = 0.0
	var barrel_w: float = float(BODY_TEX.get_width()) * sc * (125.0 / 1024.0)
	var click_sc: float = (barrel_w * 0.82) / CLICK_W
	_clicker.scale = Vector2(click_sc, click_sc * 0.46)
	_clicker.rotation = 0.0
	_clicker.offset = Vector2.ZERO
	_place_clicker()


func _collar_y() -> float:
	var h: float = float(BODY_TEX.get_height()) * _body.scale.y
	return _body.position.y - h * 0.5 + h * CUT


func _place_clicker() -> void:
	var vis_h: float = CLICK_H * _clicker.scale.y
	var stub: float = lerpf(20.0, 7.0, _click.position)
	_clicker.position = Vector2(_body.position.x, _collar_y() - stub + vis_h * 0.5)
	_clicker.rotation = 0.0


func _pen_hit(pos: Vector2) -> bool:
	var h: float = float(BODY_TEX.get_height()) * _body.scale.y
	var w: float = float(BODY_TEX.get_width()) * _body.scale.x * 0.22
	var body := Rect2(_body.position - Vector2(w, h) * 0.5, Vector2(w, h)).grow(18.0)
	if body.has_point(pos):
		return true
	var vis_h: float = CLICK_H * _clicker.scale.y
	var cw: float = CLICK_W * _clicker.scale.x
	var top := Rect2(Vector2(_body.position.x - cw, _collar_y() - vis_h), Vector2(cw * 2.0, vis_h + 24.0))
	return top.has_point(pos)


func _process(delta: float) -> void:
	if not _active:
		return
	_click.step(delta)
	_click.target = 1.0 if _latched else 0.0
	_place_clicker()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed and _pen_hit(button.position):
			_latched = not _latched
			_click.target = 1.0 if _latched else 0.0
			Haptics.heavy()
			AudioFeel.play_thud()
			accept_event()
