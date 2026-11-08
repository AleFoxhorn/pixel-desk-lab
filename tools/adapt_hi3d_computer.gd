extends SceneTree
## Fit the existing interactive display to the imported computer's green glass.

func _initialize() -> void:
	var scene: Node3D = load("res://scenes/desk_world.tscn").instantiate() as Node3D
	var imported: MeshInstance3D = scene.get_node("GeneratedProps/Computer/Model/world/geometry_0") as MeshInstance3D
	var bounds: AABB = _glass_bounds(imported, scene)
	assert(bounds.size.x > 2.0 and bounds.size.y > 1.0, "Could not identify the imported display glass")
	var computer: Node3D = scene.get_node("Computer") as Node3D
	var legacy_keyboard: Node3D = computer.get_node("Keyboard") as Node3D
	var holder: Node3D = scene.get_node("GeneratedProps/Computer") as Node3D
	var model: Node3D = holder.get_node("Model") as Node3D
	var world: Node3D = model.get_node("world") as Node3D
	var full_bounds: AABB = (holder.transform * model.transform * world.transform * imported.transform) * imported.get_aabb()
	var housing: MeshInstance3D = computer.get_node("Housing") as MeshInstance3D
	var view_box: BoxMesh = BoxMesh.new()
	view_box.size = full_bounds.size
	housing.mesh = view_box
	housing.position = full_bounds.get_center()
	for child: Node in computer.find_children("*", "GeometryInstance3D", true, false):
		if legacy_keyboard.is_ancestor_of(child):
			continue
		(child as GeometryInstance3D).visible = false
	preload("res://scripts/legacy_keyboard.gd").restore(computer)
	var display: MeshInstance3D = computer.get_node("Screen") as MeshInstance3D
	display.visible = true
	var scale_x: float = bounds.size.x / (2.5 * 0.96)
	var scale_y: float = bounds.size.y / (1.25 * 0.97)
	display.scale = Vector3(scale_x, scale_y, 1)
	display.position = Vector3(bounds.position.x + 0.475 * 2.5 * scale_x,
		bounds.end.y - 0.475 * 1.25 * scale_y, bounds.end.z + 0.025)
	scene.set("screen_rim_enabled", false)
	var power: MeshInstance3D = computer.get_node("PowerButton") as MeshInstance3D
	power.visible = true
	power.position = Vector3(bounds.get_center().x + 0.35, bounds.position.y - 0.38, bounds.end.z + 0.04)
	var knob: Node3D = computer.get_node("TuningKnob") as Node3D
	knob.position = power.position + Vector3(0.4, 0, 0)
	for child: Node in knob.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).visible = true
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/desk_world.tscn") == OK)
	var output: FileAccess = FileAccess.open("res://verification/hi3d_computer_adapter.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"glass_bounds": str(bounds), "screen_position": str(display.position),
		"screen_scale": str(display.scale)}, "\t"))
	output.close()
	print("HI3D_COMPUTER_ADAPTER_OK: ", bounds, " display=", display.position, " scale=", display.scale)
	scene.free()
	quit()

func _glass_bounds(mesh_node: MeshInstance3D, scene: Node3D) -> AABB:
	var material: StandardMaterial3D = mesh_node.get_active_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null)
	var image: Image = material.albedo_texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var source: AABB = mesh_node.get_aabb()
	var transform: Transform3D = Transform3D.IDENTITY
	var ancestor: Node3D = mesh_node
	while ancestor != scene:
		transform = ancestor.transform * transform
		ancestor = ancestor.get_parent() as Node3D
	var first: bool = true
	var result: AABB = AABB()
	var matched: int = 0
	for index: int in range(0, vertices.size(), 4):
		var vertex: Vector3 = vertices[index]
		if vertex.z < source.get_center().z:
			continue
		# The circular meter is below the main glass; omit it from the fit.
		if vertex.y < source.position.y + source.size.y * 0.33:
			continue
		var uv: Vector2 = uvs[index]
		var color: Color = image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
			clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1))
		if color.g < color.r * 1.25 or color.g < color.b * 1.03:
			continue
		var point: Vector3 = transform * vertex
		if first:
			result = AABB(point, Vector3.ZERO)
			first = false
		else:
			result = result.expand(point)
		matched += 1
	assert(matched > 500, "Imported display color mask did not match enough vertices")
	return result
