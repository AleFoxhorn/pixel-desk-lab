// World-space projection adapted from the Godot triplanar template.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool desktop = false;
varying vec3 projection_position;

void vertex() {
	projection_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 p = projection_position;
	vec3 color;
	if (desktop) {
		float depth = smoothstep(-2.7, 4.9, p.z);
		color = mix(vec3(0.63, 0.29, 0.42), vec3(0.87, 0.43, 0.55), depth);
		float reflection = exp(-pow((p.x + 3.7) / 0.23, 2.0)) * 0.45;
		reflection += exp(-pow((p.x + 2.5) / 0.09, 2.0)) * 0.22;
		reflection += exp(-pow((p.x - 3.3) / 0.18, 2.0)) * 0.30;
		reflection += exp(-pow((p.x - 4.2) / 0.06, 2.0)) * 0.15;
		reflection *= 0.7 + 0.3 * hash(floor(p.xz * vec2(140.0, 30.0)));
		color = mix(color, vec3(1.0, 0.78, 0.53), reflection);
		float vignette = smoothstep(2.0, 7.5, abs(p.x)) * 0.08;
		color -= vec3(vignette);
	} else {
		float light = exp(-pow((p.x + 2.1) / 7.0, 2.0));
		float height = smoothstep(0.0, 7.5, p.y);
		color = mix(vec3(0.24, 0.32, 0.50), vec3(0.36, 0.46, 0.65), light);
		color *= 0.90 + height * 0.12;
	}
	vec2 grain_uv = desktop ? p.xz : p.xy;
	float grain = hash(floor(grain_uv * 160.0)) - 0.5;
	ALBEDO = clamp(color + grain * 0.032, vec3(0.0), vec3(1.0));
}
