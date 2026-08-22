extends FidgetModule
## Clicker pen. Push the top in and the writing tip comes out; click again to reverse.

const BODY_TEX := preload("res://assets/modules/pen_body.png")
const TIP_TEX := preload("res://assets/modules/pen_tip.png")
const CLICK_PATH := "res://assets/modules/pen_clicker.png"
const CUT := 0.048
## Hide only the silver writing point; keep the gold cone on the body.
const CUT_BOT := 0.058
const TIP_CUT := 0.536
const CLICK_W := 248.0
const CLICK_H := 300.0

var _click: Spring2D
var _latched: bool = false
var _body: Sprite2D
var _clicker: Sprite2D
var _tip: Sprite2D


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
	_tip = Sprite2D.new()
	Chroma.apply(_tip, TIP_TEX, TIP_CUT)
	_tip.centered = true
	_tip.z_index = 0
	add_child(_tip)
	_body = Sprite2D.new()
	Chroma.apply(_body, BODY_TEX, CUT, 0, CUT_BOT)
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
	if _tip and TIP_TEX:
		var tip_sc: float = sc * (38.0 / 34.0)
		_tip.scale = Vector2(tip_sc, tip_sc)
		_tip.rotation = 0.0
	_place_ends()


func _collar_y() -> float:
	var h: float = float(BODY_TEX.get_height()) * _body.scale.y
	return _body.position.y - h * 0.5 + h * CUT


func _cut_bot_y() -> float:
	var h: float = float(BODY_TEX.get_height()) * _body.scale.y
	return _body.position.y - h * 0.5 + h * (1.0 - CUT_BOT)


func _place_ends() -> void:
	var vis_h: float = CLICK_H * _clicker.scale.y
	var stub: float = lerpf(20.0, 7.0, _click.position)
	_clicker.position = Vector2(_body.position.x, _collar_y() - stub + vis_h * 0.5)
	_clicker.rotation = 0.0
	if _tip == null or TIP_TEX == null:
		return
	var tip_h: float = float(TIP_TEX.get_height()) * _tip.scale.y
	# Texture stays centered; silver starts at TIP_CUT, so line that up with the gold cone.
	var out_y: float = _cut_bot_y() + tip_h * (0.5 - TIP_CUT) + 3.0 * _tip.scale.y
	var silver_h: float = tip_h * (1.0 - TIP_CUT)
	var in_y: float = out_y - silver_h * 0.92
	_tip.position = Vector2(_body.position.x, lerpf(in_y, out_y, _click.position))
	_tip.visible = true


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
	_place_ends()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed and _pen_hit(button.position):
			_latched = not _latched
			_click.target = 1.0 if _latched else 0.0
			Haptics.heavy()
			AudioFeel.play_pen_click(_latched)
			accept_event()
