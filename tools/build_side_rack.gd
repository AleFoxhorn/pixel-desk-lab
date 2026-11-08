extends SceneTree
## Editable, empty side shelving, with geometry shared with the existing desk style.
const DeskBuilder: Script = preload("res://scripts/desk_scene.gd")
var rack: Node3D
var geometry: Node3D

func _initialize() -> void:
	call_deferred("build")

func part(node_name: String, at: Vector3, dimensions: Vector3, hex: String, bevel: float = 0.035) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = geometry._bevel_mesh(dimensions, bevel)
	node.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	rack.add_child(node)
	node.owner = rack
	return node

func build() -> void:
	geometry = DeskBuilder.new()
	rack = Node3D.new()
	rack.name = "SideRack"
	root.add_child(rack)
	# Full-size freestanding rack: ground level matches the existing floor at -1.7.
	part("RecessedBack", Vector3(0, 1.02, -0.68), Vector3(1.68, 5.16, 0.12), "35435e", 0.08)
	for x: float in [-0.88, 0.88]:
		part("SidePanel_%s" % str(x), Vector3(x, 1.04, 0), Vector3(0.15, 5.28, 1.58), "607caa", 0.07)
		part("FrontUpright_%s" % str(x), Vector3(x, 1.03, 0.76), Vector3(0.19, 5.30, 0.15), "829bc0", 0.065)
		part("CreamPinstripe_%s" % str(x), Vector3(x - 0.022, 1.03, 0.845), Vector3(0.023, 5.12, 0.012), "f3d2a6", 0.004)
		for z: float in [-0.51, 0.51]:
			part("Foot_%s_%s" % [str(x), str(z)], Vector3(x * 0.85, -1.61, z), Vector3(0.19, 0.18, 0.22), "e2b282")
	for index: int in range(4):
		var y: float = -1.37 + float(index) * 1.25
		part("Shelf_%d" % index, Vector3(0, y, 0.03), Vector3(1.76, 0.13, 1.50), "d8839c", 0.055)
		part("ShelfTop_%d" % index, Vector3(0, y + 0.069, 0.03), Vector3(1.64, 0.016, 1.38), "e99ba8", 0.006)
		part("WarmShelfLip_%d" % index, Vector3(0, y + 0.043, 0.799), Vector3(1.66, 0.024, 0.018), "ffe0a9", 0.005)
		part("LowerShelfShadow_%d" % index, Vector3(0, y - 0.069, 0.72), Vector3(1.66, 0.028, 0.08), "824c70", 0.008)
	part("RoundedCrown", Vector3(0, 3.69, 0.04), Vector3(2.04, 0.19, 1.74), "ce7f9b", 0.085)
	part("CrownTop", Vector3(0, 3.79, 0.03), Vector3(1.92, 0.025, 1.60), "e9a2af", 0.01)
	part("CrownHighlight", Vector3(0, 3.735, 0.917), Vector3(1.85, 0.026, 0.022), "ffe0ae", 0.006)
	part("BasePlinth", Vector3(0, -1.40, 0.03), Vector3(1.98, 0.20, 1.67), "b96c8e", 0.075)
	# Small flush brass fasteners echo the terminal's warm hardware.
	for x: float in [-0.88, 0.88]:
		for y: float in [-1.25, 1.05, 3.40]:
			var bolt: MeshInstance3D = part("Fastener_%s_%s" % [str(x), str(y)], Vector3(x, y, 0.857), Vector3(0.060, 0.060, 0.022), "f5d09d", 0.022)
			bolt.rotation_degrees.z = 45.0
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(rack) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/side_rack.tscn") == OK)
	geometry.free()
	print("SIDE_RACK_BUILD_OK: ", rack.get_child_count(), " editable parts")
	quit()
