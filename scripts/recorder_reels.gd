extends Node3D
## Runtime-only reel companions: imported geometry, UVs and source GLB stay intact.
## Add this controller beneath the Recorder holder, then call setup(holder, bounds).
var reels: Array[MeshInstance3D] = []
var angular_speed: float = 0.0
var triangle_counts: Dictionary = {"total": 0, "fixed": 0, "left": 0, "right": 0}
var axis_centers: Array[Vector3] = []
var mode: String = "stop"
var target_speed: float = 0.0
var source: MeshInstance3D
var material_links: Array[Dictionary] = []
var source_mesh: Mesh

func setup(holder: Node3D, _bounds: AABB) -> void:
	if not reels.is_empty():
		return
	# Runtime control caps are tiny; the original imported mesh is the largest surface.
	var best_vertices: int = 0
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var candidate: MeshInstance3D = node as MeshInstance3D
		if candidate.mesh == null:
			continue
		var vertex_count: int = 0
		for surface: int in range(candidate.mesh.get_surface_count()):
			vertex_count += (candidate.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if vertex_count > best_vertices:
			best_vertices = vertex_count
			source = candidate
	assert(source != null and best_vertices > 1000, "Recorder imported mesh was not found")
	source_mesh = source.mesh
	var mesh_bounds: AABB = source_mesh.get_aabb()
	# Measured from the protruding bearing faces in recorder.glb, before holder scaling.
	axis_centers = [mesh_bounds.position + mesh_bounds.size * Vector3(0.294, 0.610, 0.90),
		mesh_bounds.position + mesh_bounds.size * Vector3(0.715, 0.610, 0.90)]
	for index: int in range(2):
		var reel: MeshInstance3D = MeshInstance3D.new()
		reel.name = "LeftReel" if index == 0 else "RightReel"
		reel.position = axis_centers[index]
		reel.layers = source.layers
		reel.cast_shadow = source.cast_shadow
		reel.mesh = ArrayMesh.new()
		source.add_child(reel)
		reels.append(reel)
	var fixed: ArrayMesh = ArrayMesh.new()
	for surface: int in range(source_mesh.get_surface_count()):
		_split_surface(surface, mesh_bounds, fixed)
	assert(triangle_counts["left"] > 1000 and triangle_counts["right"] > 1000, "Recorder reel regions must contain real source triangles")
	assert(triangle_counts["total"] == triangle_counts["fixed"] + triangle_counts["left"] + triangle_counts["right"], "Every original triangle must appear exactly once")
	source.mesh = fixed
	_sync_materials()
	set_mode("stop")
	set_meta("source_triangle_count", triangle_counts["total"])
	set_meta("source_asset_unchanged", true)

func _split_surface(surface: int, mesh_bounds: AABB, fixed: ArrayMesh) -> void:
	var arrays: Array = source_mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for index: int in range(vertices.size()):
			indices[index] = index
	var classes: PackedByteArray = PackedByteArray()
	classes.resize(vertices.size())
	var size_x: float = mesh_bounds.size.x
	var front: float = mesh_bounds.position.z + mesh_bounds.size.z * 0.78
	var hub_radius_squared: float = pow(size_x * 0.060, 2.0)
	var left_radius_squared: float = pow(size_x * 0.205, 2.0)
	var right_radius_squared: float = pow(size_x * 0.198, 2.0)
	# The inner bearing and outer surrounding frame remain stationary. The complete
	# three-blade face and the visible wound-tape pattern rotate as a single annulus.
	for index: int in range(vertices.size()):
		var point: Vector3 = vertices[index]
		if point.z < front:
			continue
		var left_delta: Vector2 = Vector2(point.x - axis_centers[0].x, point.y - axis_centers[0].y)
		var radius_squared: float = left_delta.length_squared()
		if radius_squared > hub_radius_squared and radius_squared < left_radius_squared:
			classes[index] = 1
			continue
		var right_delta: Vector2 = Vector2(point.x - axis_centers[1].x, point.y - axis_centers[1].y)
		radius_squared = right_delta.length_squared()
		if radius_squared > hub_radius_squared and radius_squared < right_radius_squared:
			classes[index] = 2
	var groups: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for offset: int in range(0, indices.size(), 3):
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		var group: int = 0
		# A single choice per triangle keeps the source partition exhaustive and disjoint.
		if classes[a] == classes[b] or classes[a] == classes[c]:
			group = classes[a]
		elif classes[b] == classes[c]:
			group = classes[b]
		groups[group].append(a)
		groups[group].append(b)
		groups[group].append(c)
	triangle_counts["total"] += int(indices.size() / 3.0)
	triangle_counts["fixed"] += int(groups[0].size() / 3.0)
	triangle_counts["left"] += int(groups[1].size() / 3.0)
	triangle_counts["right"] += int(groups[2].size() / 3.0)
	var original_material: Material = source_mesh.surface_get_material(surface)
	if not groups[0].is_empty():
		var fixed_arrays: Array = arrays.duplicate()
		fixed_arrays[Mesh.ARRAY_INDEX] = groups[0]
		fixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fixed_arrays)
		fixed.surface_set_material(fixed.get_surface_count() - 1, original_material)
	for index: int in range(2):
		if groups[index + 1].is_empty():
			continue
		var part_arrays: Array = _compact_arrays(arrays, groups[index + 1], axis_centers[index])
		var part_mesh: ArrayMesh = reels[index].mesh as ArrayMesh
		part_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part_arrays)
		part_mesh.surface_set_material(part_mesh.get_surface_count() - 1, original_material)
		material_links.append({"reel": reels[index], "source_surface": surface, "target_surface": part_mesh.get_surface_count() - 1})

