class_name DrawKit
extends Object

const GOLD := Color(0.84, 0.70, 0.44)
const GOLD_HI := Color(0.96, 0.88, 0.62)
const GOLD_LO := Color(0.42, 0.32, 0.16)
const STEEL := Color(0.62, 0.64, 0.68)
const INK := Color(0.07, 0.07, 0.08)
const CHAR := Color(0.12, 0.12, 0.14)


static func rounded(canvas: CanvasItem, rect: Rect2, color: Color, radius: float = 10.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	canvas.draw_style_box(box, rect)


static func rim(canvas: CanvasItem, rect: Rect2, radius: float, fill: Color, border: Color, width: int = 2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.border_color = border
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	canvas.draw_style_box(box, rect)


static func circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center, radius, color)
