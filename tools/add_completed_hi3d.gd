extends SceneTree
## Add newly imported models while preserving existing prop edits.

const Placement: Script = preload("res://tools/place_hi3d_models.gd")

func _initialize() -> void:
	var props: Node3D = load("res://scenes/generated_props.tscn").instantiate() as Node3D
	var added: Array[String] = []
	for item: Dictionary in Placement.ITEMS:
		if props.has_node(str(item["node"])):
			continue
		var path: String = "res://models/hi3d/%s.glb" % item["id"]
		if not ResourceLoader.exists(path):
			continue
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		assert(model != null)
		model.name = "Model"
		var boxes: Array[AABB] = []
		_collect(model, Transform3D.IDENTITY, boxes)
		assert(not boxes.is_empty())
		var bounds: AABB = boxes[0]
		for index: int in range(1, boxes.size()):
			bounds = bounds.merge(boxes[index])
		var factor: float = float(item["extent"]) / bounds.size[int(item["axis"])]
		var offset: Vector3 = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		var holder: Node3D = Node3D.new()
		holder.name = str(item["node"])
		holder.position = item["at"]
		holder.rotation_degrees.y = float(item.get("yaw", 0.0))
		holder.set_meta("source_asset", path)
		holder.set_meta("source_task_id", str(item.get("task_id", "")))
		props.add_child(holder)
		holder.owner = props
		holder.add_child(model)
		model.owner = props
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), offset * factor) * model.transform
		var placed: AABB = holder.transform * AABB(bounds.position * factor + offset * factor, bounds.size * factor)
		assert(absf(placed.position.y - holder.position.y) < 0.001)
		added.append(str(holder.name))
	if props.has_node("CardHolder"):
		(props.get_node("OrigamiBird") as Node3D).position.z = 3.05
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(props) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/generated_props.tscn") == OK)
	props.free()
	print("HI3D_ADD_COMPLETED_OK: ", added)
	quit()

func _collect(node: Node3D, parent: Transform3D, boxes: Array[AABB]) -> void:
	var transform: Transform3D = parent * node.transform
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh != null:
			boxes.append(transform * mesh.get_aabb())
	for child: Node in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, transform, boxes)
