// Inverted-hull pass adapted from the Godot outline_3d template.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.16, 0.12, 0.22, 1.0);
uniform float outline_width : hint_range(0.0, 0.05, 0.0001) = 0.002;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	if (outline_width <= 0.0) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
