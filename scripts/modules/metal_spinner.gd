extends FidgetModule
## Arms rotate around the bearing hole. The hub is punched out of the rotor so it cannot orbit.

const ARMS := 3
const SPINNER_PATH := "res://assets/modules/fidget_spinner.png"
const HUB_PATH := "res://assets/modules/spinner_hub.png"
const HUB_PX := Vector2(512.0, 548.0)

var _angle: float = 0.0
var _vel: float = 0.0
var _dragging: bool = false
var _last_pos := Vector2.ZERO
var _last_tick: int = 0
var _arm_pass: int = 0
var _pivot: Node2D
var _rotor: Sprite2D
var _hub: Sprite2D
var _tex: Texture2D
var _hub_tex: Texture2D


func _ready() -> void:
	module_id = "metal_spinner"
	display_name = "Metal Spinner"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = Chroma.punch(_load_png(SPINNER_PATH), HUB_PX, 131.0)
	_hub_tex = Chroma.tex(_load_png(HUB_PATH))
	_pivot = Node2D.new()
	add_child(_pivot)
	_rotor = Sprite2D.new()
	_rotor.texture = _tex
	_rotor.material = null
	_rotor.centered = true
	if _tex:
		_rotor.offset = Vector2(float(_tex.get_width()) * 0.5, float(_tex.get_height()) * 0.5) - HUB_PX
	else:
		_rotor.offset = Vector2(0.0, -36.0)
	_rotor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pivot.add_child(_rotor)
	if _hub_tex:
		_hub = Sprite2D.new()
		_hub.texture = _hub_tex
		_hub.material = null
		_hub.centered = true
		_hub.z_index = 2
		_hub.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_hub)
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
	if size.x < 8.0 or _tex == null:
		return
	var c := ReachSettings.play_center(size)
	var target := minf(size.x, size.y) * 0.78
	var sc := target / float(_tex.get_width())
	_pivot.position = c
	_rotor.position = Vector2.ZERO
	_rotor.scale = Vector2(sc, sc)
	_pivot.rotation = _angle
	if _hub and _hub_tex:
		_hub.position = c
		var hub_d: float = float(_tex.get_width()) * sc * 0.262
		_hub.scale = Vector2.ONE * (hub_d / float(_hub_tex.get_width()))


func _center() -> Vector2:
	return _pivot.position


func _radius() -> float:
	if _tex == null:
		return 80.0
	return float(_tex.get_width()) * _rotor.scale.x * 0.46


func _hub_radius() -> float:
	if _hub == null or _hub_tex == null:
		return 22.0
	return float(_hub_tex.get_width()) * _hub.scale.x * 0.42


func _process(delta: float) -> void:
	if not _active:
		return
	on_tilt(Input.get_accelerometer(), Input.get_gyroscope())
	if not _dragging:
		_vel *= exp(-0.16 * delta)
		if absf(_vel) < 0.04:
			_vel = 0.0
		_angle = wrapf(_angle + _vel * delta, 0.0, TAU)
		_tick_arms()
	_pivot.rotation = _angle
	if _hub:
		_hub.rotation = 0.0
		_hub.position = _pivot.position


func on_tilt(_accel: Vector3, gyro: Vector3) -> void:
	if _dragging:
		return
	_vel += gyro.z * (0.85 * AppSettings.shake_strength)
	_vel = clampf(_vel, -48.0, 48.0)


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		var d: float = button.position.distance_to(_center())
		if button.pressed and d < _radius() * 1.15 and d > _hub_radius() * 0.85:
			_dragging = true
			_last_pos = button.position
			accept_event()
		else:
			_dragging = false


func _input(event: InputEvent) -> void:
	if not _active or not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var c: Vector2 = _center()
		var a0: float = (_last_pos - c).angle()
		var a1: float = (motion.position - c).angle()
		var da: float = wrapf(a1 - a0, -PI, PI)
		_angle = wrapf(_angle + da, 0.0, TAU)
		_vel = clampf(_vel * 0.25 + da * 96.0, -48.0, 48.0)
		_last_pos = motion.position
		_tick_arms()
		_pivot.rotation = _angle
		accept_event()


func _tick_arms() -> void:
	var sector := int(floor(_angle / (TAU / float(ARMS))))
	if sector == _arm_pass:
		return
	_arm_pass = sector
	var now := Time.get_ticks_msec()
	if now - _last_tick < 22:
		return
	_last_tick = now
	var speed := clampf(absf(_vel) / 22.0, 0.12, 1.0)
	Haptics.impact(lerpf(0.10, 0.50, speed))
	AudioFeel.play_tick(lerpf(0.82, 1.22, speed))
