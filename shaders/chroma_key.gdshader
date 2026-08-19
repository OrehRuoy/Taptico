shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec3 key_color : source_color = vec3(1.0, 0.0, 1.0);
uniform float threshold = 0.22;
uniform float smoothness = 0.16;
uniform float circle_mask : hint_range(0.0, 1.0) = 0.0;
uniform float circle_radius : hint_range(0.35, 0.55) = 0.492;
uniform float circle_feather : hint_range(0.0, 0.08) = 0.018;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float mag = min(col.r, col.b) - col.g;
	float dist = distance(col.rgb, key_color);
	float kill = 0.0;
	if (mag > 0.20 && min(col.r, col.b) > 0.42) {
		kill = smoothstep(0.20, 0.42, mag);
	}
	kill = max(kill, 1.0 - smoothstep(threshold, threshold + smoothness, dist));
	col.a *= 1.0 - kill;
	col.r = mix(col.r, col.g, kill * 0.65);
	col.b = mix(col.b, col.g, kill * 0.65);
	if (circle_mask > 0.5) {
		float d = distance(UV, vec2(0.5));
		col.a *= 1.0 - smoothstep(circle_radius - circle_feather, circle_radius, d);
	}
	COLOR = col;
}
