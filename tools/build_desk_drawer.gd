extends SceneTree
## Build editable furniture and patch only the corresponding front-panel opening.
const DeskBuilder: Script = preload("res://scripts/desk_scene.gd")
const DrawerController: Script = preload("res://scripts/desk_drawer.gd")
var geometry: Node3D
var drawer: Node3D

func _initialize() -> void:
	call_deferred("build")

func part(parent: Node3D, node_name: String, at: Vector3, dimensions: Vector3, hex: String, bevel: float = 0.025) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.position = at
	node.mesh = geometry._bevel_mesh(dimensions, bevel)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	parent.add_child(node)
	node.owner = drawer
	return node

func paper_file(node_name: String, at: Vector3, angle: float, folder_color: String, tab_x: float) -> void:
	var file: Node3D = Node3D.new()
	file.name = node_name
	file.position = at
	file.rotation_degrees.y = angle
	drawer.get_node("Slide/Files").add_child(file)
	file.owner = drawer
	part(file, "FolderBack", Vector3(0, 0, 0), Vector3(1.06, 0.025, 1.26), folder_color, 0.015)
	part(file, "IndexTab", Vector3(tab_x, 0.006, -0.665), Vector3(0.32, 0.025, 0.14), folder_color, 0.018)
	for index: int in range(4):
		var y: float = 0.021 + float(index) * 0.012
		part(file, "Page_%d" % index, Vector3(float(index % 2) * 0.015, y, -float(index) * 0.009), Vector3(0.94, 0.009, 1.10), "f5dfb4" if index < 3 else "fff0cd", 0.004)
	# Printed marks stay geometric and legible under the existing low-resolution print pass.
	part(file, "Header", Vector3(-0.14, 0.064, -0.39), Vector3(0.53, 0.005, 0.045), "60718e", 0.001)
	part(file, "HeaderRule", Vector3(0, 0.064, -0.28), Vector3(0.72, 0.005, 0.012), "d9949e", 0.001)
	for row: int in range(5):
		part(file, "TextLine_%d" % row, Vector3(-0.035 if row % 2 == 0 else -0.12, 0.064, -0.15 + float(row) * 0.105), Vector3(0.65 if row % 2 == 0 else 0.48, 0.005, 0.017), "9b9aa2", 0.001)
	part(file, "SmallStamp", Vector3(0.26, 0.065, 0.39), Vector3(0.18, 0.006, 0.115), "d8839c", 0.012)
	part(file, "ClipLeft", Vector3(-0.30, 0.074, -0.48), Vector3(0.015, 0.018, 0.19), "7185a3", 0.005)
	part(file, "ClipRight", Vector3(-0.22, 0.074, -0.48), Vector3(0.015, 0.018, 0.19), "7185a3", 0.005)
	part(file, "ClipBridge", Vector3(-0.26, 0.074, -0.57), Vector3(0.095, 0.018, 0.018), "7185a3", 0.005)

