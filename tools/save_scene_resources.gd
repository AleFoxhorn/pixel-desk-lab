extends SceneTree
## One-time conversion of the prototype's procedural geometry into editor-native resources.
## Future edits should be made in desk_world.tscn, not by rerunning this generator.

const Desk: Script = preload("res://scripts/desk_scene.gd")
const CameraDirector: Script = preload("res://scripts/camera_director.gd")

func _initialize() -> void:
	_save_scenes.call_deferred()

func _save_scenes() -> void:
	if FileAccess.file_exists("res://scenes/desk_world.tscn"):
		push_error("Refusing to overwrite an existing editable scene.")
		quit(1)
		return
	var world: Node3D = Desk.new()
	world.name = "DeskWorld"
	root.add_child(world)
	await process_frame
	var camera: Camera3D = CameraDirector.new()
	camera.name = "Camera"
	camera.fov = 39.0
	camera.near = 0.05
	camera.far = 80.0
	world.add_child(camera)
	camera.go_to(0, true)
	camera.current = true
	var views: Node3D = Node3D.new()
	views.name = "Views"
	world.add_child(views)
	var names: Array[String] = ["Front", "Side", "Rear", "ScreenClose"]
	for index: int in range(CameraDirector.VIEWS.size()):
		var data: Dictionary = CameraDirector.VIEWS[index]
		var focus: Vector3 = data["focus"]
		var yaw: float = deg_to_rad(float(data["yaw"]))
		var pitch: float = deg_to_rad(float(data["pitch"]))
		var distance: float = float(data["distance"])
		var view: Node3D = Node3D.new()
		view.name = names[index]
		views.add_child(view)
		var position_marker: Marker3D = Marker3D.new()
		position_marker.name = "CameraPosition"
		position_marker.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		view.add_child(position_marker)
		position_marker.look_at(focus)
		var focus_marker: Marker3D = Marker3D.new()
		focus_marker.name = "LookAt"
		focus_marker.position = focus
		view.add_child(focus_marker)
	_assign_owners(world, world)
	# Store a static editor preview. The scene controller binds the live 2D viewport at runtime.
	world.screen_on.albedo_texture = load("res://art/terminal.svg") as Texture2D
	var packed_world: PackedScene = PackedScene.new()
	assert(packed_world.pack(world) == OK)
	assert(ResourceSaver.save(packed_world, "res://scenes/desk_world.tscn") == OK)
	var lab: Control = Control.new()
	lab.name = "PixelDeskLab"
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.set_script(load("res://scripts/lab.gd"))
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "SceneViewport"
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	lab.add_child(viewport)
	viewport.owner = lab
	var saved_world: PackedScene = load("res://scenes/desk_world.tscn") as PackedScene
	var instance: Node3D = saved_world.instantiate() as Node3D
	viewport.add_child(instance)
	instance.owner = lab
	var display: TextureRect = TextureRect.new()
	display.name = "StyledImage"
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.size = Vector2(1280, 720)
	var texture: ViewportTexture = ViewportTexture.new()
	texture.resource_local_to_scene = true
	texture.viewport_path = NodePath("SceneViewport")
	display.texture = texture
	var post: ShaderMaterial = ShaderMaterial.new()
	post.shader = load("res://shaders/palette.gdshader") as Shader
	post.set_shader_parameter("enabled", true)
	post.set_shader_parameter("dither_enabled", true)
	post.set_shader_parameter("dither_strength", 0.045)
	display.material = post
	lab.add_child(display)
	display.owner = lab
	var packed_lab: PackedScene = PackedScene.new()
	assert(packed_lab.pack(lab) == OK)
	assert(ResourceSaver.save(packed_lab, "res://scenes/lab.tscn") == OK)
	lab.free()
	print("SAVED_EDITABLE_SCENES: desk_world.tscn and lab.tscn")
	quit()

func _assign_owners(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_assign_owners(child, scene_root)
