extends RefCounted
## Reversible material companions. Never changes source GLBs or shared materials.
const TOON_SHADER: Shader = preload("res://shaders/textured_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/prop_outline.gdshader")
var entries: Array[Dictionary] = []
var enabled: bool = false
var surface_count: int = 0
var outline_world_width: float = 0.012

func bind(root: Node3D) -> void:
	set_enabled(false)
	entries.clear()
	surface_count = 0
	var props: Node3D = root.find_child("GeneratedProps", true, false) as Node3D
	if props == null:
		return
	for node: Node in props.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		# Imported scene ownership distinguishes original meshes from later runtime controls.
		if mesh_node.owner == null:
			continue
		var surfaces: Array[Dictionary] = []
		var converted: int = 0
		var source_override: Material = mesh_node.material_override
		var world_scale: Vector3 = _world_scale(mesh_node)
		var max_scale: float = maxf(absf(world_scale.x), maxf(absf(world_scale.y), absf(world_scale.z)))
		for index: int in range(mesh_node.mesh.get_surface_count()):
			var original_surface: Material = mesh_node.get_surface_override_material(index)
			var source: StandardMaterial3D = mesh_node.get_active_material(index) as StandardMaterial3D
			var toon: ShaderMaterial = null
			if source != null and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				toon = ShaderMaterial.new()
				toon.shader = TOON_SHADER
				toon.set_shader_parameter("albedo", source.albedo_color)
				if source.albedo_texture != null:
					toon.set_shader_parameter("albedo_texture", source.albedo_texture)
				var outline: ShaderMaterial = ShaderMaterial.new()
				outline.shader = OUTLINE_SHADER
				outline.set_shader_parameter("outline_width", outline_world_width / maxf(max_scale, 0.001))
				toon.next_pass = outline
				surface_count += 1
				converted += 1
			surfaces.append({"original": original_surface, "toon": toon})
		if converted > 0:
			entries.append({"mesh": mesh_node, "override": source_override, "surfaces": surfaces})

func set_enabled(value: bool) -> void:
	enabled = value
	for entry: Dictionary in entries:
		var mesh_node: MeshInstance3D = entry["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh_node):
			continue
		var surfaces: Array[Dictionary] = entry["surfaces"]
		mesh_node.material_override = null if value else entry["override"] as Material
		for index: int in range(surfaces.size()):
			var surface: Dictionary = surfaces[index]
			var toon: ShaderMaterial = surface["toon"] as ShaderMaterial
			mesh_node.set_surface_override_material(index, toon if value and toon != null else surface["original"] as Material)

func _world_scale(node: Node3D) -> Vector3:
	if node.is_inside_tree():
		return node.global_basis.get_scale()
	var basis: Basis = node.basis
	var parent: Node = node.get_parent()
	while parent is Node3D:
		basis = (parent as Node3D).basis * basis
		parent = parent.get_parent()
	return basis.get_scale()
