extends Node
## Module catalog and scene paths.

const FREE_MODULES: Array[String] = ["combination_lock", "toggle_switches"]

const MODULES: Array[Dictionary] = [
	{
		"id": "combination_lock",
		"name": "Combination Lock",
		"short": "Lock",
		"icon": "res://assets/modules/nav_lock.png",
		"hint": "Drag the dial.",
		"scene": "res://scenes/modules/lock/CombinationLock.tscn",
		"premium": false,
	},
	{
		"id": "toggle_switches",
		"name": "Toggle Switches",
		"short": "Switches",
		"icon": "res://assets/modules/nav_switch.png",
		"hint": "Tap a switch to flip it.",
		"scene": "res://scenes/modules/toggles/ToggleSwitches.tscn",
		"premium": false,
	},
	{
		"id": "bearing_chamber",
		"name": "Bearing Chamber",
		"short": "Bearings",
		"icon": "res://assets/modules/nav_bearings.png",
		"hint": "Tilt the phone to roll the bearings.",
		"scene": "res://scenes/modules/bearing/BearingChamber.tscn",
		"premium": true,
	},
	{
		"id": "theremin_pad",
		"name": "Ambient Pad",
		"short": "Pad",
		"icon": "res://assets/modules/nav_pad.png",
		"hint": "Press and drag for pitch and warmth.",
		"scene": "res://scenes/modules/theremin/ThereminPad.tscn",
		"premium": true,
	},
	{
		"id": "key_matrix",
		"name": "Key Matrix",
		"short": "Keys",
		"icon": "res://assets/modules/nav_keys.png",
		"hint": "Pick Smooth, Bump, or Click, then tap.",
		"scene": "res://scenes/modules/keys/KeyMatrix.tscn",
		"premium": true,
	},
]


func get_module(index: int) -> Dictionary:
	if index < 0 or index >= MODULES.size():
		return {}
	return MODULES[index]


func get_module_count() -> int:
	return MODULES.size()


func get_module_by_id(module_id: String) -> Dictionary:
	for mod in MODULES:
		if mod["id"] == module_id:
			return mod
	return {}
