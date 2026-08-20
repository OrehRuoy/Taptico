extends Control

const FRAME_TEX := preload("res://assets/modules/paywall_frame.png")
const HERO_TEX := preload("res://assets/modules/paywall_hero.png")
const CLOSE_TEX := preload("res://assets/modules/btn_close_x.png")
const PLATE_TEX := preload("res://assets/modules/btn_gold_plate.png")
const CHROMA := preload("res://shaders/chroma_key.gdshader")

@onready var price_label: Label = $Panel/VBox/PriceLabel
@onready var buy_button: Button = $Panel/VBox/BuyButton
@onready var restore_button: Button = $Panel/VBox/Actions/RestoreButton
@onready var close_button: Button = $Panel/VBox/Actions/CloseButton
@onready var reset_button: Button = $Panel/VBox/Actions/ResetButton
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var headline: Label = $Panel/VBox/Headline
@onready var features: Label = $Panel/VBox/Features
@onready var hero: TextureRect = $Panel/VBox/Hero
@onready var frame: TextureRect = $Frame
@onready var panel: PanelContainer = $Panel
@onready var dim: ColorRect = $Dim
@onready var inner: ColorRect = $Inner

var _opened_at_ms: int = 0
var _close_x: TextureButton
var _buy_plate: TextureRect
var _buy_caption: Label


func _ready() -> void:
	hide()
	z_index = 200
	z_as_relative = false
	_style()
	buy_button.pressed.connect(_on_buy)
	restore_button.pressed.connect(_on_restore)
	close_button.pressed.connect(_on_close)
	if dim:
		dim.gui_input.connect(_on_dim_input)
	if reset_button:
		reset_button.pressed.connect(_on_reset_testing)
		reset_button.visible = OS.has_feature("editor")
	IAPManager.products_loaded.connect(_refresh_price)
	IAPManager.products_failed.connect(_on_products_failed)
	IAPManager.purchase_started.connect(_on_purchase_started)
	IAPManager.purchase_succeeded.connect(_on_success)
	IAPManager.purchase_failed.connect(_on_failed)
	IAPManager.restore_finished.connect(_on_restore_done)
	IAPManager.busy_changed.connect(_on_busy_changed)
	_refresh_price()
	_set_busy(IAPManager.is_busy())
	resized.connect(_layout_sheet)
	_layout_sheet()


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
	button.material = null


func _style() -> void:
	if dim:
		dim.color = Color(0.0, 0.0, 0.0, 0.16)
		dim.z_index = 0
		dim.z_as_relative = true
	var empty := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", empty)
	panel.z_index = 2
	panel.z_as_relative = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if frame:
		var mat := ShaderMaterial.new()
		mat.shader = CHROMA
		frame.visible = true
		frame.material = mat
		frame.texture = FRAME_TEX
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.z_index = 0
		frame.z_as_relative = true
	if inner:
		inner.visible = false
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not has_node("CloseX"):
		_close_x = TextureButton.new()
		_close_x.name = "CloseX"
		_close_x.texture_normal = CLOSE_TEX
		_empty_tex_button(_close_x)
		_close_x.z_index = 3
		_close_x.z_as_relative = true
		_close_x.pressed.connect(_on_close)
		add_child(_close_x)
	else:
		_close_x = $CloseX
	if hero:
		hero.texture = HERO_TEX
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.custom_minimum_size = Vector2(0, 168)
		hero.show()
	if headline:
		headline.hide()
	if features:
		features.hide()
	if message_label:
		message_label.hide()
	if price_label:
		price_label.show()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 20)
		price_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
	_premium_cta(buy_button)
	_ghost_button(restore_button)
	close_button.hide()
	close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reset_button:
		_ghost_button(reset_button)
	if not has_node("Panel/VBox/TopPad"):
		var spacer := Control.new()
		spacer.name = "TopPad"
		spacer.custom_minimum_size = Vector2(0, 8)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vbox: VBoxContainer = $Panel/VBox
		vbox.add_child(spacer)
		vbox.move_child(spacer, 0)


func _premium_cta(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(216, 108)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.clip_contents = false
	if button.has_node("Plate"):
		_buy_plate = button.get_node("Plate")
	else:
		_buy_plate = TextureRect.new()
		_buy_plate.name = "Plate"
		button.add_child(_buy_plate)
		button.move_child(_buy_plate, 0)
	var mat := ShaderMaterial.new()
	mat.shader = CHROMA
	_buy_plate.material = mat
	_buy_plate.texture = PLATE_TEX
	_buy_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_buy_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_buy_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_plate.z_index = 0
	if button.has_node("Caption"):
		_buy_caption = button.get_node("Caption")
	else:
		_buy_caption = Label.new()
		_buy_caption.name = "Caption"
		button.add_child(_buy_caption)
	_buy_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_buy_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_caption.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	_buy_caption.add_theme_color_override("font_outline_color", Color(0.98, 0.86, 0.48, 0.35))
	_buy_caption.add_theme_constant_override("outline_size", 2)
	_buy_caption.add_theme_font_size_override("font_size", 22)
	_buy_caption.text = "Get Premium"
	if not button.button_down.is_connected(_on_buy_press_visual):
		button.button_down.connect(_on_buy_press_visual)
	if not button.button_up.is_connected(_on_buy_release_visual):
		button.button_up.connect(_on_buy_release_visual)
	_refresh_buy_visual()


func _ghost_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.10, 0.12, 0.88)
	box.set_corner_radius_all(14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.84, 0.70, 0.44, 0.45)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	button.add_theme_color_override("font_disabled_color", Color(0.90, 0.86, 0.76, 0.45))
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.flat = false


