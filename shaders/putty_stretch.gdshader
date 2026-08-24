shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float stretch : hint_range(0.0, 1.0) = 0.0;
uniform float neck : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float s = clamp(stretch, 0.0, 1.0);
	vec2 uv = UV;
	vec4 c = texture(TEXTURE, uv);
	if (c.a < 0.40) {
		vec2 inward = mix(uv, vec2(0.5), 0.62);
		c = texture(TEXTURE, inward);
	}
	c.a = 1.0;
	float gray = dot(c.rgb, vec3(0.30, 0.48, 0.22));
	c.rgb = mix(c.rgb, vec3(gray), 0.22);
	c.rgb *= vec3(0.90, 0.92, 0.94);
	float u = UV.x * 2.0 - 1.0;
	float v = UV.y * 2.0 - 1.0;
	float rim = smoothstep(0.62, 1.0, length(vec2(u, v)));
	c.rgb *= 1.0 - rim * 0.16;
	c.rgb += vec3(0.10, 0.11, 0.12) * s * rim;
	COLOR = c;
}
