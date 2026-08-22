extends FidgetModule
## Top-down circular well. Bearings stay inside the rim.

const BALL_COUNT := 5
const BALL_R := 16.0
const WELL_TEX := preload("res://assets/modules/chamber_well.png")
const BALL_TEX := preload("res://assets/modules/bearing_photo.png")

@onready var chamber: Node2D = $Chamber
@onready var balls_root: Node2D = $Chamber/Balls

var _well: Sprite2D
var _ball_spr: Array[Sprite2D] = []
var _ball_pos: Array[Vector2] = []
var _ball_vel: Array[Vector2] = []
var _inner_radius: float = 118.0
var _gravity := Vector2(0, 720)
var _last_clack_ms: int = 0
var _placed: bool = false


func _ready() -> void:
	module_id = "bearing_chamber"
	display_name = "Bearing Chamber"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_well = Sprite2D.new()
	Chroma.apply(_well, WELL_TEX)
	_well.z_index = 0
	_well.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chamber.add_child(_well)
	chamber.move_child(_well, 0)
	_disable_box_walls()
	_clear_scene_balls()
	_make_balls()
	balls_root.z_index = 1
	resized.connect(_layout)
	_layout()


func _disable_box_walls() -> void:
	for wall_name in ["Top", "Bottom", "Left", "Right"]:
		var wall := chamber.get_node_or_null(wall_name)
		if wall:
			wall.queue_free()


func _clear_scene_balls() -> void:
	if balls_root == null:
		return
	for child in balls_root.get_children():
		if child is RigidBody2D:
			var rb := child as RigidBody2D
			rb.freeze = true
			rb.collision_layer = 0
			rb.collision_mask = 0
			rb.contact_monitor = false
		child.visible = false
		child.queue_free()


func _make_balls() -> void:
	_ball_spr.clear()
	_ball_pos.clear()
	_ball_vel.clear()
	var sc := 1.0
	if BALL_TEX:
		sc = (BALL_R * 2.0) / (float(BALL_TEX.get_width()) * 0.90)
	for i in BALL_COUNT:
		var sprite := Sprite2D.new()
		sprite.name = "Steel%d" % i
		Chroma.apply(sprite, BALL_TEX)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.centered = true
		sprite.scale = Vector2(sc, sc)
		balls_root.add_child(sprite)
		_ball_spr.append(sprite)
		_ball_pos.append(Vector2.ZERO)
		_ball_vel.append(Vector2.ZERO)


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var c := ReachSettings.play_center(size)
	chamber.position = c
	var well_d := minf(size.x, size.y) * 0.88
	if _well and _well.texture:
		var sc := well_d / float(_well.texture.get_width())
		_well.scale = Vector2(sc, sc)
		_well.position = Vector2.ZERO
	var new_r := well_d * 0.352
	if _inner_radius > 24.0 and new_r > 24.0 and not _ball_pos.is_empty():
		var grow := new_r / _inner_radius
		if absf(grow - 1.0) > 0.01:
			for i in _ball_pos.size():
				_ball_pos[i] *= grow
				_ball_vel[i] *= grow
	_inner_radius = new_r
	if not _placed or _needs_respawn():
		_respawn_balls()
		_placed = true
	_sync_sprites()


func _needs_respawn() -> bool:
	if _ball_pos.size() != BALL_COUNT:
		return true
	var limit := _inner_radius + BALL_R * 2.0
	for pos in _ball_pos:
		if not pos.is_finite() or pos.length() > limit:
			return true
	return false


func on_activate() -> void:
	if balls_root:
		balls_root.process_mode = Node.PROCESS_MODE_INHERIT
	_layout()
	if _needs_respawn():
		_respawn_balls()
	_sync_sprites()


func on_deactivate() -> void:
	if balls_root:
		balls_root.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if not _active or _ball_pos.size() != BALL_COUNT:
		return
	var dt := minf(delta, 0.033)
	var damp := exp(-1.6 * dt)
	var limit := maxf(_inner_radius - BALL_R - 2.0, 12.0)
	for i in BALL_COUNT:
		_ball_vel[i] += _gravity * dt
		_ball_vel[i] *= damp
		_ball_pos[i] += _ball_vel[i] * dt
		if not _ball_pos[i].is_finite():
			_respawn_balls()
			return
	for i in BALL_COUNT:
		for j in range(i + 1, BALL_COUNT):
			var delta_p := _ball_pos[j] - _ball_pos[i]
			var dist := delta_p.length()
			var min_d := BALL_R * 2.0
			if dist < 0.001:
				delta_p = Vector2.from_angle(float(i) * 1.256)
				dist = 0.001
			if dist >= min_d:
				continue
			var n := delta_p / dist
			var overlap := (min_d - dist) * 0.5
			_ball_pos[i] -= n * overlap
			_ball_pos[j] += n * overlap
			var rel := _ball_vel[j] - _ball_vel[i]
			var vn := rel.dot(n)
			if vn < 0.0:
				var impulse := n * vn * 0.82
				_ball_vel[i] += impulse
				_ball_vel[j] -= impulse
				_clack(rel.length())
	for i in BALL_COUNT:
		var pos := _ball_pos[i]
		var d := pos.length()
		if d > limit:
			var n := pos / maxf(d, 0.001)
			_ball_pos[i] = n * limit
			var vn := _ball_vel[i].dot(n)
			if vn > 0.0:
				_ball_vel[i] -= n * vn * 1.55
				_ball_vel[i] *= 0.92
				_clack(absf(vn))
		_ball_spr[i].position = _ball_pos[i]
		_ball_spr[i].rotation += _ball_vel[i].length() * dt * 0.04


func _sync_sprites() -> void:
	for i in _ball_spr.size():
		if i < _ball_pos.size():
			_ball_spr[i].position = _ball_pos[i]


func _respawn_balls() -> void:
	if _ball_pos.size() != BALL_COUNT:
		return
	var ring := maxf(_inner_radius * 0.42, BALL_R * 2.2)
	for i in BALL_COUNT:
		var ang := float(i) * TAU / float(BALL_COUNT) - PI * 0.5
		_ball_pos[i] = Vector2.from_angle(ang) * ring
		_ball_vel[i] = Vector2.ZERO
	_sync_sprites()


func on_tilt(accel: Vector3, _gyro: Vector3) -> void:
	if chamber == null:
		return
	var shake := AppSettings.shake_strength
	if accel.length() >= 0.18:
		_gravity = Vector2(accel.x, -accel.y) * (980.0 * shake)
	else:
		var local := get_local_mouse_position() - chamber.position
		var mouse_force := local.normalized() * minf(local.length() / 90.0, 1.0) * (900.0 * maxf(shake, 0.35))
		_gravity = Vector2(0, 720 * maxf(shake, 0.2)) + mouse_force


func _clack(speed: float) -> void:
	if speed < 55.0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_clack_ms < 50:
		return
	_last_clack_ms = now
	var gain := lerpf(0.22, 0.7, AppSettings.shake_strength)
	Haptics.impact(clampf(speed / 420.0, 0.16, 0.85))
	AudioFeel.play_clack(gain)
