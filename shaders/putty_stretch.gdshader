shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float stretch : hint_range(0.0, 1.0) = 0.0;
uniform float neck : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float s = clamp(max(stretch, neck * 0.92), 0.0, 1.0);
	float n = clamp(neck, 0.0, 1.0);
	float u = UV.x * 2.0 - 1.0;
	float v = UV.y * 2.0 - 1.0;
	float mid = 1.0 - u * u;
	vec2 uv = UV;
	uv.x = 0.5 + (UV.x - 0.5) * mix(1.0, 0.70, s);
	float v_scale = mix(1.0, mix(1.45, 0.62, u * u), s);
	v_scale *= mix(1.0, mix(1.7, 0.35, u * u), n);
	uv.y = 0.5 + (UV.y - 0.5) * v_scale;
	uv.y += s * 0.035 * sin(UV.x * 26.0) * mid;
	uv.x += s * 0.018 * sin(UV.y * 18.0 + u * 4.0) * mid;
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec4 c = texture(TEXTURE, uv);
	float thin = (s * 0.55 + n * 0.7) * mid;
	c.rgb *= 1.0 - thin * 0.34;
	float rim = smoothstep(0.42, 0.88, abs(v));
	c.rgb += vec3(0.22, 0.14, 0.05) * s * rim * (0.35 + 0.65 * u * u);
	c.rgb += vec3(0.08, 0.04, 0.01) * thin * (1.0 - rim);
	COLOR = c;
}
