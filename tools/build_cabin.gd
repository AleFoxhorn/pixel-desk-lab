extends SceneTree
## Rebuild the editable environment scene; contains no prop stand-ins.
var cabin: Node3D

func _initialize() -> void:
	call_deferred("build")

func material(hex: String, unlit: bool = true) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.roughness = 0.48
	if unlit:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func mesh_node(node_name: String, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	# Camera can see through the rear wall when inspecting the model from outside.
	node.layers = 2
	if node_name.begins_with("Desk") or node_name.begins_with("WoodGrain") or node_name == "RoseDesktop":
		node.layers = 1
	cabin.add_child(node)
	node.owner = cabin
	return node

func box(node_name: String, at: Vector3, dimensions: Vector3, hex: String, unlit: bool = true) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	return mesh_node(node_name, mesh, material(hex, unlit), at)

func polygon(node_name: String, points: PackedVector2Array, z: float, hex: String) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(Vector3(points[index].x, points[index].y, z))
	mesh_node(node_name, surface.commit(), material(hex))

func ribbon(node_name: String, points: PackedVector2Array, z: float, width: float, hex: String) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(points.size() - 1):
		var delta: Vector2 = (points[index + 1] - points[index]).normalized()
		var normal: Vector2 = Vector2(-delta.y, delta.x) * width * 0.5
		var a: Vector2 = points[index] + normal
		var b: Vector2 = points[index] - normal
		var c: Vector2 = points[index + 1] - normal
		var d: Vector2 = points[index + 1] + normal
		for vertex: Vector2 in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3(vertex.x, vertex.y, z))
	mesh_node(node_name, surface.commit(), material(hex))

