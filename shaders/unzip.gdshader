shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float split_uv_y = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (UV.y < split_uv_y) {
		col.a = 0.0;
	}
	COLOR = col;
}
