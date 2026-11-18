extends Node
## Device posture and desk-stand detection.

signal desk_stand_changed(active: bool)

const STILLNESS_THRESHOLD := 0.15
# Desk Stand turns on only after the phone has stood on its side, still, this long,
# so tilting to play (bearings, cube) never flips the screen.
const ENTER_HOLD_SEC := 2.0
# It turns off after the phone has been laid flat or moved for this long.
const EXIT_HOLD_SEC := 0.4
const PICKUP_GYRO := 0.6
# Shares of gravity: along the screen's short axis when standing sideways,
# along its long axis at most, and through the screen when laid flat.
const SIDEWAYS_MIN := 0.75
const ALONG_MAX := 0.4
const FLAT_MIN := 0.75

var desk_stand_active: bool = false
var _orientation: int = -1
var _hold: float = 0.0


func _ready() -> void:
	_lock_portrait()


func _process(delta: float) -> void:
	var allowed := EntitlementStore.has_desk_stand_mode() and Haptics.is_charging()
	step_desk_stand(delta, allowed, Input.get_accelerometer(), Input.get_gyroscope())


func step_desk_stand(delta: float, allowed: bool, accel: Vector3, gyro: Vector3) -> void:
	var next := desk_stand_active
	if not allowed:
		next = false
		_hold = 0.0
	else:
		var flip := _stand_lost(accel, gyro) if desk_stand_active else _stand_held(accel, gyro)
		_hold = _hold + delta if flip else 0.0
		if _hold >= (EXIT_HOLD_SEC if desk_stand_active else ENTER_HOLD_SEC):
			next = not desk_stand_active
			_hold = 0.0
	if next:
		_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	else:
		_lock_portrait()
	if next != desk_stand_active:
		desk_stand_active = next
		_apply_desk_stand(desk_stand_active)
		desk_stand_changed.emit(desk_stand_active)


func _lock_portrait() -> void:
	_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _set_orientation(orientation: int) -> void:
	if _orientation == orientation:
		return
	_orientation = orientation
	DisplayServer.screen_set_orientation(orientation)


## Portrait frame: still and standing on its long edge, like in a stand.
func _stand_held(accel: Vector3, gyro: Vector3) -> bool:
	if gyro.length() >= STILLNESS_THRESHOLD or accel.length() < 0.001:
		return false
	var g := accel.normalized()
	return absf(g.x) >= SIDEWAYS_MIN and absf(g.y) <= ALONG_MAX


## Works whichever way the sensor axes follow the screen: picked up or laid flat.
func _stand_lost(accel: Vector3, gyro: Vector3) -> bool:
	if gyro.length() >= PICKUP_GYRO:
		return true
	if accel.length() < 0.001:
		return false
	return absf(accel.normalized().z) >= FLAT_MIN


func _apply_desk_stand(active: bool) -> void:
	DisplayServer.screen_set_keep_on(active)


func is_landscape() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	return size.x > size.y
