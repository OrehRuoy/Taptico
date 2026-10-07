extends Node
## Local entitlement cache — no cloud, no accounts.

const SAVE_PATH := "user://entitlements.cfg"
const KEY_LIFETIME := "lifetime_unlocked"
const TRIAL_SECONDS := 300.0

signal entitlements_changed

var lifetime_unlocked: bool = false
var _trial_left: Dictionary = {}
var _trial_unsaved: float = 0.0


func _ready() -> void:
	load_entitlements()


func load_entitlements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	lifetime_unlocked = cfg.get_value("entitlements", KEY_LIFETIME, false)
	_trial_left.clear()
	if cfg.has_section("trial"):
		for key in cfg.get_section_keys("trial"):
			_trial_left[str(key)] = float(cfg.get_value("trial", key, TRIAL_SECONDS))


func save_entitlements() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("entitlements", KEY_LIFETIME, lifetime_unlocked)
	for module_id in _trial_left:
		cfg.set_value("trial", str(module_id), float(_trial_left[module_id]))
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


## Seconds left on this fidget's one-time try. A missing entry is a full unused try.
func trial_seconds_left(module_id: String) -> float:
	if module_id.is_empty() or is_module_unlocked(module_id):
		return 0.0
	if not _trial_left.has(module_id):
		return TRIAL_SECONDS
	return maxf(float(_trial_left[module_id]), 0.0)


## Remember that this fidget's try has started, without spending time yet.
func begin_trial(module_id: String) -> float:
	var left := trial_seconds_left(module_id)
	if module_id.is_empty() or is_module_unlocked(module_id):
		return 0.0
	if not _trial_left.has(module_id):
		_trial_left[module_id] = left
		save_entitlements()
	return left


## Spend foreground time on one fidget. Saves every few seconds, and immediately at zero.
func spend_trial(module_id: String, seconds: float) -> float:
	if module_id.is_empty() or is_module_unlocked(module_id):
		return 0.0
	if seconds < 0.0:
		seconds = 0.0
	var left := trial_seconds_left(module_id) - seconds
	if left < 0.0:
		left = 0.0
	_trial_left[module_id] = left
	_trial_unsaved += seconds
	if left <= 0.0 or _trial_unsaved >= 5.0:
		_trial_unsaved = 0.0
		save_entitlements()
	return left


func flush_trial_save() -> void:
	if _trial_unsaved <= 0.0:
		return
	_trial_unsaved = 0.0
	save_entitlements()


func clear_trials() -> void:
	_trial_left.clear()
	_trial_unsaved = 0.0
	save_entitlements()


func has_desk_stand_mode() -> bool:
	return has_lifetime()


func has_premium_themes() -> bool:
	return has_lifetime()
