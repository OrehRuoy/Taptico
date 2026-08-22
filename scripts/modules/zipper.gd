extends FidgetModule
## Closed zipper on top of an open zipper. Drag the puller; teeth mesh or separate.

const TEETH := 32
const CLOSED_PATH := "res://assets/modules/zipper_placket.png"
const OPEN_PATH := "res://assets/modules/zipper_open.png"
const PULL_TEX := preload("res://assets/modules/zipper_pull.png")
const UNZIP := preload("res://shaders/unzip.gdshader")
const DRAG_GEAR := 2.8

var _open: float = 0.0
var _dragging: bool = false
var _last_tooth: int = -1
var _drag_y0: float = 0.0
var _open0: float = 0.0
var _closed: Sprite2D
var _opened: Sprite2D
var _pull: Sprite2D
var _unzip_mat: ShaderMaterial
var _closed_tex: Texture2D
var _open_tex: Texture2D


func _ready() -> void:
	module_id = "zipper"
	display_name = "Zipper"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_closed_tex = Chroma.tex(_load_png(CLOSED_PATH))
	_open_tex = Chroma.tex(_load_png(OPEN_PATH))
	_unzip_mat = ShaderMaterial.new()
	_unzip_mat.shader = UNZIP
	_opened = Sprite2D.new()
	_opened.texture = _open_tex if _open_tex else _closed_tex
	_opened.material = null
	_opened.centered = true
	_opened.z_index = 0
	_opened.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_opened)
	_closed = Sprite2D.new()
	_closed.texture = _closed_tex
	_closed.material = _unzip_mat
	_closed.centered = true
	_closed.z_index = 1
	_closed.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_closed)
	_pull = Sprite2D.new()
	Chroma.apply(_pull, PULL_TEX)
	_pull.centered = true
	_pull.offset = Vector2(0.0, 292.0)
	_pull.z_index = 2
	_pull.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_pull)
	resized.connect(_layout)
	_layout()


func _load_png(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	if size.y < 8.0 or _closed_tex == null:
		return
	var c := ReachSettings.play_center(size)
	var target_h := minf(size.y * 0.50, 280.0)
	var sc := target_h / float(_closed_tex.get_height())
	_closed.scale = Vector2(sc, sc)
	_closed.position = c
	_opened.scale = Vector2(sc, sc)
	_opened.position = c
	var tape_w: float = float(_closed_tex.get_width()) * sc * 0.349
	_pull.scale = Vector2.ONE * (tape_w * 0.72 / 221.0)
	_place_pull()


func _y_range() -> Vector2:
	var h: float = float(_closed_tex.get_height()) * _closed.scale.y
	return Vector2(_closed.position.y - h * 0.49, _closed.position.y + h * 0.47)


func _handle_y() -> float:
	return _pull.position.y + _pull.offset.y * _pull.scale.y


func _place_pull() -> void:
	var yr := _y_range()
	_pull.position = Vector2(_closed.position.x, lerpf(yr.x, yr.y, _open))
	_unzip_mat.set_shader_parameter("split_uv_y", lerpf(0.0, 0.98, _open))


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			if _hit_pull(button.position) or _hit_teeth(button.position):
				_dragging = true
				_drag_y0 = button.position.y
				_open0 = _open
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
		_set_from_drag(local_ev.position.y)
		accept_event()


func _set_from_drag(y: float) -> void:
	var yr := _y_range()
	var span: float = maxf(64.0, (yr.y - yr.x) * DRAG_GEAR)
	_open = clampf(_open0 + (y - _drag_y0) / span, 0.0, 1.0)
	var tooth := int(round(_open * float(TEETH)))
	if tooth != _last_tooth:
		_last_tooth = tooth
		Haptics.selection()
		AudioFeel.play_tick(lerpf(0.85, 1.2, _open))
	_place_pull()


func _hit_pull(pos: Vector2) -> bool:
	var sc: float = _pull.scale.x
	if sc < 0.001:
		return false
	var local: Vector2 = (pos - _pull.position) / sc - _pull.offset
	var px: float = local.x + 512.0
	var py: float = local.y + 512.0
	return px >= 390.0 and px <= 640.0 and py >= 170.0 and py <= 850.0


func _hit_teeth(pos: Vector2) -> bool:
	var w: float = float(_closed_tex.get_width()) * _closed.scale.x * 0.11
	var h: float = float(_closed_tex.get_height()) * _closed.scale.y
	return Rect2(_closed.position - Vector2(w, h) * 0.5, Vector2(w, h)).has_point(pos)
