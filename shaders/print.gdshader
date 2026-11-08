// A second pass after palette mapping; UI is drawn afterwards and stays sharp.
// Gaussian taps adapted from the Godot skill blur template.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.18;
uniform vec2 image_scale = vec2(1.0);

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - 0.5;
	vec2 warped = UV + centered * dot(centered, centered) * 0.018 * strength;
	warped.x += sin(UV.y * 112.0) * 0.00045 * strength;
	vec2 uv = SCREEN_UV + (warped - UV) * image_scale;
	vec2 lo = SCREEN_UV - UV * image_scale;
	vec2 hi = lo + image_scale;
	vec2 px = SCREEN_PIXEL_SIZE * max(strength, 0.001);
	vec3 soft = vec3(0.0);
	float weights = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 delta = vec2(float(x), float(y));
			float weight = exp(-dot(delta, delta) / 1.1);
			soft += texture(screen_texture, clamp(uv + delta * px * 1.3, lo, hi)).rgb * weight;
			weights += weight;
		}
	}
	soft /= weights;
	// Small red/cyan registration error, like ink plates on aged paper.
	vec3 offset_color = vec3(
		texture(screen_texture, clamp(uv + vec2(px.x * 1.1, 0.0), lo, hi)).r,
		soft.g,
		texture(screen_texture, clamp(uv - vec2(px.x * 0.8, 0.0), lo, hi)).b);
	vec3 ink = mix(soft, offset_color, 0.30);
	float luminance = dot(ink, vec3(0.299, 0.587, 0.114));
	ink = mix(ink, vec3(luminance), 0.12 * strength);
	ink = mix(ink, vec3(0.81, 0.74, 0.61), 0.055 * strength);
	vec2 paper_pixel = floor(FRAGCOORD.xy / 1.3);
	float fiber = grain(paper_pixel) - 0.5;
	float mottling = grain(floor(FRAGCOORD.xy / 7.0)) - 0.5;
	ink += (fiber * 0.085 + mottling * 0.018) * strength;
	vec3 sharp = texture(screen_texture, SCREEN_UV).rgb;
	vec3 filtered = mix(sharp, clamp(ink, vec3(0.0), vec3(1.0)), min(strength, 1.0));
	// Soft elliptical vignette, applied after the blur blend so the light preset stays visible.
	float edge_fade = smoothstep(0.26, 0.72, length(centered));
	filtered *= 1.0 - edge_fade * vignette_strength * clamp(strength / 0.45, 0.0, 1.0);
	COLOR = vec4(filtered, 1.0);
}
