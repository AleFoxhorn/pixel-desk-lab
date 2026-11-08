extends SceneTree
## Normalize imported GLBs and save an editable prop scene beside the existing desk.

const ITEMS: Array[Dictionary] = [
	{"id": "keyboard", "node": "Keyboard", "axis": 0, "extent": 4.1, "yaw": 180.0, "at": Vector3(0.15, 0.34, 2.65)},
	{"id": "lamp", "node": "Lamp", "axis": 1, "extent": 3.5, "at": Vector3(-4.35, 0.34, -0.55)},
	{"id": "radio", "node": "Radio", "axis": 0, "extent": 1.9, "at": Vector3(-4.65, 0.34, 1.35)},
	{"id": "recorder", "node": "Recorder", "axis": 0, "extent": 2.25, "at": Vector3(4.8, 0.34, 0.5)},
	{"id": "computer", "node": "Computer", "axis": 0, "extent": 6.6, "at": Vector3(0, 0.34, -0.15)},
	# Its oriented bounds occupy half the placed radio's volume.
	{"id": "origami_bird", "node": "OrigamiBird", "axis": 0, "extent": 1.5277865, "yaw": -25.0, "at": Vector3(3.2, 0.34, 3.05)},
	{"id": "card_holder", "node": "CardHolder", "axis": 0, "extent": 1.55, "at": Vector3(2.8, 0.34, 1.7), "task_id": "da0460b56dc94c46afc19b4fae130990"},
	{"id": "rocket", "node": "Rocket", "axis": 1, "extent": 1.5, "yaw": -15.0, "at": Vector3(5.2, 0.34, 2.65), "task_id": "82388e8b16924aa29fde8eed58e2ee52"},
	{"id": "wall_shelf", "node": "WallShelf", "axis": 0, "extent": 9.0, "at": Vector3(0, 4.197, -2.42), "task_id": "ef640f630b844065945d7a18f2b0bf15"},
	{"id": "binder_pink", "node": "BinderPink", "axis": 1, "extent": 1.0, "at": Vector3(-2.7, 5.513356, -2.42), "task_id": "a9e0437c24c247e08f4596b4b54abf9b"}
]

func _initialize() -> void:
	var props: Node3D = Node3D.new()
	props.name = "GeneratedProps"
	var reports: Array[Dictionary] = []
	for item: Dictionary in ITEMS:
		var path: String = "res://models/hi3d/%s.glb" % item["id"]
		assert(ResourceLoader.exists(path), "Model has not finished importing: " + path)
		var packed: PackedScene = load(path) as PackedScene
		assert(packed != null, "Model must import as PackedScene: " + path)
		var model: Node3D = packed.instantiate() as Node3D
		assert(model != null)
		model.name = "Model"
		var bounds_list: Array[AABB] = []
		_collect_bounds(model, Transform3D.IDENTITY, bounds_list)
		assert(not bounds_list.is_empty(), "No mesh bounds in " + path)
		var bounds: AABB = bounds_list[0]
		for index: int in range(1, bounds_list.size()):
			bounds = bounds.merge(bounds_list[index])
		var axis: int = int(item["axis"])
		assert(bounds.size[axis] > 0.00001)
		var factor: float = float(item["extent"]) / bounds.size[axis]
		var holder: Node3D = Node3D.new()
		holder.name = str(item["node"])
		holder.visible = str(item["id"]) not in ["keyboard", "origami_bird"]
		holder.position = item["at"]
		holder.rotation_degrees.y = float(item.get("yaw", 0.0))
		props.add_child(holder)
		holder.owner = props
		holder.add_child(model)
		model.owner = props
		var offset: Vector3 = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), offset * factor) * model.transform
		var task_id: String = _task_id(str(item["id"]))
		if not task_id.is_empty():
			holder.set_meta("source_task_id", task_id)
		holder.set_meta("source_asset", path)
		var normalized: AABB = holder.transform * AABB(bounds.position * factor + offset * factor, bounds.size * factor)
		assert(absf(normalized.position.y - (item["at"] as Vector3).y) < 0.001)
		reports.append({"asset": item["id"], "source_bounds": str(bounds), "placed_bounds": str(normalized), "scale": factor})
	assert(props.get_child_count() == ITEMS.size(), "All generated props must be present")
	var scene: PackedScene = PackedScene.new()
	assert(scene.pack(props) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/generated_props.tscn") == OK)
	var file: FileAccess = FileAccess.open("res://verification/hi3d_placement.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "\t"))
	file.close()
	props.free()
	print("HI3D_PLACEMENT_OK: ", JSON.stringify(reports))
	quit()

func _collect_bounds(node: Node3D, parent_transform: Transform3D, result: Array[AABB]) -> void:
	var accumulated: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			result.append(accumulated * mesh_instance.get_aabb())
	for child: Node in node.get_children():
		if child is Node3D:
			_collect_bounds(child as Node3D, accumulated, result)

func _task_id(asset: String) -> String:
	var tasks: Dictionary = {
		"keyboard": "fa87944b651249dd8444fea1ba00592b",
		"lamp": "682a353f95c94f389e760573f17f953e",
		"radio": "018a007defcc4483b3c785e75dc1de81",
		"recorder": "1f84c11e18c84e83b09b161579f0cafa",
		"computer": "d343c25bdf4547f9a7159c4d9fb76853"
	}
	if tasks.has(asset):
		return str(tasks[asset])
	for item: Dictionary in ITEMS:
		if str(item["id"]) == asset:
			return str(item.get("task_id", ""))
	return ""
