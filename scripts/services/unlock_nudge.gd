extends Node
## One calm Lifetime unlock offer after real play on a free toy. Never on a cold open.

const SAVE_PATH := "user://unlock_nudge.cfg"
const LOCK_NEED := 40
const SWITCH_NEED := 1
const SLIDER_NEED := 1

signal offer_ready

var shown: bool = false
var lock_count: int = 0
var switch_count: int = 0
var slider_count: int = 0


func _ready() -> void:
	_load()


func should_offer() -> bool:
	if shown or EntitlementStore.has_lifetime():
		return false
	return lock_count >= LOCK_NEED or switch_count >= SWITCH_NEED or slider_count >= SLIDER_NEED


func mark_shown() -> void:
	if shown:
		return
	shown = true
	_save()


func note_lock() -> void:
	_note("lock")


func note_switch() -> void:
	_note("switch")


func note_slider() -> void:
	_note("slider")


func _note(which: String) -> void:
	if shown or EntitlementStore.has_lifetime():
		return
	match which:
		"lock":
			lock_count += 1
		"switch":
			switch_count += 1
		"slider":
			slider_count += 1
	_save()
	if should_offer():
		offer_ready.emit()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	shown = bool(cfg.get_value("nudge", "shown", false))
	lock_count = int(cfg.get_value("nudge", "lock", 0))
	switch_count = int(cfg.get_value("nudge", "switch", 0))
	slider_count = int(cfg.get_value("nudge", "slider", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("nudge", "shown", shown)
	cfg.set_value("nudge", "lock", lock_count)
	cfg.set_value("nudge", "switch", switch_count)
	cfg.set_value("nudge", "slider", slider_count)
	cfg.save(SAVE_PATH)
