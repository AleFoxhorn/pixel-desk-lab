extends SceneTree
## Run after Godot import: --headless --path PROJECT --script res://tools/inspect_model.gd -- --asset=res://models/example.glb
## Reports node-level separability only; it does not claim semantic parts from material surfaces.

func _initialize() -> void:
	var asset: String = "res://scenes/desk_world.tscn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--asset="):
			asset = argument.trim_prefix("--asset=")
	var packed: PackedScene = load(asset) as PackedScene
	if packed == null:
		push_error("Import the model with Godot first; expected a PackedScene: " + asset)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	var meshes: Array[Dictionary] = []
	var hotspots: Array[Dictionary] = []
	var nodes: Array[Node] = [instance]
	nodes.append_array(instance.find_children("*", "", true, false))
	for node: Node in nodes:
		if node is MeshInstance3D:
			var part: MeshInstance3D = node as MeshInstance3D
			if part.mesh != null:
				meshes.append({"path": str(instance.get_path_to(part)),
					"surfaces": part.mesh.get_surface_count(), "has_skin": part.skin != null,
					"position": str(part.position), "bounds": str(part.get_aabb())})
		if node is CollisionObject3D and node.has_meta("action"):
			hotspots.append({"path": str(instance.get_path_to(node)), "action": node.get_meta("action")})
	var report: Dictionary = {"asset": asset, "mesh_nodes": meshes.size(), "meshes": meshes,
		"interaction_hotspots": hotspots,
		"assessment": "multiple_mesh_nodes_inspect_part_names" if meshes.size() > 1 else "single_mesh_requires_geometry_inspection",
		"limits": "Mesh nodes can be transformed independently. Surfaces are material regions, not guaranteed parts. Connected geometry requires cutting; skinned meshes require bone-aware inspection."}
	var destination: String = "res://verification/model_structure.json"
	var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write inspection report")
		instance.free()
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("MODEL_INSPECT_OK: %s, %d mesh nodes, %d interaction hotspots; %s" % [asset, meshes.size(), hotspots.size(), destination])
	instance.free()
	quit()
