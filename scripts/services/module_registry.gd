extends Node
## Module catalog and scene paths.

const FREE_MODULES: Array[String] = ["combination_lock", "toggle_switches", "magnetic_slider"]

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
		"hint": "Press and drag. Left is lower, right is higher. Up is brighter, down is warmer.",
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
	{
		"id": "magnetic_slider",
		"name": "Magnetic Slider",
		"short": "Slider",
		"icon": "res://assets/modules/nav_slider.png",
		"hint": "Drag the plate. It snaps to either end.",
		"scene": "res://scenes/modules/slider/MagneticSlider.tscn",
		"premium": false,
	},
	{
		"id": "metal_spinner",
		"name": "Metal Spinner",
		"short": "Spinner",
		"icon": "res://assets/modules/nav_spinner.png",
		"hint": "Flick to spin. Tilt adds a little weight.",
		"scene": "res://scenes/modules/spinner/MetalSpinner.tscn",
		"premium": true,
	},
	{
		"id": "clicker_pen",
		"name": "Clicker Pen",
		"short": "Pen",
		"icon": "res://assets/modules/nav_pen.png",
		"hint": "Click the top. The tip comes out when the clicker is in.",
		"scene": "res://scenes/modules/pen/ClickerPen.tscn",
		"premium": true,
	},
	{
		"id": "desk_cube",
		"name": "Desk Cube",
		"short": "Cube",
		"icon": "res://assets/modules/nav_cube.png",
		"hint": "Swipe beside the cube to flip faces. Stick, spin, rub, or tap.",
		"scene": "res://scenes/modules/cube/DeskCube.tscn",
		"premium": true,
	},
	{
		"id": "infinity_cube",
		"name": "Infinity Cube",
		"short": "Infinity",
		"icon": "res://assets/modules/nav_infinity.png",
		"hint": "Drag a side to fold.",
		"scene": "res://scenes/modules/infinity/InfinityCube.tscn",
		"premium": true,
	},
	{
		"id": "zipper",
		"name": "Zipper",
		"short": "Zipper",
		"icon": "res://assets/modules/nav_zipper.png",
		"hint": "Drag the puller to zip and unzip.",
		"scene": "res://scenes/modules/zipper/Zipper.tscn",
		"premium": true,
	},
	{
		"id": "dimple_plate",
		"name": "Dimple Plate",
		"short": "Dimples",
		"icon": "res://assets/modules/nav_dimple.png",
		"hint": "Tap to pop. Use Reset to flip them back.",
		"scene": "res://scenes/modules/dimple/DimplePlate.tscn",
		"premium": true,
	},
	{
		"id": "desk_putty",
		"name": "Desk Putty",
		"short": "Putty",
		"icon": "res://assets/modules/nav_putty.png",
		"hint": "Drag to move. Two fingers stretch slowly. Pull a thin middle to snap it.",
		"scene": "res://scenes/modules/putty/DeskPutty.tscn",
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
