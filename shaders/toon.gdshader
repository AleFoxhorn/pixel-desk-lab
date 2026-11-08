// Banded diffuse and specular from the Godot skill toon template.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.7, 1.0);
uniform float bands : hint_range(2.0, 8.0) = 3.0;
uniform float band_softness : hint_range(0.0, 0.2) = 0.025;

uniform float specular_strength : hint_range(0.0, 2.0) = 0.5;
uniform float specular_size : hint_range(0.0, 1.0) = 0.35;
uniform vec4 specular_color : source_color = vec4(1.0, 0.91, 0.72, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.0;
}

void light() {
	float lit = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
	float scaled = lit * bands;
	float band = (floor(scaled) + smoothstep(0.5 - band_softness * bands,
		0.5 + band_softness * bands, fract(scaled))) / bands;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * clamp(band, 0.0, 1.0) / PI;

	vec3 half_vector = normalize(normalize(VIEW) + normalize(LIGHT));
	float ndoth = clamp(dot(normalize(NORMAL), half_vector), 0.0, 1.0);
	float blob = pow(ndoth, mix(256.0, 4.0, specular_size));
	float highlight = smoothstep(0.22, 0.30, blob);
	SPECULAR_LIGHT += specular_color.rgb * LIGHT_COLOR * ATTENUATION *
		highlight * specular_strength * step(0.0, dot(NORMAL, LIGHT)) / PI;
}
