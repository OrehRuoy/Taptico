shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec3 key_color : source_color = vec3(1.0, 0.0, 1.0);
uniform float threshold = 0.18;
uniform float smoothness = 0.07;
uniform float cut_top : hint_range(0.0, 0.12) = 0.052;

void fragment() {
	if (UV.y < cut_top) {
		COLOR = vec4(0.0);
		return;
	}
	vec4 col = texture(TEXTURE, UV);
	float mag = min(col.r, col.b) - col.g;
	float dist = distance(col.rgb, key_color);
	float kill = 0.0;
	if (mag > 0.20 && min(col.r, col.b) > 0.42) {
		kill = smoothstep(0.20, 0.42, mag);
	}
	kill = max(kill, 1.0 - smoothstep(threshold, threshold + smoothness, dist));
	col.a *= 1.0 - kill;
	if (kill > 0.34) {
		col.a = 0.0;
	}
	col.r = mix(col.r, col.g, kill * 0.55);
	col.b = mix(col.b, col.g, kill * 0.55);
	COLOR = col;
}
