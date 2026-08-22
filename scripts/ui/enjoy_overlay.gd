extends Control
## "Enjoying Taptico?" — Yes opens Apple's review sheet; No opens a Web3Forms note.

const FRAME_TEX := preload("res://assets/modules/paywall_frame.png")
const CLOSE_TEX := preload("res://assets/modules/btn_close_x.png")
const PLATE_TEX := preload("res://assets/modules/btn_gold_plate.png")

const WEB3FORMS_URL := "https://api.web3forms.com/submit"
const WEB3FORMS_KEY := "08be0cba-f088-4593-85d7-dff35e730241"
const FALLBACK_EMAIL := "noreply@taptico.app"

var _preview: bool = false
var _page: String = "ask"
var _busy: bool = false
var _opened_at_ms: int = 0

var _shell: Control
var _title: Label
var _close: TextureButton
var _scroll: ScrollContainer
var _col: VBoxContainer
var _ask_box: VBoxContainer
var _form_box: VBoxContainer
var _thanks_box: VBoxContainer
var _thanks_lab: Label
var _feedback: TextEdit
var _email: LineEdit
var _device_lab: Label
var _status: Label
var _send: Button
var _http: HTTPRequest


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 220
	z_as_relative = false
	_http = HTTPRequest.new()
	_http.timeout = 20
	_http.request_completed.connect(_on_http_done)
	add_child(_http)
	_build()
	resized.connect(_layout_card)


func present(preview: bool = false) -> void:
	_preview = preview
	_busy = false
	_page = "ask"
	_status.text = ""
	if _feedback:
		_feedback.text = ""
	if _email:
		_email.text = ""
	_device_lab.text = "Included with your note: %s" % EnjoyPrompt.device_summary()
	_show_page()
	show()
	move_to_front()
	_opened_at_ms = Time.get_ticks_msec()
	_layout_card()
	await get_tree().process_frame
	_layout_card()
	if not preview:
		AnalyticsService.log_event("enjoy_prompt_shown")
		AnalyticsService.log_screen("enjoy_prompt")


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

	var frame := TextureRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	Chroma.apply(frame, FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(frame)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58))
	_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.55))
	_title.add_theme_constant_override("outline_size", 3)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_title)

	_close = TextureButton.new()
	Chroma.apply(_close, CLOSE_TEX)
	_empty_tex_button(_close)
	_close.pressed.connect(_on_close)
	_shell.add_child(_close)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_shell.add_child(_scroll)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_col)

	_ask_box = VBoxContainer.new()
	_ask_box.add_theme_constant_override("separation", 12)
	var ask_sub := _muted_label("A quick yes or no helps a lot.")
	_ask_box.add_child(ask_sub)
	var yes := Button.new()
	_plate_button(yes, "Yes")
	yes.pressed.connect(_on_yes)
	_ask_box.add_child(yes)
	var no := Button.new()
	no.text = "Not really"
	_ghost_button(no)
	no.custom_minimum_size = Vector2(0, 44)
	no.pressed.connect(_on_no)
	_ask_box.add_child(no)
	_col.add_child(_ask_box)

	_form_box = VBoxContainer.new()
	_form_box.add_theme_constant_override("separation", 8)
	_form_box.add_child(_muted_label("What can we improve? Bugs, ideas, anything."))
	_feedback = TextEdit.new()
	_feedback.custom_minimum_size = Vector2(0, 118)
	_feedback.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_feedback.placeholder_text = "Your feedback"
	_style_field(_feedback)
	_form_box.add_child(_feedback)
	_email = LineEdit.new()
	_email.placeholder_text = "Email if you want a reply (optional)"
	_email.custom_minimum_size = Vector2(0, 40)
	_email.secret = false
	_style_line(_email)
	_form_box.add_child(_email)
	_device_lab = _muted_label("")
	_device_lab.add_theme_font_size_override("font_size", 11)
	_form_box.add_child(_device_lab)
	_status = _muted_label("")
	_status.add_theme_color_override("font_color", Color(0.93, 0.82, 0.58))
	_form_box.add_child(_status)
	_send = Button.new()
	_plate_button(_send, "Send")
	_send.custom_minimum_size = Vector2(0, 88)
	_send.pressed.connect(_on_send)
	_form_box.add_child(_send)
	_form_box.hide()
	_col.add_child(_form_box)

	_thanks_box = VBoxContainer.new()
	_thanks_box.add_theme_constant_override("separation", 10)
	_thanks_lab = Label.new()
	_thanks_lab.text = "Thanks — we got it."
	_thanks_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thanks_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thanks_lab.add_theme_font_size_override("font_size", 18)
	_thanks_lab.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
	_thanks_box.add_child(_thanks_lab)
	_thanks_box.hide()
	_col.add_child(_thanks_box)


func _show_page() -> void:
	_ask_box.visible = _page == "ask"
	_form_box.visible = _page == "form"
	_thanks_box.visible = _page == "thanks"
	match _page:
		"ask":
			_title.text = "Enjoying Taptico?"
		"form":
			_title.text = "Tell us what to fix"
		"thanks":
			_title.text = "Thank you"
	_send.disabled = _busy
	_layout_card()


func _on_yes() -> void:
	AudioFeel.play_tick(1.0)
	if not _preview:
		AnalyticsService.log_event("enjoy_prompt_yes")
		EnjoyPrompt.mark_completed()
	if OS.has_feature("editor"):
		_thanks_lab.text = "On iPhone this opens Apple’s review sheet.\nApple may hide it if you’ve already seen it recently."
		_page = "thanks"
		_show_page()
		await get_tree().create_timer(2.2).timeout
		if is_inside_tree():
			hide()
		return
	hide()
	IAPManager.request_review()


