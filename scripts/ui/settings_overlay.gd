extends Control
## Sound, haptics, tilt/shake, and one-hand reach.

signal preview_enjoy_requested
signal simulate_enjoy_requested

const FRAME_TEX := preload("res://assets/modules/paywall_frame.png")
const TITLE_TEX := preload("res://assets/modules/title_settings.png")
const CLOSE_TEX := preload("res://assets/modules/btn_close_x.png")

var _sound_btn: Button
var _vol: HSlider
var _haptic: HSlider
var _shake: HSlider
var _vol_lab: Label
var _haptic_lab: Label
var _shake_lab: Label
var _reach_buttons: Dictionary = {}
var _opened_at_ms: int = 0
var _shell: Control
var _frame: TextureRect
var _title: TextureRect
var _close: TextureButton
var _scroll: ScrollContainer
var _col: VBoxContainer
var _knob: ImageTexture


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 210
	z_as_relative = false
	_knob = _make_knob()
	_build()
	resized.connect(_layout_card)
	AppSettings.changed.connect(_refresh)
	ReachSettings.changed.connect(_refresh_reach)


func _make_knob() -> ImageTexture:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(13.5, 13.5)
	for y in 28:
		for x in 28:
			var d := Vector2(x, y).distance_to(c)
			if d <= 10.5:
				img.set_pixel(x, y, Color(0.93, 0.82, 0.55, 1))
			elif d <= 12.5:
				img.set_pixel(x, y, Color(0.72, 0.56, 0.30, 1))
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


func _empty_tex_button(button: TextureButton) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.16)
	dim.gui_input.connect(_on_dim)
	add_child(dim)

	_shell = Control.new()
	_shell.name = "Shell"
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shell)

	_frame = TextureRect.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	Chroma.apply(_frame, FRAME_TEX)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_frame)

	_title = TextureRect.new()
	Chroma.apply(_title, TITLE_TEX)
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_title)

	_close = TextureButton.new()
	Chroma.apply(_close, CLOSE_TEX)
	_empty_tex_button(_close)
	_close.pressed.connect(hide_settings)
	_shell.add_child(_close)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_shell.add_child(_scroll)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 11)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_col)

	_col.add_child(_section_label("Hands"))
	var reach_row := HBoxContainer.new()
	reach_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reach_row.add_theme_constant_override("separation", 8)
	reach_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reach_modes := [
		[ReachSettings.Mode.LEFT, "Left"],
		[ReachSettings.Mode.RIGHT, "Right"],
		[ReachSettings.Mode.TWO_HAND, "Both"],
	]
	for item in reach_modes:
		var btn := Button.new()
		btn.text = str(item[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_reach_selected.bind(int(item[0])))
		reach_row.add_child(btn)
		_reach_buttons[int(item[0])] = btn
	_col.add_child(reach_row)

	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(0, 40)
	_sound_btn.pressed.connect(_toggle_sound)
	_style_toggle(_sound_btn)
	_col.add_child(_sound_btn)

	_vol_lab = _section_label("Volume")
	_col.add_child(_vol_lab)
	_vol = _make_slider()
	_vol.value_changed.connect(func(v: float) -> void: AppSettings.set_sound_volume(v / 100.0))
	_col.add_child(_vol)

	_haptic_lab = _section_label("Haptics")
	_col.add_child(_haptic_lab)
	_haptic = _make_slider()
	_haptic.value_changed.connect(func(v: float) -> void: AppSettings.set_haptic_strength(v / 100.0))
	_col.add_child(_haptic)

	_shake_lab = _section_label("Shake / tilt")
	_col.add_child(_shake_lab)
	_shake = _make_slider()
	_shake.value_changed.connect(func(v: float) -> void: AppSettings.set_shake_strength(v / 100.0))
	_col.add_child(_shake)

	var hint := Label.new()
	hint.text = "Shake / tilt moves the bearings. Sound plays with every fidget."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.78, 0.80, 0.82))
	_col.add_child(hint)

	if EnjoyPrompt.debug_tools_enabled():
		_col.add_child(_section_label("Debug"))
		var preview := Button.new()
		preview.text = "Preview enjoy prompt"
		preview.custom_minimum_size = Vector2(0, 40)
		preview.focus_mode = Control.FOCUS_NONE
		preview.pressed.connect(_on_preview_enjoy)
		_style_gold(preview)
		_col.add_child(preview)
		var simulate := Button.new()
		simulate.text = "Simulate 3rd login day"
		simulate.custom_minimum_size = Vector2(0, 40)
		simulate.focus_mode = Control.FOCUS_NONE
		simulate.pressed.connect(_on_simulate_enjoy)
		_style_toggle(simulate)
		_col.add_child(simulate)
		var reset_enjoy := Button.new()
		reset_enjoy.text = "Reset enjoy tracking"
		reset_enjoy.custom_minimum_size = Vector2(0, 40)
		reset_enjoy.focus_mode = Control.FOCUS_NONE
		reset_enjoy.pressed.connect(_on_reset_enjoy)
		_style_toggle(reset_enjoy)
		_col.add_child(reset_enjoy)
		var debug_hint := Label.new()
		debug_hint.text = "Godot: F10 preview · F11 reset days · F12 simulate 3rd day · F9 reset unlock. Debug iOS builds show these buttons too."
		debug_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		debug_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		debug_hint.add_theme_font_size_override("font_size", 11)
		debug_hint.add_theme_color_override("font_color", Color(0.70, 0.72, 0.74))
		_col.add_child(debug_hint)

	_refresh()
	_layout_card()


