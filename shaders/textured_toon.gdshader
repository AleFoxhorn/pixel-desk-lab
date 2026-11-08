// Textured adaptation of the Godot toon template. Opaque, Compatibility-safe.
shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest_mipmap;
uniform float texture_posterize : hint_range(0.0, 1.0) = 0.55;
uniform float texture_levels : hint_range(3.0, 24.0) = 12.0;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.72, 0.94, 1.0);
uniform float halftone_strength : hint_range(0.0, 0.15) = 0.055;
// Match the left key; preserve a readable light plane even under prop occlusion.
uniform vec3 key_direction = vec3(-0.687, 0.559, 0.464);
uniform float light_plane_strength : hint_range(0.0, 0.6) = 0.32;
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
	EMISSION = ALBEDO * shadow_tint.rgb * 0.20;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float light_plane = step(0.34, dot(world_normal, normalize(key_direction)));
	vec3 light_color = mix(ALBEDO, vec3(1.0, 0.85, 0.62), 0.20);
	EMISSION += light_color * light_plane * light_plane_strength;
	// Fixed four-source-pixel dots are used only by the two shadow steps below.
	vec2 cell = fract(FRAGCOORD.xy / 4.0) - vec2(0.5);
	paper_dot = 1.0 - step(0.18, length(cell));
}

void light() {
	float facing = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
	float lit = clamp(facing * ATTENUATION, 0.0, 1.0);
	// A broad shadow, a decisive light plane, then a small highlight plane.
	float band = step(0.32, lit) * 0.96 + step(0.76, lit) * 0.14;
	band *= 1.0 - paper_dot * halftone_strength * (1.0 - step(0.76, lit));
	vec3 tint = clamp(LIGHT_COLOR / PI, vec3(0.0), vec3(1.0));
	// Dominant-light composition prevents the several desk fill lights stacking to white.
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, ALBEDO * tint * max(band, 0.0));
}