func build() -> void:
	geometry = DeskBuilder.new()
	drawer = Node3D.new()
	drawer.name = "DeskDrawer"
	drawer.set_script(DrawerController)
	# Fixed blue carcass sits immediately below the desk apron.
	part(drawer, "CavityBack", Vector3(0, -0.01, -1.91), Vector3(3.13, 0.56, 0.07), "35435e")
	part(drawer, "CavityFloor", Vector3(0, -0.30, -0.94), Vector3(3.15, 0.06, 1.99), "35435e")
	part(drawer, "UpperFrame", Vector3(0, 0.278, -0.94), Vector3(3.15, 0.05, 1.99), "6d436b")
	for x: float in [-1.54, 1.54]:
		part(drawer, "CaseSide_%s" % str(x), Vector3(x, -0.01, -0.94), Vector3(0.08, 0.57, 1.99), "607caa")
		part(drawer, "FixedRunner_%s" % str(x), Vector3(x * 0.965, -0.15, -0.91), Vector3(0.024, 0.035, 1.71), "829bc0", 0.006)
	var slide: Node3D = Node3D.new()
	slide.name = "Slide"
	drawer.add_child(slide)
	slide.owner = drawer
	part(slide, "TrayFloor", Vector3(0, -0.225, -0.91), Vector3(2.93, 0.06, 1.84), "829bc0")
	part(slide, "Liner", Vector3(0, -0.191, -0.91), Vector3(2.72, 0.008, 1.66), "536789", 0.003)
	for x: float in [-1.425, 1.425]:
		part(slide, "TraySide_%s" % str(x), Vector3(x, -0.065, -0.92), Vector3(0.075, 0.31, 1.82), "718db7")
		part(slide, "SideLip_%s" % str(x), Vector3(x, 0.094, -0.92), Vector3(0.08, 0.018, 1.78), "a0b0c8", 0.006)
		part(slide, "SlidingRunner_%s" % str(x), Vector3(x * 1.05, -0.15, -0.89), Vector3(0.022, 0.027, 1.64), "e2b282", 0.005)
	part(slide, "TrayBack", Vector3(0, -0.065, -1.80), Vector3(2.90, 0.31, 0.07), "607caa")
	part(slide, "RoseFront", Vector3(0, -0.012, 0.055), Vector3(3.00, 0.58, 0.12), "c77c98", 0.055)
	part(slide, "FrontInset", Vector3(0, -0.012, 0.119), Vector3(2.80, 0.40, 0.013), "b36c8d", 0.015)
	part(slide, "FrontWarmEdge", Vector3(0, 0.240, 0.121), Vector3(2.76, 0.020, 0.014), "f3d2a6", 0.005)
	part(slide, "LowerShadow", Vector3(0, -0.278, 0.105), Vector3(2.79, 0.025, 0.018), "824c70", 0.005)
	for x: float in [-0.46, 0.46]:
		part(slide, "HandleFoot_%s" % str(x), Vector3(x, -0.005, 0.176), Vector3(0.105, 0.115, 0.12), "e2b282", 0.025)
	part(slide, "CreamHandle", Vector3(0, 0.003, 0.252), Vector3(1.08, 0.095, 0.105), "ffe0a9", 0.04)
	part(slide, "HandleHighlight", Vector3(0, 0.037, 0.274), Vector3(0.88, 0.012, 0.035), "fff0cd", 0.005)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "HandleHit"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("action", "desk_drawer")
	body.position = Vector3(0, 0, 0.20)
	slide.add_child(body)
	body.owner = drawer
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 0.59, 0.26)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = drawer
	var files: Node3D = Node3D.new()
	files.name = "Files"
	slide.add_child(files)
	files.owner = drawer
	paper_file("BlueFile", Vector3(-0.63, -0.175, -0.87), -5.0, "9bb2c6", -0.27)
	paper_file("RoseFile", Vector3(0.58, -0.165, -1.02), 6.0, "d9949e", 0.27)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(drawer) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/desk_drawer.tscn") == OK)
	install()
	drawer.free()
	geometry.free()
	print("DESK_DRAWER_BUILD_OK")
	quit()

func install() -> void:
	var cabin: Node3D = (load("res://scenes/cabin_environment.tscn") as PackedScene).instantiate() as Node3D
	# Preserve every other environment node, imported prop and camera setting.
	for child: Node in cabin.get_children():
		if str(child.name) in ["DeskFrontPanel", "DeskFrontPanelLeft", "DeskFrontPanelRight", "DeskPanelSeam_2_0", "DeskPanelSeam_4_5", "DeskDrawer"]:
			child.free()
	for data: Dictionary in [{"name": "DeskFrontPanelLeft", "x": -2.455, "width": 8.29}, {"name": "DeskFrontPanelRight", "x": 5.705, "width": 1.79}]:
		var panel: MeshInstance3D = MeshInstance3D.new()
		panel.name = str(data["name"])
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(float(data["width"]), 0.52, 0.08)
		panel.mesh = mesh
		panel.position = Vector3(float(data["x"]), -0.30, 4.73)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color("6d436b")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		panel.material_override = mat
		cabin.add_child(panel)
		panel.owner = cabin
	var instance: Node3D = (load("res://scenes/desk_drawer.tscn") as PackedScene).instantiate() as Node3D
	instance.position = Vector3(3.25, -0.41, 4.76)
	cabin.add_child(instance)
	instance.owner = cabin
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(cabin) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/cabin_environment.tscn") == OK)
	cabin.free()
