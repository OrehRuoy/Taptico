extends Node
## Unique calendar-day tracking for the "Enjoying Taptico?" prompt.

const SAVE_PATH := "user://enjoy.cfg"
const NEED_DAYS := 3

var unique_days: PackedStringArray = PackedStringArray()
var completed: bool = false
var snoozed_date: String = ""


func _ready() -> void:
	_load()
	record_open_today()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		record_open_today()


func today_stamp() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


func record_open_today() -> void:
	var t := today_stamp()
	if unique_days.has(t):
		return
	unique_days.append(t)
	_save()


func should_show() -> bool:
	if completed:
		return false
	if unique_days.size() < NEED_DAYS:
		return false
	if snoozed_date == today_stamp():
		return false
	return true


func mark_completed() -> void:
	completed = true
	snoozed_date = ""
	_save()


func snooze_today() -> void:
	snoozed_date = today_stamp()
	_save()


func reset_for_debug() -> void:
	unique_days = PackedStringArray()
	completed = false
	snoozed_date = ""
	_save()
	record_open_today()


func simulate_third_day() -> void:
	unique_days = PackedStringArray(["1970-01-01", "1970-01-02", today_stamp()])
	completed = false
	snoozed_date = ""
	_save()


func debug_tools_enabled() -> bool:
	return OS.has_feature("editor") or OS.is_debug_build()


func device_snapshot() -> Dictionary:
	var screen := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	var godot: Dictionary = Engine.get_version_info()
	return {
		"app_version": str(ProjectSettings.get_setting("application/config/version", "1.0.0")),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"model": OS.get_model_name(),
		"locale": OS.get_locale(),
		"screen": "%dx%d" % [screen.x, screen.y],
		"window": "%dx%d" % [win.x, win.y],
		"editor": OS.has_feature("editor"),
		"debug": OS.is_debug_build(),
		"godot": str(godot.get("string", "")),
	}


func device_summary() -> String:
	var d := device_snapshot()
	var model := str(d.model)
	if model.is_empty() or model == "GenericDevice":
		model = str(d.os)
	return "%s · %s %s · Taptico %s" % [model, d.os, d.os_version, d.app_version]


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	completed = bool(cfg.get_value("enjoy", "completed", false))
	snoozed_date = str(cfg.get_value("enjoy", "snoozed", ""))
	var raw: Variant = cfg.get_value("enjoy", "days", PackedStringArray())
	unique_days = PackedStringArray()
	if raw is PackedStringArray:
		unique_days = raw
	elif raw is Array:
		for item in raw:
			var s := str(item)
			if not s.is_empty() and not unique_days.has(s):
				unique_days.append(s)
	elif typeof(raw) == TYPE_STRING:
		for part in str(raw).split(",", false):
			var s := part.strip_edges()
			if not s.is_empty() and not unique_days.has(s):
				unique_days.append(s)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("enjoy", "completed", completed)
	cfg.set_value("enjoy", "snoozed", snoozed_date)
	cfg.set_value("enjoy", "days", unique_days)
	cfg.save(SAVE_PATH)
