// Textured adaptation of the Godot toon template. Opaque, Compatibility-safe.
shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest_mipmap;
uniform float texture_posterize : hint_range(0.0, 1.0) = 0.55;
uniform float texture_levels : hint_range(3.0, 24.0) = 12.0;
uniform vec4 shadow_tint : source_color = vec4(0.86, 0.82, 0.94, 1.0);
uniform float halftone_strength : hint_range(0.0, 0.15) = 0.055;
varying float paper_dot;

void fragment() {
	vec3 base = albedo.rgb * texture(albedo_texture, UV).rgb;
	// Quantise perceptual colour gently; keep the source artwork and UV layout.
	vec3 perceptual = pow(max(base, vec3(0.0)), vec3(1.0 / 2.2));
	vec3 stepped = floor(perceptual * texture_levels + 0.5) / texture_levels;
	ALBEDO = mix(base, pow(stepped, vec3(2.2)), texture_posterize);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = ALBEDO * shadow_tint.rgb * 0.42;
	// Fixed four-source-pixel dots are used only by the two shadow steps below.
	vec2 cell = fract(FRAGCOORD.xy / 4.0) - vec2(0.5);
	paper_dot = 1.0 - step(0.18, length(cell));
}

void light() {
	float facing = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
	float lit = clamp(facing * ATTENUATION, 0.0, 1.0);
	float band = 0.12 + step(0.25, lit) * 0.22 + step(0.65, lit) * 0.30;
	band -= paper_dot * halftone_strength * (1.0 - step(0.65, lit));
	vec3 tint = clamp(LIGHT_COLOR / PI, vec3(0.0), vec3(1.0));
	// Dominant-light composition prevents the several desk fill lights stacking to white.
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, ALBEDO * tint * max(band, 0.0));
}