func _compact_arrays(arrays: Array, selected: PackedInt32Array, center: Vector3) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_map: PackedInt32Array = PackedInt32Array()
	index_map.resize(vertices.size())
	index_map.fill(-1)
	var used: PackedInt32Array = PackedInt32Array()
	var new_indices: PackedInt32Array = PackedInt32Array()
	new_indices.resize(selected.size())
	for index: int in range(selected.size()):
		var old_index: int = selected[index]
		if index_map[old_index] < 0:
			index_map[old_index] = used.size()
			used.append(old_index)
		new_indices[index] = index_map[old_index]
	var result: Array = arrays.duplicate()
	for slot: int in range(Mesh.ARRAY_MAX):
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		var attribute: Variant = arrays[slot]
		if attribute.size() == 0:
			continue
		var stride: int = int(attribute.size() / float(vertices.size()))
		assert(stride > 0, "Unexpected imported vertex attribute layout")
		var copy: Variant = attribute.duplicate()
		copy.resize(used.size() * stride)
		for index: int in range(used.size()):
			for component: int in range(stride):
				copy[index * stride + component] = attribute[used[index] * stride + component]
		if slot == Mesh.ARRAY_VERTEX:
			var compact_vertices: PackedVector3Array = copy
			for index: int in range(compact_vertices.size()):
				assert(mesh_point_inside(vertices[used[index]], source_mesh.get_aabb()), "Reel vertices must remain inside original bounds")
				compact_vertices[index] -= center
			copy = compact_vertices
		result[slot] = copy
	result[Mesh.ARRAY_INDEX] = new_indices
	return result

func mesh_point_inside(point: Vector3, bounds: AABB) -> bool:
	return bounds.grow(0.00001).has_point(point)

func set_mode(next_mode: String) -> void:
	mode = next_mode
	target_speed = -7.0 if mode == "rewind" else (1.25 if mode in ["play", "record"] else 0.0)

func _sync_materials() -> void:
	if not is_instance_valid(source):
		return
	for link: Dictionary in material_links:
		var reel: MeshInstance3D = link["reel"] as MeshInstance3D
		var material: Material = source.get_active_material(int(link["source_surface"]))
		if reel.get_surface_override_material(int(link["target_surface"])) != material:
			reel.set_surface_override_material(int(link["target_surface"]), material)

func _process(delta: float) -> void:
	_sync_materials()
	angular_speed = move_toward(angular_speed, target_speed, (12.0 if is_zero_approx(target_speed) else 7.0) * delta)
	if is_zero_approx(angular_speed):
		return
	for reel: MeshInstance3D in reels:
		reel.rotation.z = fposmod(reel.rotation.z + angular_speed * delta, TAU)
