shader_type canvas_item;

uniform vec2 pointer = vec2(0.5, 0.5);
uniform float intensity = 0.35;
uniform vec4 deep : source_color = vec4(0.07, 0.09, 0.12, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.72, 0.82, 1.0);

void fragment() {
	vec2 uv = UV;
	float grid = 0.0;
	grid += smoothstep(0.02, 0.0, abs(fract(uv.x * 8.0) - 0.5));
	grid += smoothstep(0.02, 0.0, abs(fract(uv.y * 12.0) - 0.5));
	float d = distance(uv, pointer);
	float halo = exp(-d * 6.5) * intensity;
	vec3 col = mix(deep.rgb, glow.rgb, halo);
	col += vec3(0.12, 0.14, 0.16) * grid * 0.18;
	COLOR = vec4(col, 1.0);
}
