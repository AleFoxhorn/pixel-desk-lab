extends Node3D
## A brief diagnostic overlay on the existing star window; no input or camera ownership.
const REVEAL_SHADER: Shader = preload("res://shaders/window_reveal.gdshader")
const CENTER: Vector2 = Vector2(5.55, 3.55)
const EXTENT: Vector2 = Vector2(2.75, 2.56)
const DURATION: float = 0.60
var effect_active: bool = false
var material: ShaderMaterial
var overlay_mesh: MeshInstance3D
var motion: Tween = null

func setup(cabin: Node3D) -> void:
	if overlay_mesh != null:
		return
	var outline: PackedVector2Array = PackedVector2Array()
	var uv_points: PackedVector2Array = PackedVector2Array()
	for index: int in range(96):
		var angle: float = TAU * float(index) / 96.0
		var x: float = cos(angle)
		var y: float = sin(angle)
		var px: float = signf(x) * pow(absf(x), 0.78) * EXTENT.x
		var py: float = signf(y) * pow(absf(y), 0.78) * EXTENT.y
		outline.append(CENTER + Vector2(px + py * 0.22, py))
		uv_points.append(Vector2(px / EXTENT.x, py / EXTENT.y) * 0.5 + Vector2(0.5, 0.5))
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	assert(indices.size() == (outline.size() - 2) * 3, "Window diagnostic must cover the aperture without degenerate triangles")
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		surface.set_normal(Vector3.BACK)
		surface.set_uv(uv_points[index])
		surface.add_vertex(Vector3(outline[index].x, outline[index].y, -2.49))
	overlay_mesh = MeshInstance3D.new()
	overlay_mesh.name = "DigitalWindowReveal"
	overlay_mesh.mesh = surface.commit()
	overlay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass: MeshInstance3D = cabin.get_node_or_null("DeepSpace") as MeshInstance3D
	overlay_mesh.layers = glass.layers if glass != null else 2
	material = ShaderMaterial.new()
	material.shader = REVEAL_SHADER
	material.render_priority = 1
	overlay_mesh.material_override = material
	cabin.add_child(overlay_mesh)
	stop()

func trigger() -> void:
	if material == null or overlay_mesh == null:
		return
	if motion != null and motion.is_valid():
		motion.kill()
	effect_active = true
	overlay_mesh.show()
	_set_frame(0.0)
	motion = create_tween()
	motion.tween_method(_set_frame, 0.0, DURATION, DURATION)
	motion.tween_callback(stop)

func _set_frame(elapsed: float) -> void:
	var amount: float = 0.0
	if elapsed < 0.035:
		amount = elapsed / 0.035
	elif elapsed < 0.11:
		amount = 1.0
	elif elapsed < 0.19:
		amount = lerpf(1.0, 0.06, (elapsed - 0.11) / 0.08)
	elif elapsed < 0.24:
		amount = 0.06
	elif elapsed < 0.275:
		amount = lerpf(0.06, 0.9, (elapsed - 0.24) / 0.035)
	elif elapsed < 0.36:
		amount = 0.9
	else:
		amount = 0.9 * (1.0 - clampf((elapsed - 0.36) / 0.24, 0.0, 1.0))
	material.set_shader_parameter("reveal_amount", amount)
	material.set_shader_parameter("reveal_time", elapsed)

func stop() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	motion = null
	effect_active = false
	if material != null:
		material.set_shader_parameter("reveal_amount", 0.0)
		material.set_shader_parameter("reveal_time", 0.0)
	if overlay_mesh != null:
		overlay_mesh.hide()
