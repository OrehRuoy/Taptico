class_name TexClean
extends Object
## Fast outer magenta key. Interior magenta becomes solid fill so holes don't show through.


static func outer_key_and_fill(src: Texture2D, fill: Color = Color(0.09, 0.09, 0.10, 1.0), max_edge: int = 512) -> Texture2D:
	if src == null:
		return src
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if maxi(w, h) > max_edge:
		var s := float(max_edge) / float(maxi(w, h))
		img.resize(maxi(2, int(w * s)), maxi(2, int(h * s)), Image.INTERPOLATE_LANCZOS)
		w = img.get_width()
		h = img.get_height()
	var outer: Dictionary = {}
	var q: Array[Vector2i] = []
	for x in w:
		_try_seed(img, x, 0, q, outer)
		_try_seed(img, x, h - 1, q, outer)
	for y in h:
		_try_seed(img, 0, y, q, outer)
		_try_seed(img, w - 1, y, q, outer)
	var i := 0
	while i < q.size():
		var p: Vector2i = q[i]
		i += 1
		_try_seed(img, p.x - 1, p.y, q, outer)
		_try_seed(img, p.x + 1, p.y, q, outer)
		_try_seed(img, p.x, p.y - 1, q, outer)
		_try_seed(img, p.x, p.y + 1, q, outer)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if not _is_magenta(c):
				continue
			if outer.has(Vector2i(x, y)):
				c.a = 0.0
			else:
				c = fill
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func crop_alpha(src: Texture2D, pad: int = 2) -> Texture2D:
	if src == null:
		return src
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.08:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < x0:
		return src
	x0 = maxi(0, x0 - pad)
	y0 = maxi(0, y0 - pad)
	x1 = mini(w - 1, x1 + pad)
	y1 = mini(h - 1, y1 + pad)
	return ImageTexture.create_from_image(img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)))


static func _try_seed(img: Image, x: int, y: int, q: Array[Vector2i], outer: Dictionary) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var p := Vector2i(x, y)
	if outer.has(p):
		return
	if not _is_magenta(img.get_pixel(x, y)):
		return
	outer[p] = true
	q.append(p)


static func _is_magenta(c: Color) -> bool:
	return c.r > 0.42 and c.b > 0.42 and c.g < minf(c.r, c.b) * 0.72 and (minf(c.r, c.b) - c.g) > 0.16


static func strip_magenta(src: Texture2D, _circular_shrink_px: float = 0.0, _erode_passes: int = 2) -> Texture2D:
	return outer_key_and_fill(src)
