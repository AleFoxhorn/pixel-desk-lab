// TextureRect post-process. Pixelation comes from the real low-resolution SubViewport.
// The ordered grid is evaluated in source pixels, before nearest-neighbour enlargement.
shader_type canvas_item;
render_mode unshaded;

uniform bool enabled = true;
uniform bool reference_style = true;
uniform bool dither_enabled = true;
uniform float dither_strength : hint_range(0.0, 0.15) = 0.045;
uniform float palette_strength : hint_range(0.0, 1.0) = 0.90;

const vec3 palette[25] = vec3[25](
	vec3(0.055,0.075,0.10), vec3(0.09,0.13,0.16), vec3(0.13,0.20,0.23),
	vec3(0.19,0.28,0.29), vec3(0.27,0.37,0.35), vec3(0.39,0.48,0.42),
	vec3(0.56,0.61,0.50), vec3(0.71,0.72,0.58), vec3(0.83,0.80,0.65),
	vec3(0.93,0.88,0.73), vec3(0.15,0.13,0.23), vec3(0.24,0.21,0.34),
	vec3(0.37,0.30,0.43), vec3(0.53,0.43,0.56), vec3(0.71,0.59,0.66),
	vec3(0.39,0.21,0.31), vec3(0.60,0.31,0.40), vec3(0.79,0.47,0.49),
	vec3(0.18,0.33,0.28), vec3(0.29,0.51,0.39), vec3(0.46,0.70,0.54),
	vec3(0.68,0.84,0.66), vec3(0.50,0.34,0.21), vec3(0.71,0.50,0.29),
	vec3(0.90,0.70,0.41)
);
const vec3 reference_palette[25] = vec3[25](
	vec3(0.1608,0.1255,0.2235),
	vec3(0.2431,0.1647,0.2824),
	vec3(0.3490,0.2118,0.3059),
	vec3(0.4863,0.2588,0.3725),
	vec3(0.6627,0.3294,0.4549),
	vec3(0.8078,0.4196,0.5333),
	vec3(0.8941,0.5451,0.6039),
	vec3(0.9569,0.6745,0.6667),
	vec3(1.0000,0.8118,0.6745),
	vec3(1.0000,0.9412,0.7333),
	vec3(0.1569,0.1922,0.2863),
	vec3(0.2196,0.2824,0.4000),
	vec3(0.2980,0.3765,0.5373),
	vec3(0.3843,0.4863,0.6431),
	vec3(0.5176,0.6039,0.7098),
	vec3(0.6745,0.7529,0.8000),
	vec3(0.0980,0.2627,0.2784),
	vec3(0.1412,0.3569,0.3569),
	vec3(0.2039,0.4745,0.4588),
	vec3(0.2980,0.5843,0.5059),
	vec3(0.4510,0.7020,0.5569),
	vec3(0.6431,0.8235,0.6314),
	vec3(0.8000,0.8980,0.6824),
	vec3(0.8510,0.6667,0.5137),
	vec3(0.9686,0.8510,0.6196)
);
const float bayer[16] = float[16](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,
	3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 rgb = source.rgb;
	if (enabled) {
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
		int index = (p.x % 4) + (p.y % 4) * 4;
		float threshold = (bayer[index] + 0.5) / 16.0 - 0.5;
		vec3 sample_color = clamp(rgb + threshold * dither_strength *
			(dither_enabled ? 1.0 : 0.0), vec3(0.0), vec3(1.0));
		float best_distance = 100.0;
		vec3 best = palette[0];
		for (int i = 0; i < 25; i++) {
			vec3 candidate = reference_style ? reference_palette[i] : palette[i];
			vec3 delta = sample_color - candidate;
			float distance = dot(delta * delta, vec3(0.30, 0.52, 0.18));
			if (distance < best_distance) {
				best_distance = distance;
				best = candidate;
			}
		}
		rgb = max(max(source.r, source.g), source.b) < 0.075 ? source.rgb : mix(source.rgb, best, palette_strength);
	}
	COLOR = vec4(rgb, source.a);
}
