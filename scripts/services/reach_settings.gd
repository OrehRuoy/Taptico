extends Node
## One-hand vs two-hand toy placement.

signal changed

enum Mode { TWO_HAND, RIGHT, LEFT }

const SAVE_PATH := "user://settings.cfg"
const LABELS := ["Two hands", "Right hand", "Left hand"]

var mode: int = Mode.TWO_HAND


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		mode = clampi(int(cfg.get_value("reach", "mode", Mode.TWO_HAND)), 0, 2)


func cycle() -> void:
	mode = (mode + 1) % 3
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("reach", "mode", mode)
	cfg.save(SAVE_PATH)
	changed.emit()


func label() -> String:
	return LABELS[mode]


func cluster_origin(area: Vector2, cluster: Vector2) -> Vector2:
	var pad := 16.0
	match mode:
		Mode.RIGHT:
			return Vector2(area.x - pad - cluster.x, (area.y - cluster.y) * 0.46)
		Mode.LEFT:
			return Vector2(pad, (area.y - cluster.y) * 0.46)
		_:
			return Vector2((area.x - cluster.x) * 0.5, (area.y - cluster.y) * 0.42)


func play_center(area: Vector2) -> Vector2:
	match mode:
		Mode.RIGHT:
			return Vector2(area.x * 0.62, area.y * 0.48)
		Mode.LEFT:
			return Vector2(area.x * 0.38, area.y * 0.48)
		_:
			return Vector2(area.x * 0.5, area.y * 0.50)
