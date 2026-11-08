// Banded diffuse and specular from the Godot skill toon template.
shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.7, 1.0);
uniform float bands : hint_range(2.0, 8.0) = 3.0;
uniform float band_softness : hint_range(0.0, 0.2) = 0.025;
uniform vec3 key_direction = vec3(-0.687, 0.559, 0.464);
uniform float light_plane_strength : hint_range(0.0, 0.6) = 0.32;

uniform float specular_strength : hint_range(0.0, 2.0) = 0.5;
uniform float specular_size : hint_range(0.0, 1.0) = 0.35;
uniform vec4 specular_color : source_color = vec4(1.0, 0.91, 0.72, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * vec3(0.66, 0.72, 0.94) * 0.20;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float light_plane = step(0.34, dot(world_normal, normalize(key_direction)));
	EMISSION += mix(ALBEDO, vec3(1.0, 0.85, 0.62), 0.20) * light_plane * light_plane_strength;
}

void light() {
	float lit = clamp(dot(normalize(NORMAL), normalize(LIGHT)) * ATTENUATION, 0.0, 1.0);
	float scaled = lit * bands;
	float band = (floor(scaled) + smoothstep(0.5 - band_softness * bands,
		0.5 + band_softness * bands, fract(scaled))) / bands;
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, ALBEDO * clamp(LIGHT_COLOR / PI, vec3(0.0), vec3(1.0)) * clamp(band, 0.0, 1.0) * 1.15);

	vec3 half_vector = normalize(normalize(VIEW) + normalize(LIGHT));
	float ndoth = clamp(dot(normalize(NORMAL), half_vector), 0.0, 1.0);
	float blob = pow(ndoth, mix(256.0, 4.0, specular_size));
	float highlight = smoothstep(0.22, 0.30, blob);
	SPECULAR_LIGHT += specular_color.rgb * LIGHT_COLOR * ATTENUATION *
		highlight * specular_strength * step(0.0, dot(NORMAL, LIGHT)) / PI;
}
