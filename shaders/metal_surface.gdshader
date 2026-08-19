shader_type canvas_item;

uniform vec3 light_dir = vec3(0.35, -0.75, 0.55);
uniform vec4 base_color : source_color = vec4(0.42, 0.46, 0.52, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.82, 0.85, 0.90, 1.0);
uniform vec4 rim_color : source_color = vec4(0.18, 0.20, 0.24, 1.0);
uniform float roughness = 0.28;
uniform float brushed = 0.35;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 n = normalize(vec3(p.x, p.y, mix(0.35, 1.1, 1.0 - r)));
	vec3 l = normalize(light_dir);
	float ndotl = clamp(dot(n, l), 0.0, 1.0);
	float spec = pow(max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0), mix(12.0, 72.0, 1.0 - roughness));
	float grain = fract(sin(dot(UV * vec2(180.0, 920.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 albedo = mix(rim_color.rgb, mix(base_color.rgb, highlight_color.rgb, ndotl), smoothstep(1.05, 0.15, r));
	albedo += (grain - 0.5) * brushed * 0.08;
	COLOR = vec4(albedo + spec * highlight_color.rgb * 0.55, COLOR.a);
}
