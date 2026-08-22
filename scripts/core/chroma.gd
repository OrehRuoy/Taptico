extends Node
## Keys #FF00FF into real alpha. Raw disk cache + mipmaps. Do not change the key test.

var _mem: Dictionary = {}
var _shader: Shader


func _ready() -> void:
	var d := DirAccess.open("user://")
	if d and not d.dir_exists("keyed"):
		d.make_dir("keyed")
	_shader = Shader.new()
	_shader.code = """shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float cut_top = 0.0;
uniform float cut_bottom = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (cut_top > 0.001 && UV.y < cut_top) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}
	if (cut_bottom > 0.001 && UV.y > 1.0 - cut_bottom) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}
	float mag = min(c.r, c.b) - c.g;
	if (c.r > 0.50 && c.b > 0.50 && c.g < 0.48 && mag > 0.10) {
		c.r = 0.0;
		c.g = 0.0;
		c.b = 0.0;
		c.a = 0.0;
	}
	COLOR = c;
}
"""


func mat(cut_top: float = 0.0, cut_bottom: float = 0.0) -> ShaderMaterial:
	if _shader == null:
		_ready()
	var m := ShaderMaterial.new()
	m.shader = _shader
	if cut_top > 0.0001:
		m.set_shader_parameter("cut_top", cut_top)
	if cut_bottom > 0.0001:
		m.set_shader_parameter("cut_bottom", cut_bottom)
	return m


func tex(src: Texture2D, cut_top: float = 0.0, punch_c: Vector2 = Vector2.ZERO, punch_r: float = 0.0, max_edge: int = 0, cut_bottom: float = 0.0) -> Texture2D:
	if src == null:
		return null
	var stamp := 0
	if not src.resource_path.is_empty() and FileAccess.file_exists(src.resource_path):
		stamp = int(FileAccess.get_modified_time(src.resource_path))
	var key := "v4_%s_%d_%.3f_%.3f_%.1f_%.1f_%.1f_%d" % [src.resource_path, stamp, cut_top, cut_bottom, punch_c.x, punch_c.y, punch_r, max_edge]
	if key.find("res://") < 0:
		key = "v4_rid_%s_%.3f_%.3f_%d" % [str(src.get_rid().get_id()), cut_top, cut_bottom, max_edge]
	if _mem.has(key):
		return _mem[key]
	var disk := "user://keyed/%s.bin" % _safe_name(key)
	var cached := _load_raw(disk)
	if cached:
		var tex_cached := ImageTexture.create_from_image(cached)
		_mem[key] = tex_cached
		return tex_cached
	var img := _read_image(src)
	if img == null:
		_mem[key] = src
		return src
	if max_edge > 0:
		var big: int = maxi(img.get_width(), img.get_height())
		if big > max_edge:
			var s: float = float(max_edge) / float(big)
			img.resize(maxi(2, int(img.get_width() * s)), maxi(2, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	_key_image(img, cut_top, punch_c, punch_r, cut_bottom)
	_save_raw(disk, img)
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_mem[key] = out
	return out


func apply(node: CanvasItem, src: Texture2D, cut_top: float = 0.0, max_edge: int = 0, cut_bottom: float = 0.0) -> Texture2D:
	var keyed := tex(src, cut_top, Vector2.ZERO, 0.0, max_edge, cut_bottom)
	if node is Sprite2D:
		(node as Sprite2D).texture = keyed
	elif node is TextureRect:
		(node as TextureRect).texture = keyed
	elif node is TextureButton:
		(node as TextureButton).texture_normal = keyed
	if keyed == src:
		node.material = mat(cut_top, cut_bottom)
	else:
		node.material = null
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return keyed


func punch(src: Texture2D, center_px: Vector2, radius_px: float) -> Texture2D:
	return tex(src, 0.0, center_px, radius_px)


func _safe_name(key: String) -> String:
	return key.replace("res://", "").replace("/", "_").replace(":", "_").replace(".", "_")


func _save_raw(path: String, img: Image) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_32(img.get_width())
	f.store_32(img.get_height())
	var data := img.get_data()
	f.store_32(data.size())
	f.store_buffer(data)


func _load_raw(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var w := int(f.get_32())
	var h := int(f.get_32())
	var n := int(f.get_32())
	if w < 1 or h < 1 or n < w * h * 4:
		return null
	var data := f.get_buffer(n)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	if img:
		img.generate_mipmaps()
	return img


func _read_image(src: Texture2D) -> Image:
	var img: Image = null
	if not src.resource_path.is_empty():
		img = Image.new()
		if img.load(src.resource_path) != OK:
			img = null
	if img == null:
		img = src.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		img.clear_mipmaps()
	return img


func _key_image(img: Image, cut_top: float, punch_c: Vector2, punch_r: float, cut_bottom: float = 0.0) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var expected := w * h * 4
	var data := img.get_data()
	if data.size() < expected:
		return
	var cut_y := int(float(h) * cut_top)
	var cut_y_bot := h
	if cut_bottom > 0.0001:
		cut_y_bot = int(float(h) * (1.0 - cut_bottom))
	var r2: float = punch_r * punch_r
	var do_punch: bool = punch_r > 1.0
	var do_cut: bool = cut_y > 0 or cut_y_bot < h or do_punch
	var i := 0
	var px := 0
	while i + 3 < expected:
		var r: int = data[i]
		var g: int = data[i + 1]
		var b: int = data[i + 2]
		var keyed: bool = r > 130 and b > 130 and g < 140 and (r + b - g - g) > 120
		if do_cut:
			var y: int = int(px / w)
			if y < cut_y or y >= cut_y_bot:
				keyed = true
			if do_punch:
				var x: int = px % w
				var dx: float = float(x) - punch_c.x
				var dy: float = float(y) - punch_c.y
				if dx * dx + dy * dy <= r2:
					keyed = true
		if keyed:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
			data[i + 3] = 0
		i += 4
		px += 1
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)
