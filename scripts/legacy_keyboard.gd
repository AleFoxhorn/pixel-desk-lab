extends RefCounted
## Keep the original 48 keys and spacebar as a separate desktop keyboard.
static func restore(computer: Node3D) -> void:
	var keyboard: Node3D = computer.get_node_or_null("Keyboard") as Node3D
	if keyboard == null:
		return
	keyboard.visible = true
	var housing: MeshInstance3D = computer.get_node("Housing") as MeshInstance3D
	var housing_bounds: AABB = housing.transform * housing.get_aabb()
	var target_width: float = housing_bounds.size.x * 0.67
	var target_depth: float = target_width * 0.31
	keyboard.scale = Vector3(target_width / 2.94, 1.0, target_depth / 1.05)
	keyboard.rotation_degrees.x = 10.0
	var base_bounds: AABB = Transform3D(keyboard.basis, Vector3.ZERO) * AABB(Vector3(-1.47, 0.655, 0.575), Vector3(2.94, 0.10, 1.05))
	var display: Node3D = computer.get_node("Screen") as Node3D
	# Center beneath the glass, leaving a small gap in front of the new computer.
	keyboard.position = Vector3(display.position.x, 0.325 - base_bounds.position.y, housing_bounds.end.z + 0.38 - base_bounds.position.z)
	for child: Node in keyboard.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visible = true
	if keyboard.has_node("LegacyKeyboardBase"):
		return
	var base: MeshInstance3D = MeshInstance3D.new()
	base.name = "LegacyKeyboardBase"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.94, 0.10, 1.05)
	base.mesh = mesh
	base.position = Vector3(0, 0.705, 1.10)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("d77b95")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.material_override = material
	keyboard.add_child(base)
	base.owner = computer.owner
