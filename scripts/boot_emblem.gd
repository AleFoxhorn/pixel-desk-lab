extends Control
## Full-display emblem drawn on a fixed pixel grid, including the moving satellite.
var progress: float = 0.0

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = (size * Vector2(0.54, 0.51)).round()
	var scale_factor: float = minf(size.x / 1000.0, size.y / 500.0)
	draw_set_transform(center)
	var green: Color = Color("9bcea8")
	var orbit: PackedVector2Array = []
	for index: int in range(97):
		var angle: float = TAU * float(index) / 96.0
		orbit.append((Vector2(cos(angle) * 185.0, sin(angle) * 68.0).rotated(-0.32) * scale_factor).round())
	draw_polyline(orbit, Color("416b4e"), maxf(1.0, roundf(12.0 * scale_factor)), false)
	draw_polyline(orbit, green, maxf(1.0, roundf(4.0 * scale_factor)), false)
	var star: PackedVector2Array = PackedVector2Array([
		Vector2(0, -119), Vector2(18, -23), Vector2(94, 0), Vector2(18, 23),
		Vector2(0, 119), Vector2(-18, 23), Vector2(-94, 0), Vector2(-18, -23)])
	for index: int in range(star.size()):
		star[index] = (star[index] * scale_factor).round()
	draw_colored_polygon(star, green)
	var satellite_angle: float = -0.5 + progress * 1.1
	var satellite: Vector2 = (Vector2(cos(satellite_angle) * 185.0, sin(satellite_angle) * 68.0).rotated(-0.32) * scale_factor).round()
	draw_circle(satellite, maxf(1.0, roundf(17.0 * scale_factor)), Color("416b4e"))
	draw_circle(satellite, maxf(1.0, roundf(10.0 * scale_factor)), Color("c0ecc0"))
