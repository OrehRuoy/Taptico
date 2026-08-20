extends Control

const GOLD := Color(0.84, 0.70, 0.44)
const MUTED := Color(0.70, 0.73, 0.76)
const INK := Color(0.07, 0.07, 0.08)
const SWIPE_PX := 64.0
const CHROMA := preload("res://shaders/chroma_key.gdshader")

var _icon_size := 58.0

@onready var title_label: Label = $TitleBand/TitleLabel
@onready var subtitle_label: Label = $TitleBand/SubtitleLabel
@onready var hint_label: Label = $TitleBand/HintLabel
@onready var title_band: Control = $TitleBand
@onready var settings_button: TextureButton = $Header/SettingsButton
@onready var settings_overlay: Control = $Settings
@onready var module_host: Control = $Stage/ModuleHost
@onready var unlock_button: TextureButton = $Header/UnlockButton
@onready var nav_bar: ScrollContainer = $NavBar
@onready var chip_row: HBoxContainer = $NavBar/ChipRow
@onready var paywall: Control = $Paywall
@onready var stage: Panel = $Stage

var _current_index: int = 0
var _module_instances: Dictionary = {}
var _nav_buttons: Array[TextureButton] = []
var _nav_labels: Array[Label] = []
var _swipe_from := Vector2.ZERO
var _swiping: bool = false
var _chroma: ShaderMaterial


func _ready() -> void:
	_chroma = ShaderMaterial.new()
	_chroma.shader = CHROMA
	if has_node("TitleBand/TitlePlate"):
		$TitleBand/TitlePlate.material = _chroma
	if has_node("Header/LogoMark"):
		$Header/LogoMark.material = _chroma
	if has_node("Header/Logo"):
		$Header/Logo.material = _chroma
		$Header/Logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		$Header/Logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_style_chrome()
	_build_nav()
	unlock_button.pressed.connect(_on_unlock_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	title_band.gui_input.connect(_on_chrome_swipe)
	resized.connect(_layout_chrome)
	get_viewport().size_changed.connect(_layout_chrome)
	paywall.z_index = 200
	paywall.z_as_relative = false
	EntitlementStore.entitlements_changed.connect(_refresh_lock_state)
	DeviceService.desk_stand_changed.connect(_on_desk_stand)
	_layout_chrome()
	_show_module(0)
	_refresh_lock_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_on_reset_pressed()


func _style_chrome() -> void:
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = Color(0.05, 0.055, 0.07, 0.4)
	stage_box.set_corner_radius_all(28)
	stage_box.border_width_left = 1
	stage_box.border_width_top = 1
	stage_box.border_width_right = 1
	stage_box.border_width_bottom = 1
	stage_box.border_color = Color(0.84, 0.70, 0.44, 0.22)
	stage.add_theme_stylebox_override("panel", stage_box)
	stage.z_index = 0
	stage.z_as_relative = true
	title_label.add_theme_color_override("font_color", Color(0.93, 0.82, 0.58))
	title_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.03, 0.75))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.55))
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_label.add_theme_constant_override("outline_size", 3)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_icon_button(settings_button)
	_style_icon_button(unlock_button)


func _safe_margins() -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	var vis := get_viewport_rect().size
	if win.x < 8.0 or win.y < 8.0:
		return Vector4(8, 10, 8, 8)
	var safe := DisplayServer.get_display_safe_area()
	var sx := vis.x / win.x
	var sy := vis.y / win.y
	var left := maxf(8.0, float(safe.position.x) * sx)
	var top := maxf(8.0, float(safe.position.y) * sy)
	var right := maxf(8.0, float(win.x - safe.end.x) * sx)
	var bottom := maxf(8.0, float(win.y - safe.end.y) * sy)
	return Vector4(left, top, right, bottom)


func _layout_chrome() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var safe := _safe_margins()
	var header_h := clampf(size.y * 0.075, 52.0, 78.0)
	var title_h := clampf(size.y * 0.082, 56.0, 86.0)
	var nav_h := clampf(size.y * 0.125, 92.0, 128.0)
	var stage_inset := clampf(size.x * 0.03, 10.0, 22.0)
	$HeaderBar.offset_top = 0.0
	$HeaderBar.offset_bottom = safe.y + header_h
	$Header.offset_top = safe.y
	$Header.offset_bottom = safe.y + header_h
	title_band.offset_top = safe.y + header_h
	title_band.offset_bottom = safe.y + header_h + title_h
	stage.offset_left = stage_inset
	stage.offset_right = -stage_inset
	stage.offset_top = safe.y + header_h + title_h + 8.0
	stage.offset_bottom = -(nav_h + safe.w)
	nav_bar.offset_left = stage_inset
	nav_bar.offset_right = -stage_inset
	nav_bar.offset_top = -(nav_h + safe.w - 4.0)
	nav_bar.offset_bottom = -maxi(4, int(safe.w) - 2)
	_layout_header_controls(header_h)
	_icon_size = clampf(minf(size.x, size.y) * 0.07, 48.0, 72.0)
	_update_nav_styles()