func _on_no() -> void:
	AudioFeel.play_tick(0.85)
	if not _preview:
		AnalyticsService.log_event("enjoy_prompt_no")
	_page = "form"
	_show_page()
	_feedback.grab_focus()


func _on_send() -> void:
	if _busy:
		return
	var note := _feedback.text.strip_edges()
	if note.length() < 4:
		_status.text = "A few more words would help."
		return
	var mail := _email.text.strip_edges()
	if not mail.is_empty() and not _email_ok(mail):
		_status.text = "That email doesn’t look right."
		return
	AudioFeel.play_tick(1.0)
	_busy = true
	_status.text = "Sending…"
	_show_page()
	var wants_reply := not mail.is_empty()
	var snap := EnjoyPrompt.device_snapshot()
	var details := "\n\n---\nDevice: %s\nOS: %s %s\nApp: Taptico %s\nScreen: %s\nLocale: %s\nWants reply: %s" % [
		str(snap.model), str(snap.os), str(snap.os_version), str(snap.app_version),
		str(snap.screen), str(snap.locale), "yes" if wants_reply else "no (no email given)",
	]
	var payload := {
		"access_key": WEB3FORMS_KEY,
		"subject": "Taptico feedback",
		"from_name": "Taptico",
		"name": "Taptico user",
		"email": mail if wants_reply else FALLBACK_EMAIL,
		"message": note + details,
		"app_version": str(snap.app_version),
		"device": str(snap.model),
		"os": "%s %s" % [snap.os, snap.os_version],
		"screen": str(snap.screen),
		"locale": str(snap.locale),
		"godot": str(snap.godot),
		"wants_reply": "yes" if wants_reply else "no",
		"build": "editor" if bool(snap.editor) else ("debug" if bool(snap.debug) else "release"),
	}
	if wants_reply:
		payload["replyto"] = mail
	var body := JSON.stringify(payload)
	var err := _http.request(
		WEB3FORMS_URL,
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		_busy = false
		_status.text = "Could not send. Check your connection."
		_show_page()


func _on_http_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var text := body.get_string_from_utf8()
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if ok:
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and parsed.has("success"):
			ok = bool(parsed["success"])
	if not ok:
		_status.text = "Could not send. Try again in a moment."
		_show_page()
		return
	if not _preview:
		AnalyticsService.log_event("feedback_sent")
		EnjoyPrompt.mark_completed()
	_thanks_lab.text = "Thanks — we got it."
	_page = "thanks"
	_show_page()
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree():
		hide()


func _on_close() -> void:
	if _busy:
		_http.cancel_request()
		_busy = false
	if _page == "form":
		if not _preview:
			EnjoyPrompt.mark_completed()
	elif _page == "ask":
		if not _preview:
			EnjoyPrompt.snooze_today()
	hide()


func _on_dim(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_at_ms < 280:
		return
	if _page == "form":
		return
	var tapped := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if tapped:
		_on_close()


func _email_ok(value: String) -> bool:
	if not value.contains("@") or not value.contains("."):
		return false
	var at := value.find("@")
	return at > 0 and at < value.length() - 3


func _layout_card() -> void:
	if _shell == null or size.x < 8.0:
		return
	var pad := 16.0
	var shell_w := minf(size.x - pad * 2.0, 392.0)
	var shell_h := minf(size.y - pad * 2.0, 680.0)
	var ix := shell_w * 0.135
	var iy_t := shell_h * 0.11
	var iy_b := shell_h * 0.10
	var inner_w := shell_w - ix * 2.0
	var inner_h := shell_h - iy_t - iy_b
	var header_h := 58.0
	var close_s := 32.0
	_col.custom_minimum_size = Vector2(inner_w - 6.0, 0.0)
	var content_h := _col.get_combined_minimum_size().y + 12.0
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
	_title.size = Vector2(inner_w - close_s - 6.0, header_h)
	_close.position = Vector2(ix + inner_w - close_s - 2.0, iy_t + 6.0)
	_close.size = Vector2(close_s, close_s)
	_scroll.position = Vector2(ix + 4.0, iy_t + header_h + 6.0)
	_scroll.size = Vector2(inner_w - 8.0, body_h)


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


func _plate_button(button: Button, caption: String) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plate := TextureRect.new()
	plate.name = "Plate"
	Chroma.apply(plate, PLATE_TEX)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate)
	var lab := Label.new()
	lab.name = "Caption"
	lab.text = caption
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	lab.add_theme_color_override("font_outline_color", Color(0.98, 0.86, 0.48, 0.35))
	lab.add_theme_constant_override("outline_size", 2)
	lab.add_theme_font_size_override("font_size", 22)
	button.add_child(lab)


func _ghost_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.10, 0.12, 0.88)
	box.set_corner_radius_all(14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.84, 0.70, 0.44, 0.45)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _style_field(edit: TextEdit) -> void:
	var box := _field_box()
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	edit.add_theme_color_override("caret_color", Color(0.93, 0.82, 0.55))
	edit.add_theme_font_size_override("font_size", 15)


func _style_line(edit: LineEdit) -> void:
	var box := _field_box()
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	edit.add_theme_color_override("font_placeholder_color", Color(0.70, 0.66, 0.56, 0.8))
	edit.add_theme_font_size_override("font_size", 15)
	edit.caret_blink = true


func _field_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.08, 0.96)
	box.set_corner_radius_all(12)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.84, 0.70, 0.44, 0.55)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _muted_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.78, 0.80, 0.82))
	return lab
