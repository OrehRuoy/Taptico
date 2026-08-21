extends Node
## Device posture and desk-stand detection.

signal desk_stand_changed(active: bool)

const STILLNESS_THRESHOLD := 0.15

var desk_stand_active: bool = false
var _orientation: int = -1


func _ready() -> void:
	_lock_portrait()


func _process(_delta: float) -> void:
	var should_be_active := _evaluate_desk_stand()
	if should_be_active:
		_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	else:
		_lock_portrait()
	if should_be_active != desk_stand_active:
		desk_stand_active = should_be_active
		_apply_desk_stand(desk_stand_active)
		desk_stand_changed.emit(desk_stand_active)


func _lock_portrait() -> void:
	_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _set_orientation(orientation: int) -> void:
	if _orientation == orientation:
		return
	_orientation = orientation
	DisplayServer.screen_set_orientation(orientation)


func _evaluate_desk_stand() -> bool:
	if not EntitlementStore.has_desk_stand_mode():
		return false
	if not Haptics.is_charging():
		return false
	if Input.get_gyroscope().length() >= STILLNESS_THRESHOLD:
		return false
	var accel := Input.get_accelerometer()
	return absf(accel.x) > absf(accel.y) + 0.2


func _apply_desk_stand(active: bool) -> void:
	DisplayServer.screen_set_keep_on(active)


func is_landscape() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	return size.x > size.y
