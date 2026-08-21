shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float key_r = 1.0;
uniform float key_g = 0.0;
uniform float key_b = 1.0;
uniform float threshold = 0.22;
uniform float smoothness = 0.16;
uniform float circle_mask = 0.0;
uniform float circle_radius = 0.492;
uniform float circle_feather = 0.018;
uniform float cut_top = 0.0;

void fragment() {
	if (cut_top > 0.001 && UV.y < cut_top) {
		COLOR = vec4(0.0);
		return;
	}
	vec4 col = texture(TEXTURE, UV);
	vec3 keyc = vec3(key_r, key_g, key_b);
	float mag = min(col.r, col.b) - col.g;
	float dist = distance(col.rgb, keyc);
	float kill = 0.0;
	if (mag > 0.20 && min(col.r, col.b) > 0.42) {
		kill = smoothstep(0.20, 0.42, mag);
	}
	kill = max(kill, 1.0 - smoothstep(threshold, threshold + smoothness, dist));
	col.a *= 1.0 - kill;
	col.r = mix(col.r, col.g, kill * 0.65);
	col.b = mix(col.b, col.g, kill * 0.65);
	if (circle_mask > 0.5) {
		float d = distance(UV, vec2(0.5, 0.5));
		col.a *= 1.0 - smoothstep(circle_radius - circle_feather, circle_radius, d);
	}
	COLOR = col;
}
