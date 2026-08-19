extends Node
## Local entitlement cache — no cloud, no accounts.

const SAVE_PATH := "user://entitlements.cfg"
const KEY_LIFETIME := "lifetime_unlocked"

signal entitlements_changed

var lifetime_unlocked: bool = false


func _ready() -> void:
	load_entitlements()


func load_entitlements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	lifetime_unlocked = cfg.get_value("entitlements", KEY_LIFETIME, false)


func save_entitlements() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("entitlements", KEY_LIFETIME, lifetime_unlocked)
	cfg.save(SAVE_PATH)


func set_lifetime_unlocked(value: bool) -> void:
	if lifetime_unlocked == value:
		return
	lifetime_unlocked = value
	save_entitlements()
	entitlements_changed.emit()


func reset_lifetime() -> void:
	lifetime_unlocked = false
	save_entitlements()
	entitlements_changed.emit()


func has_lifetime() -> bool:
	return lifetime_unlocked


func is_module_unlocked(module_id: String) -> bool:
	if has_lifetime():
		return true
	return module_id in ModuleRegistry.FREE_MODULES


func has_desk_stand_mode() -> bool:
	return has_lifetime()


func has_premium_themes() -> bool:
	return has_lifetime()
