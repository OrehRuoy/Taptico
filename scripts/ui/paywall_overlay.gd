extends Control

const FRAME_TEX := preload("res://assets/modules/paywall_frame.png")
const HERO_TEX := preload("res://assets/modules/paywall_hero.png")
const BTN_TEX := preload("res://assets/modules/btn_unlock.png")
const CHROMA := preload("res://shaders/chroma_key.gdshader")

@onready var price_label: Label = $Panel/VBox/PriceLabel
@onready var buy_button: TextureButton = $Panel/VBox/BuyButton
@onready var restore_button: Button = $Panel/VBox/Actions/RestoreButton
@onready var close_button: Button = $Panel/VBox/Actions/CloseButton
@onready var reset_button: Button = $Panel/VBox/Actions/ResetButton
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var headline: Label = $Panel/VBox/Headline
@onready var features: Label = $Panel/VBox/Features
@onready var hero: TextureRect = $Panel/VBox/Hero
@onready var frame: TextureRect = $Frame


func _ready() -> void:
	hide()
	_style()
	buy_button.pressed.connect(_on_buy)
	restore_button.pressed.connect(_on_restore)
	close_button.pressed.connect(_on_close)
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


func _style() -> void:
	var empty := StyleBoxEmpty.new()
	$Panel.add_theme_stylebox_override("panel", empty)
	var mat := ShaderMaterial.new()
	mat.shader = CHROMA
	if frame:
		frame.material = mat
		frame.texture = FRAME_TEX
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hero:
		hero.texture = HERO_TEX
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.custom_minimum_size = Vector2(0, 200)
	if has_node("Inner"):
		$Inner.color = Color(0, 0, 0, 1)
		$Inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame:
		frame.z_index = 4
	if features:
		features.hide()
	if headline:
		headline.hide()
	if message_label:
		message_label.hide()
	if has_node("Panel/VBox/Logo"):
		$Panel/VBox/Logo.hide()
	if has_node("Panel/VBox/Kicker"):
		$Panel/VBox/Kicker.hide()
	if price_label:
		price_label.show()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.58))
	buy_button.texture_normal = BTN_TEX
	buy_button.ignore_texture_size = true
	buy_button.stretch_mode = TextureButton.STRETCH_SCALE
	buy_button.custom_minimum_size = Vector2(200, 44)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ghost_button(restore_button)
	_ghost_button(close_button)
	if reset_button:
		_ghost_button(reset_button)


func _gold_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.72, 0.58, 0.32, 1)
	box.set_corner_radius_all(14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.93, 0.82, 0.55, 0.95)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	var hover := box.duplicate()
	hover.bg_color = Color(0.80, 0.66, 0.38, 1)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.88))
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


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
	button.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size = Vector2(200, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func show_paywall(_module_name: String = "") -> void:
	if reset_button:
		reset_button.visible = OS.has_feature("editor")
	_refresh_price()
	z_index = 120
	z_as_relative = false
	move_to_front()
	show()


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
