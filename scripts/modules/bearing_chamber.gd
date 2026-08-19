extends FidgetModule
## Top-down circular well. Bearings stay inside the rim.

const BALL_COUNT := 5
const WALL_SEGS := 36
const BALL_R := 16.0
const WELL_TEX := preload("res://assets/modules/chamber_well.png")
const BALL_TEX := preload("res://assets/modules/bearing_photo.png")
const CHROMA := preload("res://shaders/chroma_key.gdshader")

@onready var chamber: Node2D = $Chamber
@onready var balls_root: Node2D = $Chamber/Balls
@onready var frame: TextureRect = $Frame

var _well: Sprite2D
var _rim: StaticBody2D
var _wall_cols: Array[CollisionShape2D] = []
var _balls: Array[RigidBody2D] = []
var _inner_radius: float = 118.0


func _ready() -> void:
	module_id = "bearing_chamber"
	display_name = "Bearing Chamber"
	is_premium = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if frame:
		frame.hide()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well = Sprite2D.new()
	_well.texture = WELL_TEX
	_well.z_index = 0
	_well.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chamber.add_child(_well)
	chamber.move_child(_well, 0)
	_disable_box_walls()
	_build_rim()
	var ball_mat := ShaderMaterial.new()
	ball_mat.shader = CHROMA
	ball_mat.set_shader_parameter("circle_mask", 1.0)
	ball_mat.set_shader_parameter("circle_radius", 0.488)
	ball_mat.set_shader_parameter("circle_feather", 0.022)
	for i in BALL_COUNT:
		var ball := balls_root.get_node("Ball%d" % i) as RigidBody2D
		ball.contact_monitor = true
		ball.max_contacts_reported = 8
		ball.gravity_scale = 1.0
		ball.linear_damp = 0.35
		ball.body_entered.connect(_on_ball_collision)
		if ball.has_node("Sprite"):
			ball.get_node("Sprite").hide()
		if ball.has_node("Photo"):
			ball.get_node("Photo").queue_free()
		var sprite := Sprite2D.new()
		sprite.name = "Photo"
		sprite.texture = BALL_TEX
		sprite.material = ball_mat
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if BALL_TEX:
			var sc := (BALL_R * 2.0) / (float(BALL_TEX.get_width()) * 0.90)
			sprite.scale = Vector2(sc, sc)
		ball.add_child(sprite)
		_balls.append(ball)
	balls_root.z_index = 1
	resized.connect(_layout)
	_layout()


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
	var c := ReachSettings.play_center(size)
	chamber.position = c
	var well_d := minf(size.x, size.y) * 0.88
	if _well and _well.texture:
		var sc := well_d / float(_well.texture.get_width())
		_well.scale = Vector2(sc, sc)
		_well.position = Vector2.ZERO
	_inner_radius = well_d * 0.352
	_layout_rim(_inner_radius)


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
	_layout()
	for ball in _balls:
		if ball.position.length() > _inner_radius - BALL_R - 2.0:
			ball.position = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		ball.sleeping = false


func on_tilt(accel: Vector3, _gyro: Vector3) -> void:
	var force := Vector2(accel.x, -accel.y) * 1400.0
	if accel.length() < 0.15:
		var local := get_local_mouse_position() - chamber.position
		var mouse_force := local.normalized() * minf(local.length() / 90.0, 1.0) * 1400.0
		force = Vector2(0, 720) + mouse_force
	for ball in _balls:
		ball.apply_central_force(force * ball.mass)


func _on_ball_collision(_body: Node) -> void:
	Haptics.impact(randf_range(0.18, 0.85))
