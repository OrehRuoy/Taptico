extends FidgetModule
## Top-down circular well. Bearings stay inside the rim.

const BALL_COUNT := 5
const WALL_SEGS := 36
const BALL_R := 16.0
const WELL_TEX := preload("res://assets/modules/chamber_well.png")
const BALL_TEX := preload("res://assets/modules/bearing_photo.png")

@onready var chamber: Node2D = $Chamber
@onready var balls_root: Node2D = $Chamber/Balls
@onready var frame: TextureRect = $Frame

var _well: Sprite2D
var _rim: StaticBody2D
var _wall_cols: Array[CollisionShape2D] = []
var _balls: Array[RigidBody2D] = []
var _inner_radius: float = 118.0
var _last_clack_ms: int = 0


func _ready() -> void:
	module_id = "bearing_chamber"
	display_name = "Bearing Chamber"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if frame:
		frame.hide()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well = Sprite2D.new()
	Chroma.apply(_well, WELL_TEX)
	_well.z_index = 0
	_well.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chamber.add_child(_well)
	chamber.move_child(_well, 0)
	_disable_box_walls()
	_build_rim()
	for i in BALL_COUNT:
		var ball := balls_root.get_node("Ball%d" % i) as RigidBody2D
		ball.contact_monitor = true
		ball.max_contacts_reported = 8
		ball.gravity_scale = 1.0
		ball.linear_damp = 0.35
		ball.freeze = true
		ball.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		ball.body_entered.connect(_on_ball_collision)
		if ball.has_node("Sprite"):
			ball.get_node("Sprite").hide()
		if ball.has_node("Photo"):
			ball.get_node("Photo").queue_free()
		var sprite := Sprite2D.new()
		sprite.name = "Photo"
		Chroma.apply(sprite, BALL_TEX)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if BALL_TEX:
			var sc := (BALL_R * 2.0) / (float(BALL_TEX.get_width()) * 0.90)
			sprite.scale = Vector2(sc, sc)
		ball.add_child(sprite)
		_balls.append(ball)
	balls_root.z_index = 1
	resized.connect(_layout)
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_set_balls_frozen(true)
	_layout()


func _on_viewport_resized() -> void:
	_layout()
	if _active:
		_respawn_balls()
		_set_balls_frozen(false)


func _disable_box_walls() -> void:
	for wall_name in ["Top", "Bottom", "Left", "Right"]:
		var wall := chamber.get_node_or_null(wall_name)
		if wall:
			wall.queue_free()


func _build_rim() -> void:
	_rim = StaticBody2D.new()
	_rim.name = "Rim"
	chamber.add_child(_rim)
	for i in WALL_SEGS:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(28, 22)
		col.shape = shape
		_rim.add_child(col)
		_wall_cols.append(col)


func _layout() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_set_balls_frozen(true)
	var c := ReachSettings.play_center(size)
	chamber.position = c
	var well_d := minf(size.x, size.y) * 0.88
	if _well and _well.texture:
		var sc := well_d / float(_well.texture.get_width())
		_well.scale = Vector2(sc, sc)
		_well.position = Vector2.ZERO
	_inner_radius = well_d * 0.352
	_layout_rim(_inner_radius)
	_respawn_balls()
	if _active:
		_set_balls_frozen(false)


func _layout_rim(radius: float) -> void:
	var chord := (TAU * radius / float(WALL_SEGS)) + 8.0
	for i in _wall_cols.size():
		var ang := float(i) * TAU / float(WALL_SEGS)
		var col := _wall_cols[i]
		var shape := col.shape as RectangleShape2D
		shape.size = Vector2(chord, 24)
		col.position = Vector2.from_angle(ang) * radius
		col.rotation = ang + PI * 0.5


func on_activate() -> void:
	if balls_root:
		balls_root.process_mode = Node.PROCESS_MODE_INHERIT
	_layout()
	_respawn_balls()
	_set_balls_frozen(false)


func on_deactivate() -> void:
	_set_balls_frozen(true)
	if balls_root:
		balls_root.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for ball in _balls:
		if not is_instance_valid(ball):
			continue
		if not ball.position.is_finite() or ball.position.length() > _inner_radius + BALL_R * 3.0:
			_respawn_balls()
			return


func _set_balls_frozen(frozen: bool) -> void:
	for ball in _balls:
		if not is_instance_valid(ball):
			continue
		ball.freeze = frozen
		ball.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		if frozen:
			ball.linear_velocity = Vector2.ZERO
			ball.angular_velocity = 0.0
			ball.sleeping = true
		else:
			ball.sleeping = false


func _respawn_balls() -> void:
	var spots: Array[Vector2] = [
		Vector2(-28, -24),
		Vector2(0, -36),
		Vector2(28, -18),
		Vector2(-16, 22),
		Vector2(20, 30),
	]
	var limit := maxf(_inner_radius - BALL_R - 8.0, 12.0)
	for i in _balls.size():
		var ball := _balls[i]
		if not is_instance_valid(ball):
			continue
		var pos := spots[i % spots.size()]
		if pos.length() > limit:
			pos = pos.normalized() * limit
		if not pos.is_finite():
			pos = Vector2.ZERO
		ball.freeze = true
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		ball.position = pos
		if not ball.position.is_finite():
			ball.position = Vector2.ZERO
		ball.reset_physics_interpolation()
	if _active:
		_set_balls_frozen(false)


func on_tilt(accel: Vector3, _gyro: Vector3) -> void:
	var shake := AppSettings.shake_strength
	var force := Vector2(accel.x, -accel.y) * (1400.0 * shake)
	if accel.length() < 0.15:
		var local := get_local_mouse_position() - chamber.position
		var mouse_force := local.normalized() * minf(local.length() / 90.0, 1.0) * (1400.0 * maxf(shake, 0.35))
		force = Vector2(0, 720 * maxf(shake, 0.2)) + mouse_force
	for ball in _balls:
		if is_instance_valid(ball) and not ball.freeze:
			ball.apply_central_force(force * ball.mass)


func _on_ball_collision(_body: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_clack_ms < 45:
		return
	_last_clack_ms = now
	var gain := lerpf(0.25, 0.7, AppSettings.shake_strength)
	Haptics.impact(randf_range(0.18, 0.85))
	AudioFeel.play_clack(gain)
