// Aperture-bound adaptation of the bundled transparent hologram shader.
// Only the hard pixel lines contribute light; the underlying star field stays intact.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 grid_color : source_color = vec4(0.31, 0.94, 0.55, 1.0);
uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_time : hint_range(0.0, 0.65) = 0.0;
uniform vec2 pixel_resolution = vec2(320.0, 288.0);

void fragment() {
	vec2 pixel = floor(UV * pixel_resolution);
	vec2 uv = (pixel + vec2(0.5)) / pixel_resolution;
	vec2 local = uv * 2.0 - vec2(1.0);
	// The source aperture is sign(cos/sin)*abs(cos/sin)^.78, with x sheared by y*.22.
	// UV removes that shear, so this is the matching inverse superellipse equation.
	float aperture = pow(abs(local.x), 2.56410256) + pow(abs(local.y), 2.56410256);
	if (aperture > 0.985 || reveal_amount <= 0.0001) {
		discard;
	}
	float vertical = 1.0 - step(1.0, mod(pixel.x, 20.0));
	float horizontal = 1.0 - step(1.0, mod(pixel.y, 24.0));
	float major_x = 1.0 - step(1.0, mod(pixel.x, 80.0));
	float major_y = 1.0 - step(1.0, mod(pixel.y, 72.0));
	float grid = max(vertical, horizontal) * 0.42;
	grid = max(grid, max(major_x, major_y) * 0.68);

	// Four small L marks remain well inside the curved glass instead of touching its frame.
	vec2 distance_from_center = abs(pixel - floor(pixel_resolution * 0.5));
	vec2 corner_extent = floor(pixel_resolution * vec2(0.33, 0.32));
	float corner_horizontal = (1.0 - step(0.75, abs(distance_from_center.y - corner_extent.y)))
		* step(corner_extent.x - 12.0, distance_from_center.x) * step(distance_from_center.x, corner_extent.x);
	float corner_vertical = (1.0 - step(0.75, abs(distance_from_center.x - corner_extent.x)))
		* step(corner_extent.y - 12.0, distance_from_center.y) * step(distance_from_center.y, corner_extent.y);
	float corners = max(corner_horizontal, corner_vertical);
	float scan_y = floor(clamp(reveal_time / 0.60, 0.0, 1.0) * pixel_resolution.y);
	float scan = 1.0 - step(0.85, abs(pixel.y - scan_y));
	float lines = max(grid, max(corners, scan));
	ALBEDO = grid_color.rgb;
	ALPHA = lines * reveal_amount * grid_color.a * 0.82;
}