func _layout_header_controls(header_h: float) -> void:
	var w := size.x
	var pad := clampf(w * 0.02, 8.0, 16.0)
	var inner_h := header_h - 8.0
	var btn_h := clampf(inner_h, 32.0, 44.0)
	var top := (header_h - btn_h) * 0.5
	var logo_w := clampf(w * 0.28, 88.0, 140.0)
	var logo: TextureRect = $Header/Logo
	logo.offset_left = pad
	logo.offset_top = top
	logo.offset_right = pad + logo_w
	logo.offset_bottom = top + btn_h
	var gear := btn_h
	settings_button.offset_left = -pad - gear
	settings_button.offset_right = -pad
	settings_button.offset_top = top
	settings_button.offset_bottom = top + btn_h
	var premium_w := clampf(btn_h * 2.35, 88.0, 110.0)
	unlock_button.offset_left = settings_button.offset_left - 8.0 - premium_w
	unlock_button.offset_right = settings_button.offset_left - 8.0
	unlock_button.offset_top = top
	unlock_button.offset_bottom = top + btn_h
	var premium_left := w + unlock_button.offset_left
	if premium_left < logo.offset_right + 8.0:
		logo.offset_right = maxf(pad + 72.0, premium_left - 8.0)


func _style_icon_button(button: TextureButton) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.material = null
	button.modulate = Color.WHITE


func _style_round_button(button: Button, bg: Color, fg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(16)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.90, 0.78, 0.50, 0.85)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_font_size_override("font_size", 14)
	button.flat = false


func _build_nav() -> void:
	for child in chip_row.get_children():
		child.queue_free()
	_nav_buttons.clear()
	_nav_labels.clear()
	for i in ModuleRegistry.get_module_count():
		var mod := ModuleRegistry.get_module(i)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_STOP
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(_icon_size, _icon_size)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.focus_mode = Control.FOCUS_NONE
		var tex: Texture2D = load(str(mod.get("icon", "")))
		if tex:
			btn.texture_normal = tex
			btn.material = _chroma
		btn.pressed.connect(_show_module.bind(i))
		var lab := Label.new()
		lab.text = str(mod.get("short", ""))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 10)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(btn)
		col.add_child(lab)
		chip_row.add_child(col)
		_nav_buttons.append(btn)
		_nav_labels.append(lab)


func _style_nav_button(button: TextureButton, active: bool, locked: bool) -> void:
	var idx := _nav_buttons.find(button)
	button.modulate = Color(1, 1, 1, 1) if active else Color(0.72, 0.70, 0.66, 0.42 if locked else 0.78)
	button.custom_minimum_size = Vector2(_icon_size + 4.0, _icon_size + 4.0) if active else Vector2(_icon_size, _icon_size)
	if idx >= 0 and idx < _nav_labels.size():
		var lab := _nav_labels[idx]
		lab.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62) if active else Color(0.62, 0.64, 0.66, 0.9))


func _on_chrome_swipe(event: InputEvent) -> void:
	if paywall.visible or settings_overlay.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_swiping = true
			_swipe_from = event.position
		else:
			if _swiping:
				_finish_swipe(event.position)
			_swiping = false


func _finish_swipe(pos: Vector2) -> void:
	var delta := pos - _swipe_from
	if absf(delta.x) < SWIPE_PX:
		return
	if absf(delta.x) < absf(delta.y) * 1.6:
		return
	if delta.x < 0.0:
		_show_module(_current_index + 1)
	else:
		_show_module(_current_index - 1)


func _show_module(index: int) -> void:
	index = clampi(index, 0, ModuleRegistry.get_module_count() - 1)
	var mod := ModuleRegistry.get_module(index)
	if mod.is_empty():
		return
	if not EntitlementStore.is_module_unlocked(mod["id"]):
		_present_paywall(mod["name"])
		_update_nav_styles()
		return
	for key in _module_instances:
		var inst: FidgetModule = _module_instances[key]
		inst.deactivate()
	var scene_path: String = mod["scene"]
	if not _module_instances.has(scene_path):
		var packed: PackedScene = load(scene_path)
		var instance: FidgetModule = packed.instantiate()
		module_host.add_child(instance)
		instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		_module_instances[scene_path] = instance
	var active: FidgetModule = _module_instances[scene_path]
	active.activate()
	_current_index = index
	title_label.text = mod["name"]
	subtitle_label.text = "FREE" if not mod["premium"] else "PREMIUM"
	hint_label.text = str(mod.get("hint", ""))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_nav_styles()
	AnalyticsService.log_screen(str(mod.get("id", mod["name"])))
	AnalyticsService.log_event("module_view", {
		"module_id": str(mod.get("id", "")),
		"module_name": str(mod.get("name", "")),
		"premium": 1 if bool(mod.get("premium", false)) else 0,
	})


func _update_nav_styles() -> void:
	for i in _nav_buttons.size():
		var mod := ModuleRegistry.get_module(i)
		var locked := not EntitlementStore.is_module_unlocked(mod["id"])
		_style_nav_button(_nav_buttons[i], i == _current_index, locked)


func _present_paywall(module_name: String = "") -> void:
	paywall.z_index = 200
	paywall.z_as_relative = false
	paywall.move_to_front()
	paywall.show_paywall(module_name)
	AnalyticsService.log_screen("paywall")
	AnalyticsService.log_event("paywall_shown", {"module_name": module_name})


func _on_unlock_pressed() -> void:
	if settings_overlay.visible:
		settings_overlay.hide_settings()
	_present_paywall()


func _on_settings_pressed() -> void:
	if paywall.visible:
		paywall.hide()
	settings_overlay.show_settings()


func _on_reset_pressed() -> void:
	EntitlementStore.reset_lifetime()
	_show_module(0)


func _refresh_lock_state() -> void:
	unlock_button.visible = true
	unlock_button.modulate = Color.WHITE
	_update_nav_styles()
	_show_module(_current_index)


func _on_desk_stand(active: bool) -> void:
	$Header.visible = not active
	$HeaderBar.visible = not active
	title_band.visible = not active
	nav_bar.visible = not active
	unlock_button.visible = not active
	settings_button.visible = not active
	if settings_overlay.visible:
		settings_overlay.hide_settings()
