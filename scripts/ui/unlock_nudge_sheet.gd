class_name UnlockNudgeSheet
extends Control
## One-time sheet after a free toy has actually been played.

signal see_unlock
signal dismissed


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 230
	z_as_relative = false
	_build()


func present() -> void:
	show()
	move_to_front()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -160
	card.offset_right = 160
	card.offset_top = -150
	card.offset_bottom = 150
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.08, 0.07, 0.96)
	box.border_color = Color(0.84, 0.70, 0.44, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(18)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 18
	box.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", box)
	add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	var title := Label.new()
	title.text = "These three are free"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
	col.add_child(title)

	var body := Label.new()
	body.text = "Lock, switches, and the slider stay free. Lifetime unlock adds the rest of the desk, including Desk Stand."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.90, 0.86, 0.78))
	col.add_child(body)

	var see := Button.new()
	see.text = "See unlock"
	see.custom_minimum_size = Vector2(0, 44)
	see.pressed.connect(func() -> void:
		hide()
		see_unlock.emit()
	)
	col.add_child(see)

	var later := Button.new()
	later.text = "Not now"
	later.custom_minimum_size = Vector2(0, 40)
	later.pressed.connect(_close)
	col.add_child(later)


func _close() -> void:
	hide()
	dismissed.emit()
