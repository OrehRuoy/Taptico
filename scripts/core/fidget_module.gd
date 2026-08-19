class_name FidgetModule
extends Control
## Base class for all tactile fidget modules.

@export var module_id: String = ""
@export var display_name: String = "Module"
@export var is_premium: bool = false

var _active: bool = false


func activate() -> void:
	if _active:
		return
	_active = true
	show()
	queue_redraw()
	on_activate()


func deactivate() -> void:
	if not _active:
		return
	_active = false
	on_deactivate()
	hide()


func on_activate() -> void:
	pass


func on_deactivate() -> void:
	pass


func _enter_tree() -> void:
	if not ReachSettings.changed.is_connected(_on_reach_changed):
		ReachSettings.changed.connect(_on_reach_changed)


func _exit_tree() -> void:
	if ReachSettings.changed.is_connected(_on_reach_changed):
		ReachSettings.changed.disconnect(_on_reach_changed)


func _on_reach_changed() -> void:
	if has_method("_layout"):
		call("_layout")


func on_tilt(accel: Vector3, gyro: Vector3) -> void:
	pass


func _process(delta: float) -> void:
	if not _active:
		return
	on_tilt(Input.get_accelerometer(), Input.get_gyroscope())
