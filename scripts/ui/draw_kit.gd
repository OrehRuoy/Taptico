class_name DrawKit
extends Object


static func rounded(canvas: CanvasItem, rect: Rect2, color: Color, radius: float = 10.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	canvas.draw_style_box(box, rect)