func _section_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.90, 0.82, 0.58))
	return lab


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.14, 0.11, 0.08, 1)
	groove.set_corner_radius_all(7)
	groove.border_width_left = 1
	groove.border_width_top = 1
	groove.border_width_right = 1
	groove.border_width_bottom = 1
	groove.border_color = Color(0.84, 0.70, 0.44, 0.55)
	groove.content_margin_top = 6
	groove.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.84, 0.70, 0.44, 1)
	fill.set_corner_radius_all(7)
	s.add_theme_stylebox_override("slider", groove)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _knob)
	s.add_theme_icon_override("grabber_highlight", _knob)
	s.add_theme_icon_override("grabber_disabled", _knob)
	return s


func _style_toggle(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.10, 0.12, 0.96)
	box.set_corner_radius_all(14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.84, 0.70, 0.44, 0.55)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	button.add_theme_font_size_override("font_size", 16)


func _style_gold(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.72, 0.58, 0.32, 1)
	box.set_corner_radius_all(14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.93, 0.82, 0.55, 0.95)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	button.add_theme_font_size_override("font_size", 16)


func _layout_card() -> void:
	if _shell == null or size.x < 8.0:
		return
	var pad := 16.0
	var shell_w := minf(size.x - pad * 2.0, 392.0)
	var shell_h := minf(size.y - pad * 2.0, 640.0)
	var ix := shell_w * 0.135
	var iy_t := shell_h * 0.11
	var iy_b := shell_h * 0.10
	var inner_w := shell_w - ix * 2.0
	var inner_h := shell_h - iy_t - iy_b
	var header_h := 58.0
	var close_s := 32.0
	_col.custom_minimum_size = Vector2(inner_w - 6.0, 0.0)
	var content_h := _col.get_combined_minimum_size().y + 10.0
	var body_h := minf(content_h, inner_h - header_h - 8.0)
	var needed_h := iy_t + header_h + 8.0 + body_h + iy_b
	shell_h = minf(needed_h, size.y - pad * 2.0)
	iy_t = shell_h * 0.11
	iy_b = shell_h * 0.10
	inner_w = shell_w - ix * 2.0
	inner_h = shell_h - iy_t - iy_b
	body_h = minf(content_h, inner_h - header_h - 8.0)
	_shell.size = Vector2(shell_w, shell_h)
	_shell.position = (size - _shell.size) * 0.5
	_title.position = Vector2(ix, iy_t + 2.0)
	_title.size = Vector2(inner_w, header_h)
	_close.position = Vector2(ix + inner_w - close_s - 2.0, iy_t + 6.0)
	_close.size = Vector2(close_s, close_s)
	_scroll.position = Vector2(ix + 4.0, iy_t + header_h + 6.0)
	_scroll.size = Vector2(inner_w - 8.0, body_h)
	_scroll.scroll_vertical = 0


func _refresh() -> void:
	if _sound_btn == null:
		return
	_sound_btn.text = "Sound: On" if AppSettings.sound_on else "Sound: Off"
	_vol.editable = AppSettings.sound_on
	_vol.set_value_no_signal(AppSettings.sound_volume * 100.0)
	_vol_lab.text = "Volume  %d%%" % int(round(AppSettings.sound_volume * 100.0))
	_haptic.set_value_no_signal(AppSettings.haptic_strength * 100.0)
	_haptic_lab.text = "Haptics  %s" % AppSettings.haptic_label()
	_shake.set_value_no_signal(AppSettings.shake_strength * 100.0)
	_shake_lab.text = "Shake / tilt  %s" % AppSettings.shake_label()
	_refresh_reach()


func _on_reach_selected(mode: int) -> void:
	ReachSettings.set_mode(mode)
	_refresh_reach()
	AnalyticsService.log_event("reach_mode", {"label": ReachSettings.label()})


func _refresh_reach() -> void:
	for mode in _reach_buttons:
		var btn: Button = _reach_buttons[mode]
		var on := int(mode) == ReachSettings.mode
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.border_width_left = 1
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		if on:
			box.bg_color = Color(0.72, 0.58, 0.32, 1)
			box.border_color = Color(0.93, 0.82, 0.55, 0.95)
			btn.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
		else:
			box.bg_color = Color(0.10, 0.10, 0.12, 0.96)
			box.border_color = Color(0.84, 0.70, 0.44, 0.45)
			btn.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal", box)
		btn.add_theme_stylebox_override("hover", box)
		btn.add_theme_stylebox_override("pressed", box)


func _toggle_sound() -> void:
	AppSettings.set_sound_on(not AppSettings.sound_on)
	if AppSettings.sound_on:
		AudioFeel.play_tick(1.0)


func show_settings() -> void:
	_refresh()
	show()
	move_to_front()
	_opened_at_ms = Time.get_ticks_msec()
	_layout_card()
	await get_tree().process_frame
	_layout_card()


func hide_settings() -> void:
	AppSettings.save()
	hide()


func _on_preview_enjoy() -> void:
	hide_settings()
	preview_enjoy_requested.emit()


func _on_simulate_enjoy() -> void:
	EnjoyPrompt.simulate_third_day()
	hide_settings()
	simulate_enjoy_requested.emit()


func _on_reset_enjoy() -> void:
	EnjoyPrompt.reset_for_debug()
	AudioFeel.play_tick(0.8)


func _on_dim(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_at_ms < 280:
		return
	var tapped := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if tapped:
		hide_settings()