func _layout_sheet() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var card_w := minf(size.x * 0.86, 348.0)
	var card_h := minf(size.y * 0.80, 580.0)
	var hw := card_w * 0.5
	var hh := card_h * 0.5
	if frame:
		frame.visible = true
		frame.offset_left = -hw
		frame.offset_right = hw
		frame.offset_top = -hh
		frame.offset_bottom = hh
	var ix := card_w * 0.135
	var iy_t := card_h * 0.11
	var iy_b := card_h * 0.145
	panel.offset_left = -hw + ix + 6.0
	panel.offset_right = hw - ix - 6.0
	panel.offset_top = -hh + iy_t + 8.0
	panel.offset_bottom = hh - iy_b - 16.0
	if _close_x:
		var cs := 32.0
		_close_x.anchor_left = 0.0
		_close_x.anchor_top = 0.0
		_close_x.anchor_right = 0.0
		_close_x.anchor_bottom = 0.0
		_close_x.position = Vector2(size.x * 0.5 + hw - ix - cs - 4.0, size.y * 0.5 - hh + iy_t + 6.0)
		_close_x.size = Vector2(cs, cs)
	if hero:
		hero.custom_minimum_size = Vector2(0, clampf((card_h - iy_t - iy_b) * 0.40, 148.0, 200.0))


func show_paywall(_module_name: String = "") -> void:
	if reset_button:
		reset_button.visible = OS.has_feature("editor")
	if close_button:
		close_button.hide()
	_refresh_price()
	z_index = 200
	z_as_relative = false
	move_to_front()
	show()
	_opened_at_ms = Time.get_ticks_msec()
	_layout_sheet()
	await get_tree().process_frame
	_layout_sheet()


func _on_dim_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_at_ms < 280:
		return
	var tapped := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if tapped:
		_on_close()


func _refresh_price() -> void:
	if price_label:
		price_label.text = IAPManager.get_price_display()
	if OS.has_feature("editor") and not (OS.get_name() == "iOS"):
		status_label.text = ""
	elif IAPManager.is_price_ready():
		status_label.text = ""
	else:
		status_label.text = "Loading price from the App Store…"
	_update_buy_enabled()


func _update_buy_enabled() -> void:
	buy_button.disabled = IAPManager.is_busy() or not IAPManager.can_purchase()
	restore_button.disabled = IAPManager.is_busy()
	restore_button.visible = true
	_refresh_buy_visual()


func _refresh_buy_visual() -> void:
	if _buy_plate == null:
		return
	if buy_button.disabled:
		_buy_plate.modulate = Color(1, 1, 1, 0.42)
		if _buy_caption:
			_buy_caption.modulate = Color(1, 1, 1, 0.55)
	else:
		_buy_plate.modulate = Color.WHITE
		if _buy_caption:
			_buy_caption.modulate = Color.WHITE


func _on_buy_press_visual() -> void:
	if _buy_plate and not buy_button.disabled:
		_buy_plate.modulate = Color(0.86, 0.86, 0.86)


func _on_buy_release_visual() -> void:
	_refresh_buy_visual()


func _set_busy(is_busy: bool) -> void:
	_update_buy_enabled()
	close_button.disabled = false
	if is_busy:
		status_label.text = "Contacting the App Store…"


func _on_busy_changed(is_busy: bool) -> void:
	_set_busy(is_busy)


func _on_buy() -> void:
	if IAPManager.is_busy():
		return
	AnalyticsService.log_event("paywall_buy_tap", {"price": IAPManager.get_price_display()})
	IAPManager.purchase_lifetime()


func _on_restore() -> void:
	if IAPManager.is_busy():
		return
	AnalyticsService.log_event("paywall_restore_tap", {})
	IAPManager.restore_purchases()


func _on_close() -> void:
	hide()


func _on_reset_testing() -> void:
	EntitlementStore.reset_lifetime()
	status_label.text = "Unlock reset."
	show_paywall()


func _on_purchase_started() -> void:
	_set_busy(true)


func _on_success() -> void:
	_set_busy(false)
	status_label.text = "Thank you. Every module is unlocked."
	AnalyticsService.log_event("purchase", {"product_id": IAPManager.PRODUCT_LIFETIME})
	await get_tree().create_timer(0.9).timeout
	hide()


func _on_failed(msg: String) -> void:
	_set_busy(false)
	status_label.text = msg


func _on_products_failed(msg: String) -> void:
	_set_busy(false)
	status_label.text = msg
	_update_buy_enabled()


func _on_restore_done(success: bool) -> void:
	_set_busy(false)
	if success:
		status_label.text = "Purchases restored."
		await get_tree().create_timer(0.9).timeout
		hide()
	else:
		status_label.text = "No purchases found for this Apple ID."
