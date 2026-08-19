shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.14, 0.16, 0.20, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);

void fragment() {
	float v = UV.y;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, v);
	float vignette = smoothstep(0.95, 0.25, length(UV - vec2(0.5, 0.42)));
	col *= mix(0.55, 1.0, vignette);
	float grain = fract(sin(dot(UV * 740.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (grain - 0.5) * 0.02;
	COLOR = vec4(col, 1.0);
}