func window_outline(center: Vector2, extent: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for index: int in range(97):
		var angle: float = TAU * float(index) / 96.0
		var x: float = cos(angle)
		var y: float = sin(angle)
		# Soft asymmetric superellipse echoes the swept reference window.
		var px: float = signf(x) * pow(absf(x), 0.78) * extent.x
		var py: float = signf(y) * pow(absf(y), 0.78) * extent.y
		result.append(center + Vector2(px + py * 0.22, py))
	return result

func build() -> void:
	cabin = Node3D.new()
	cabin.name = "CabinEnvironment"
	root.add_child(cabin)
	# The wall continues beyond all framing edges; its ribs rise into a curved roof.
	var wall: MeshInstance3D = box("BackWall", Vector3(0, 3.6, -3.0), Vector3(24, 10, 0.22), "50658e")
	var wall_finish: ShaderMaterial = ShaderMaterial.new()
	wall_finish.shader = load("res://shaders/cabin_finish.gdshader") as Shader
	wall.material_override = wall_finish
	for index: int in range(8):
		var curve: PackedVector2Array = []
		var stripe: PackedVector2Array = []
		var base: float = -10.0 + float(index) * 2.5
		for step: int in range(41):
			var y: float = -1.7 + float(step) * 0.25
			var x: float = base + 0.13 * pow(maxf(y - 1.2, 0.0), 2.0)
			curve.append(Vector2(x, y))
			stripe.append(Vector2(x + 0.11, y))
		ribbon("HullRib_%02d" % index, curve, -2.85, 0.035, "35466e")
		ribbon("HullRibHighlight_%02d" % index, stripe, -2.84, 0.065, "60759a")
	# Layered opaque aperture avoids stencil/depth dependencies in Compatibility.
	var center: Vector2 = Vector2(5.55, 3.55)
	polygon("WindowRecess", window_outline(center, Vector2(3.16, 2.97)), -2.72, "3c456b")
	polygon("WindowOuterFrame", window_outline(center, Vector2(3.04, 2.85)), -2.68, "8094b3")
	polygon("WindowPinkFrame", window_outline(center, Vector2(2.89, 2.70)), -2.64, "d9889f")
	polygon("WindowWarmLip", window_outline(center, Vector2(2.82, 2.63)), -2.60, "ffcf9f")
	polygon("DeepSpace", window_outline(center, Vector2(2.75, 2.56)), -2.56, "2c1d40")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8308
	for index: int in range(150):
		var local: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if pow(absf(local.x), 2.5) + pow(absf(local.y), 2.5) > 0.82:
			continue
		var point: Vector2 = center + Vector2(local.x * 2.75 + local.y * 2.56 * 0.22, local.y * 2.56)
		var radius: float = rng.randf_range(0.014, 0.025)
		if index % 17 == 0:
			radius = 0.12
			var star: PackedVector2Array = []
			for tip: int in range(8):
				var angle: float = TAU * float(tip) / 8.0
				var length: float = radius if tip % 2 == 0 else radius * 0.22
				star.append(point + Vector2(cos(angle) * length, sin(angle) * length * 1.5))
			polygon("Star_%03d" % index, star, -2.53, "fff0bb")
		else:
			box("Star_%03d" % index, Vector3(point.x, point.y, -2.53), Vector3(radius, radius, 0.008), "f6dbb0")
	# Empty architectural shelf. Books, planters and desktop objects arrive with models.
	var shelf: PackedVector2Array = []
	# Swept tapered front edge and concave integral supports, like the reference.
	for step: int in range(49):
		var t: float = float(step) / 48.0
		shelf.append(Vector2(-4.5 + t * 9.0, 5.48 + 0.18 * sin(t * PI)))
	for step: int in range(48, -1, -1):
		var t: float = float(step) / 48.0
		shelf.append(Vector2(-4.5 + t * 9.0, 5.38 + 0.14 * sin(t * PI)))
	polygon("ShelfCastShadow", shelf, -2.35, "35405f")
	polygon("SweptShelfFascia", shelf, -2.05, "d4829b")
	var shelf_lip: PackedVector2Array = []
	for step: int in range(49):
		var t: float = float(step) / 48.0
		shelf_lip.append(Vector2(-4.5 + t * 9.0, 5.48 + 0.18 * sin(t * PI)))
	ribbon("ShelfWarmLip", shelf_lip, -2.02, 0.028, "ffce9e")
	for x: float in [-3.3, 1.9]:
		var bracket: PackedVector2Array = []
		bracket.append(Vector2(x - 0.37, 5.45))
		bracket.append(Vector2(x + 0.37, 5.45))
		for step: int in range(13):
			var t: float = float(step) / 12.0
			bracket.append(Vector2(x + 0.37 * pow(1.0 - t, 2.0), 5.45 - t * 0.60))
		for step: int in range(12, -1, -1):
			var t: float = float(step) / 12.0
			bracket.append(Vector2(x - 0.37 * pow(1.0 - t, 2.0), 5.45 - t * 0.60))
		polygon("ShelfIntegralBracket_%s" % str(x), bracket, -2.06, "e6a19f")
	# Wide rose worktop leaves clear space for the later prop models.
	box("DeskApron", Vector3(0, 0.08, 1.05), Vector3(13.4, 0.40, 7.5), "784966")
	var top: MeshInstance3D = box("RoseDesktop", Vector3(0, 0.29, 1.05), Vector3(13.4, 0.07, 7.5), "cc7d96")
	var desk_finish: ShaderMaterial = ShaderMaterial.new()
	desk_finish.shader = wall_finish.shader
	desk_finish.set_shader_parameter("desktop", true)
	top.material_override = desk_finish
	box("DeskFrontInlay", Vector3(0, 0.325, 4.78), Vector3(13.42, 0.025, 0.035), "ffdaa3")
	box("DeskLeftInlay", Vector3(-6.66, 0.335, 1.05), Vector3(0.024, 0.008, 7.48), "f7c79d")
	box("DeskRightInlay", Vector3(6.66, 0.335, 1.05), Vector3(0.024, 0.008, 7.48), "f7c79d")
	# Keep a real opening for the editable drawer, including after environment rebuilds.
	box("DeskFrontPanelLeft", Vector3(-2.455, -0.30, 4.73), Vector3(8.29, 0.52, 0.08), "6d436b")
	box("DeskFrontPanelRight", Vector3(5.705, -0.30, 4.73), Vector3(1.79, 0.52, 0.08), "6d436b")
	for x: float in [-4.5, -2.0]:
		box("DeskPanelSeam_%s" % str(x), Vector3(x, -0.30, 4.79), Vector3(0.024, 0.52, 0.015), "493552")
	var warm: OmniLight3D = OmniLight3D.new()
	warm.name = "WarmDeskFill"
	warm.position = Vector3(-3.8, 3.2, 0.8)
	warm.light_color = Color("ffd09c")
	warm.light_energy = 0.35
	warm.omni_range = 8.0
	cabin.add_child(warm)
	warm.owner = cabin
	if FileAccess.file_exists("res://scenes/side_rack.tscn"):
		var rack_scene: PackedScene = load("res://scenes/side_rack.tscn") as PackedScene
		var rack: Node3D = rack_scene.instantiate() as Node3D
		rack.position = Vector3(-7.65, 0, -1.40)
		cabin.add_child(rack)
		rack.owner = cabin
	if FileAccess.file_exists("res://scenes/desk_drawer.tscn"):
		var drawer_scene: PackedScene = load("res://scenes/desk_drawer.tscn") as PackedScene
		var drawer: Node3D = drawer_scene.instantiate() as Node3D
		drawer.position = Vector3(3.25, -0.41, 4.76)
		cabin.add_child(drawer)
		drawer.owner = cabin
	if ResourceLoader.exists("res://models/hi3d/wall_shelf.glb"):
		for part: String in ["ShelfCastShadow", "SweptShelfFascia", "ShelfWarmLip", "ShelfIntegralBracket_-3_3", "ShelfIntegralBracket_1_9"]:
			(cabin.get_node(part) as Node3D).visible = false
	if ResourceLoader.exists("res://scenes/wall_poster.tscn"):
		var poster_scene: PackedScene = load("res://scenes/wall_poster.tscn") as PackedScene
		var poster: Node3D = poster_scene.instantiate() as Node3D
		cabin.add_child(poster)
		poster.owner = cabin
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(cabin) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/cabin_environment.tscn") == OK)
	print("CABIN_BUILD_OK: ", cabin.get_child_count(), " editable environment nodes")
	quit()
