class_name TextFit
extends RefCounted
## Shrinks a Label's font so translated text fits its box. English is never touched,
## so the shipped English layout stays pixel-identical.
## Usage: TextFit.fit(label, 14)            # single line, width = label.size.x
##        TextFit.fit(label, 13, 0.75, 220) # explicit max width (e.g. nav chip)
## Multi-line (autowrap) labels: also fits height when label.size.y > 0.

const MIN_SCALE := 0.75


static func fit(label: Label, base_size: int, min_scale: float = MIN_SCALE, max_width: float = -1.0) -> void:
	if label == null or not is_instance_valid(label):
		return
	if TranslationServer.get_locale() == "en":
		return
	var font := label.get_theme_font("font")
	var width := max_width if max_width > 0.0 else label.size.x
	if font == null or width <= 0.0:
		return
	var min_size := maxi(8, int(floor(base_size * min_scale)))
	var size := base_size
	var wrap := label.autowrap_mode != TextServer.AUTOWRAP_OFF
	while size > min_size:
		var fits := true
		if wrap:
			var h := font.get_multiline_string_size(label.text, label.horizontal_alignment, width, size).y
			fits = label.size.y <= 0.0 or h <= label.size.y
		else:
			for part in label.text.split("\n"):
				if font.get_string_size(part, label.horizontal_alignment, -1, size).x > width:
					fits = false
					break
		if fits:
			break
		size -= 1
	label.add_theme_font_size_override("font_size", size)
	if size <= min_size and not wrap:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true


static func fit_button(button: Button, base_size: int, min_scale: float = MIN_SCALE) -> void:
	if button == null or TranslationServer.get_locale() == "en":
		return
	var font := button.get_theme_font("font")
	if font == null:
		return
	var inner := button.size.x - 16.0
	if inner <= 0.0:
		return
	var size := base_size
	var min_size := maxi(8, int(floor(base_size * min_scale)))
	while size > min_size and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x > inner:
		size -= 1
	button.add_theme_font_size_override("font_size", size)
