extends Node3D
## Procedural stand-ins only. This subtree can later be replaced by imported GLB assets.

const ScreenTerminal: Script = preload("res://scripts/screen_terminal.gd")
const ScreenSurface: Script = preload("res://scripts/screen_surface.gd")
signal device_action(action: String)
var screen_brightness: float = 0.95
var screen_palette: int = 0
var terminal_view: SubViewport
var terminal_ui: ScreenTerminal

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const ImportedToon: Script = preload("res://scripts/imported_toon.gd")
var imported_toon: RefCounted
var material_pairs: Array[Dictionary] = []
const SCREEN_COLLISION_LAYER: int = 64
const COMPUTER_COLLISION_LAYER: int = 128
var has_precise_computer_hit: bool = false
var screen_size: Vector2 = ScreenSurface.DISPLAY_SIZE
var fitted_screen: bool = false
var screen: MeshInstance3D
var power_button: Node3D
var tuning_knob: Node3D
var tray: Node3D
var powered: bool = true
var interaction_busy: bool = false
@export var screen_on: StandardMaterial3D
@export var screen_off: StandardMaterial3D
@export var screen_rim_enabled: bool = true
var accent: Color = Color("c88659")

func _ready() -> void:
	if has_node("Computer"):
		_bind_saved_scene()
		_setup_interactive_screen()
		return
	_build_lighting()
	_build_desk()
	_build_computer()
	_setup_interactive_screen()

func _bind_saved_scene() -> void:
	var housing: MeshInstance3D = get_node("Computer/Housing") as MeshInstance3D
	var view_hit: StaticBody3D = StaticBody3D.new()
	view_hit.name = "CameraSurface"
	view_hit.collision_layer = 16
	view_hit.collision_mask = 0
	var view_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = housing.get_aabb().size
	view_shape.shape = box
	view_shape.position = housing.get_aabb().get_center()
	view_hit.add_child(view_shape)
	housing.add_child(view_hit)
	_build_computer_hit_surface()
	screen = get_node("Computer/Screen") as MeshInstance3D
	power_button = get_node("Computer/PowerButton") as Node3D
	tuning_knob = get_node("Computer/TuningKnob") as Node3D
	tray = get_node("Computer/MediaTray") as Node3D
	var terminal: SubViewport = get_node("TerminalTexture") as SubViewport
	screen_on.albedo_texture = terminal.get_texture()
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.has_meta("toon_material"):
			material_pairs.append({"mesh": mesh, "smooth": mesh.get_meta("smooth_material"),
				"toon": mesh.get_meta("toon_material")})
	imported_toon = ImportedToon.new()
	imported_toon.bind(self)
	var props: Node = get_node_or_null("GeneratedProps")
	if props != null:
		props.child_entered_tree.connect(func(_child: Node) -> void: _refresh_imported_toon.call_deferred())

func _refresh_imported_toon() -> void:
	if is_inside_tree() and imported_toon != null:
		imported_toon.refresh(self)

func _build_computer_hit_surface() -> void:
	# A coarse box is useful for choosing camera regions, but not for click-away
	# dismissal: the curved imported case has large empty corners and openings.
	var imported: MeshInstance3D = get_node_or_null("GeneratedProps/Computer/Model/world/geometry_0") as MeshInstance3D
	if imported == null or imported.mesh == null or has_precise_computer_hit:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ComputerSilhouette"
	body.collision_layer = COMPUTER_COLLISION_LAYER
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = imported.mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	imported.add_child(body)
	has_precise_computer_hit = true

func _build_lighting() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "Environment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111c22")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("76857f")
	environment.ambient_light_energy = 0.12
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	add_child(world_environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-34.0, -56.0, 0.0)
	key.light_color = Color("fff0d0")
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)

func _build_desk() -> void:
	_box(self, "DeskEdge", Vector3(7.8, 0.22, 4.5), Vector3(0, 0.12, 0.35), Color("293f42"), 0.07)
	_box(self, "DeskSurface", Vector3(7.75, 0.08, 4.46), Vector3(0, 0.27, 0.35), Color("60766d"), 0.035)
	_box(self, "DeskMat", Vector3(4.4, 0.025, 3.36), Vector3(0, 0.325, 0.36), Color("23373c"), 0.05)
	_box(self, "FrontRail", Vector3(7.1, 0.07, 0.025), Vector3(0, 0.11, 2.61), accent, 0.01)
	for x: float in [-2.9, 2.9]:
		_box(self, "Leg", Vector3(0.24, 1.7, 0.25), Vector3(x, -0.8, 1.5), Color("23373c"), 0.03)
	_box(self, "Floor", Vector3(200, 0.1, 200), Vector3(0, -1.7, 0), Color("111c22"))

func _build_computer() -> void:
	var computer: Node3D = Node3D.new()
	computer.name = "Computer"
	add_child(computer)
	var ivory: Color = Color("bab99b")
	var trim: Color = Color("748878")
	var dark: Color = Color("253b3c")
	_box(computer, "Base", Vector3(2.95, 0.36, 2.75), Vector3(0, 0.54, 0.40), ivory, 0.12)
	_box(computer, "Pedestal", Vector3(1.25, 0.31, 0.92), Vector3(0, 0.86, -0.15), trim, 0.09)
	_box(computer, "Housing", Vector3(2.75, 2.0, 1.6), Vector3(0, 1.91, -0.10), ivory, 0.17)
	_box(computer, "Bezel", Vector3(2.49, 1.76, 0.16), Vector3(0, 1.94, 0.71), trim, 0.16)
	_box(computer, "ScreenRecess", Vector3(2.15, 1.38, 0.06), Vector3(0, 2.02, 0.81), dark, 0.13)
	var screen_mesh: QuadMesh = QuadMesh.new()
	screen_mesh.size = Vector2(1.94, 1.20)
	screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 2.03, 0.854)
	screen_on = StandardMaterial3D.new()
	screen_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_on.albedo_texture = _terminal_texture()
	screen_on.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen_off = StandardMaterial3D.new()
	screen_off.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_off.albedo_color = Color("13272b")
	screen.material_override = screen_on
	computer.add_child(screen)
	_label(computer, "NORTH / 83", Vector3(-0.65, 1.28, 0.815), 0.0022, 24, dark)
	_label(computer, "PERSONAL RELAY", Vector3(0.66, 1.28, 0.815), 0.00145, 22, dark)
	power_button = _box(computer, "PowerButton", Vector3(0.17, 0.12, 0.09), Vector3(0.94, 1.10, 0.81), accent, 0.025)
	_hitbox(power_button, Vector3(0.30, 0.27, 0.20), "power")
	_box(computer, "PowerLamp", Vector3(0.055, 0.055, 0.03), Vector3(0.68, 1.10, 0.83), Color("a6d6ad"), 0.01)
	tuning_knob = Node3D.new()
	tuning_knob.name = "TuningKnob"
	tuning_knob.position = Vector3(-0.99, 1.12, 0.82)
	computer.add_child(tuning_knob)
	var knob: MeshInstance3D = _cylinder(tuning_knob, "Dial", 0.09, 0.10, Vector3.ZERO, dark)
	knob.rotation_degrees.x = 90.0
	_box(tuning_knob, "DialMark", Vector3(0.018, 0.06, 0.012), Vector3(0, 0.035, 0.058), ivory)
	_hitbox(tuning_knob, Vector3(0.26, 0.26, 0.22), "knob")
	_box(computer, "KeyboardWell", Vector3(2.64, 0.055, 0.75), Vector3(0, 0.747, 1.04), dark, 0.04)
	for row: int in range(4):
		for column: int in range(12):
			var color: Color = ivory if column < 10 else trim
			if row == 3 and column == 11:
				color = accent
			_box(computer, "Key_%d_%d" % [row, column], Vector3(0.16, 0.072, 0.12),
				Vector3(-1.15 + column * 0.208, 0.79, 0.77 + row * 0.17), color, 0.018)
	_box(computer, "SpaceBar", Vector3(1.02, 0.06, 0.12), Vector3(-0.15, 0.79, 1.44), trim, 0.02)
	for x: float in [-1.384, 1.384]:
		for index: int in range(9):
			_box(computer, "SideVent", Vector3(0.015, 0.035, 0.58), Vector3(x, 1.70 + index * 0.068, -0.20), dark)
	for index: int in range(12):
		_box(computer, "RearVent", Vector3(1.65, 0.045, 0.018), Vector3(0, 1.75 + index * 0.063, -0.907), dark)
	_box(computer, "RearPanel", Vector3(1.70, 0.32, 0.035), Vector3(0, 1.28, -0.925), dark, 0.035)
	for x: float in [-0.53, -0.12, 0.32]:
		_box(computer, "Port", Vector3(0.23, 0.13, 0.04), Vector3(x, 1.28, -0.958), trim, 0.015)
	var rear_label: Label3D = _label(computer, "MEMORY LINK / DO NOT DISCONNECT", Vector3(0, 1.01, -0.95), 0.0018, 24, accent)
	rear_label.rotation_degrees.y = 180.0
	var side_label: Label3D = _label(computer, "FIELD UNIT / 0083", Vector3(1.39, 1.38, 0.0), 0.0019, 24, dark)
	side_label.rotation_degrees.y = 90.0
	_box(computer, "TrayWell", Vector3(1.44, 0.16, 0.06), Vector3(0, 0.53, 1.80), dark, 0.025)
	tray = Node3D.new()
	tray.name = "MediaTray"
	tray.position = Vector3(0, 0.53, 1.79)
	computer.add_child(tray)
	_box(tray, "TrayFace", Vector3(1.34, 0.12, 0.07), Vector3.ZERO, trim, 0.025)
	_box(tray, "TrayPlate", Vector3(1.18, 0.035, 0.63), Vector3(0, 0.015, -0.33), dark)
	_hitbox(tray, Vector3(1.40, 0.24, 0.16), "tray")
	_label(computer, "N-83   /   64K", Vector3(-0.90, 0.53, 1.82), 0.0015, 22, dark)

func _terminal_texture() -> ViewportTexture:
	# A 2D screen rendered to a texture; kept independent from the outer 3D camera.
	var terminal: SubViewport = SubViewport.new()
	terminal.name = "TerminalTexture"
	terminal.size = Vector2i(640, 400)
	terminal.disable_3d = true
	terminal.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(terminal)
	var background: ColorRect = ColorRect.new()
	background.color = Color("102b29")
	background.size = Vector2(640,400)
	terminal.add_child(background)
	var font: Font = preload("res://scripts/terminal_font.gd").create_font()
	var lines: Array[Dictionary] = [
		{"text":"NORTH / RELAY SYSTEMS", "at":Vector2(35,20), "size":23},
		{"text":"PERSONAL TERMINAL / 08 NOV 2083", "at":Vector2(37,83), "size":13},
		{"text":"LOCAL NODE", "at":Vector2(37,129), "size":19},
		{"text":"ONLINE_", "at":Vector2(34,163), "size":49},
		{"text":"NO EXTERNAL TRANSMISSION", "at":Vector2(37,243), "size":15},
		{"text":"01 / WAITING FOR INPUT", "at":Vector2(37,300), "size":16},
		{"text":"MEM 64K     SYS 1.04       LINK: --", "at":Vector2(37,358), "size":12}
	]
	for data: Dictionary in lines:
		var label: Label = Label.new()
		label.text = str(data["text"])
		label.position = data["at"]
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",int(data["size"]))
		label.add_theme_color_override("font_color",Color("9bcea8"))
		terminal.add_child(label)
	for index: int in range(7):
		var bar: ColorRect = ColorRect.new()
		bar.color = Color("5b9671")
		bar.position = Vector2(485 + index * 15, 240 - index * 12)
		bar.size = Vector2(8, 15 + index * 12)
		terminal.add_child(bar)
	return terminal.get_texture()

func set_toon(enabled: bool) -> void:
	if imported_toon != null:
		imported_toon.set_enabled(enabled)
	for pair: Dictionary in material_pairs:
		var mesh: MeshInstance3D = pair["mesh"]
		mesh.material_override = pair["toon"] if enabled else pair["smooth"]

func interact(action: String) -> void:
	if interaction_busy:
		return
	if action not in ["power", "knob", "tray"]:
		return
	interaction_busy = true
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match action:
		"power":
			var rest: Vector3 = power_button.position
			tween.tween_property(power_button, "position", rest + Vector3(0, 0, -0.045), 0.12)
			tween.tween_callback(_toggle_power)
			tween.tween_property(power_button, "position", rest, 0.18)
		"knob":
			tween.tween_property(tuning_knob, "rotation:z", -1.6, 0.4)
			tween.tween_interval(0.25)
			tween.tween_property(tuning_knob, "rotation:z", 0.0, 0.4)
		"tray":
			device_action.emit("tray_open")
			var rest: Vector3 = tray.position
			tween.tween_property(tray, "position", rest + Vector3(0, 0, 0.62), 0.45)
			tween.tween_interval(0.8)
			tween.tween_callback(func() -> void: device_action.emit("tray_close"))
			tween.tween_property(tray, "position", rest, 0.45)
		_:
			interaction_busy = false
			return
	await tween.finished
	interaction_busy = false

func _toggle_power() -> void:
	powered = not powered
	if terminal_ui != null:
		terminal_ui.set_display_powered(powered)
	device_action.emit("power_on" if powered else "power_off")
	if not powered and terminal_ui != null:
		terminal_ui.boot_audio.stop_all()
	var bounce: OmniLight3D = get_node_or_null("ScreenBounce") as OmniLight3D
	if bounce != null:
		bounce.visible = powered
	screen.material_override = screen_on if powered else screen_off

func update_screen_tint() -> void:
	var colors: Array[Color] = [Color(1, 1, 1), Color(1.35, 0.85, 0.45), Color(0.65, 1.0, 1.4)]
	var tint: Color = colors[clampi(screen_palette, 0, colors.size() - 1)]
	screen_on.albedo_color = Color(tint.r * screen_brightness, tint.g * screen_brightness, tint.b * screen_brightness)

func _hitbox(parent: Node3D, size: Vector3, action: String) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Hit_" + action
	body.set_meta("action", action)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)

func _label(parent: Node3D, text: String, at: Vector3, pixel: float, font_size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = pixel
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _material(mesh: MeshInstance3D, color: Color) -> void:
	var smooth: StandardMaterial3D = StandardMaterial3D.new()
	smooth.albedo_color = color
	smooth.roughness = 0.94
	smooth.metallic_specular = 0.0
	var toon: ShaderMaterial = ShaderMaterial.new()
	toon.shader = TOON_SHADER
	toon.set_shader_parameter("albedo", color)
	toon.set_shader_parameter("bands", 3.0)
	toon.set_shader_parameter("band_softness", 0.025)
	mesh.material_override = toon
	mesh.set_meta("smooth_material", smooth)
	mesh.set_meta("toon_material", toon)
	material_pairs.append({"mesh": mesh, "smooth": smooth, "toon": toon})

func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color, bevel: float = 0.0) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.position = at
	if bevel > 0.0:
		node.mesh = _bevel_mesh(size, bevel)
	else:
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		node.mesh = box
	_material(node, color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = cylinder
	node.position = at
	_material(node, color)
	parent.add_child(node)
	return node

func _bevel_mesh(size: Vector3, requested: float) -> ArrayMesh:
	var bevel: float = minf(requested, minf(size.x, minf(size.y, size.z)) * 0.45)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for index: int in range(4):
		var inset: float = bevel if index == 0 or index == 3 else 0.0
		var w: float = size.x * 0.5 - inset
		var h: float = size.y * 0.5 - inset
		var z: float = [-size.z * 0.5, -size.z * 0.5 + bevel, size.z * 0.5 - bevel, size.z * 0.5][index]
		var corner: float = minf(bevel, minf(w, h) * 0.45)
		rings.append(PackedVector3Array([Vector3(-w + corner,-h,z),Vector3(w-corner,-h,z),
			Vector3(w,-h+corner,z),Vector3(w,h-corner,z),Vector3(w-corner,h,z),
			Vector3(-w+corner,h,z),Vector3(-w,h-corner,z),Vector3(-w,-h+corner,z)]))
	for ring_index: int in range(3):
		for index: int in range(8):
			var next: int = (index + 1) % 8
			var a: Vector3 = rings[ring_index][index]
			var b: Vector3 = rings[ring_index][next]
			var c: Vector3 = rings[ring_index + 1][next]
			var d: Vector3 = rings[ring_index + 1][index]
			var normal: Vector3 = (b-a).cross(c-a).normalized()
			_quad(surface, a, b, c, d, normal)
	for index: int in range(8):
		var next: int = (index + 1) % 8
		_triangle(surface, Vector3(0,0,-size.z*0.5), rings[0][next], rings[0][index], Vector3.BACK * -1.0)
		_triangle(surface, Vector3(0,0,size.z*0.5), rings[3][index], rings[3][next], Vector3.BACK)
	return surface.commit()

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(surface,a,b,c,normal)
	_triangle(surface,a,c,d,normal)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot front faces use clockwise winding; supplied normals point outwards.
	for vertex: Vector3 in [a,c,b]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

# Recolor only the stand-in materials; imported textures should keep their own albedo.
func set_reference_style(enabled: bool) -> void:
	for pair: Dictionary in material_pairs:
		var mesh: MeshInstance3D = pair["mesh"]
		var smooth: StandardMaterial3D = pair["smooth"]
		var toon: ShaderMaterial = pair["toon"]
		if not mesh.has_meta("original_color"):
			mesh.set_meta("original_color", smooth.albedo_color)
		var polished: bool = str(mesh.name) in ["Housing", "Base", "Bezel", "PowerButton", "Dial", "TrayFace", "Pedestal"]
		smooth.roughness = 0.3 if polished else 0.75
		smooth.metallic_specular = 0.6 if polished else 0.18
		toon.set_shader_parameter("specular_strength", 0.65 if polished else 0.12)
		toon.set_shader_parameter("specular_size", 0.42 if polished else 0.22)
		var original: Color = mesh.get_meta("original_color")
		var color: Color = original
		if enabled:
			var part: String = str(mesh.name)
			if part.begins_with("Key_") or part in ["SpaceBar", "PowerButton", "DialMark", "FrontRail"]:
				color = Color("ffe5aa")
			elif part in ["Housing", "Base", "DeskSurface", "TrayFace"]:
				color = Color("d77b95")
			elif part in ["Bezel", "Pedestal", "DeskEdge"]:
				color = Color("718db7")
			elif part in ["ScreenRecess", "KeyboardWell", "Dial"]:
				color = Color("315e61")
			elif part in ["DeskMat", "Floor"]:
				color = Color("404563")
			smooth.albedo_color = color
			toon.set_shader_parameter("albedo", color)
		else:
			smooth.albedo_color = original
			toon.set_shader_parameter("albedo", original)
	var environment: Environment = (get_node("Environment") as WorldEnvironment).environment
	environment.background_color = Color("465578") if enabled else Color("111c22")
	environment.ambient_light_color = Color("abbcde") if enabled else Color("76857f")
	environment.ambient_light_energy = 0.12

func _setup_interactive_screen() -> void:
	var old_terminal: Node = get_node_or_null("TerminalTexture")
	if old_terminal != null:
		remove_child(old_terminal)
		old_terminal.queue_free()
	terminal_view = SubViewport.new()
	terminal_view.name = "InteractiveScreen"
	terminal_view.size = ScreenSurface.TEXTURE_SIZE
	terminal_view.disable_3d = true
	terminal_view.gui_disable_input = false
	terminal_view.gui_embed_subwindows = true
	terminal_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(terminal_view)
	terminal_ui = ScreenTerminal.new()
	terminal_view.add_child(terminal_ui)
	screen.mesh = ScreenSurface.make_mesh()
	_fit_imported_screen()
	_build_screen_hit_surface()
	screen_on = screen_on.duplicate() as StandardMaterial3D
	screen_on.albedo_texture = terminal_view.get_texture()
	screen_on.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_on.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen.material_override = screen_on
	# Keep the temporary housing behind the wider reference display.
	(get_node("Computer/ScreenRecess") as Node3D).visible = false
	(get_node("Computer/Bezel") as Node3D).visible = false
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.name = "ReferenceScreenRim"
	rim.mesh = ScreenSurface.make_mesh()
	rim.transform = screen.transform
	rim.position.z -= 0.012
	rim.scale = screen.scale * Vector3(1.035, 1.06, 1)
	rim.visible = screen_rim_enabled and not fitted_screen
	var rim_material: StandardMaterial3D = StandardMaterial3D.new()
	rim_material.albedo_color = Color("f2cf9c")
	rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim.material_override = rim_material
	screen.get_parent().add_child(rim)
	_frame_screen_views()

func _fit_imported_screen() -> void:
	var imported: MeshInstance3D = get_node_or_null("GeneratedProps/Computer/Model/world/geometry_0") as MeshInstance3D
	var profile_path: String = "res://art/screen/hi3d_computer.json"
	if imported == null or not FileAccess.file_exists(profile_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if not parsed is Dictionary:
		return
	var profile: Dictionary = parsed
	var model_to_computer: Transform3D = (screen.get_parent() as Node3D).global_transform.affine_inverse() * imported.global_transform
	var model_scale: Vector3 = model_to_computer.basis.get_scale()
	var center: Array = profile["center"]
	screen.mesh = ScreenSurface.make_fitted_mesh(profile, model_scale)
	screen.transform = Transform3D(model_to_computer.basis.orthonormalized(),
		model_to_computer * Vector3(float(center[0]), float(center[1]), float(center[2])))
	var fitted_size: Array = profile["size"]
	screen_size = Vector2(float(fitted_size[0]) * model_scale.x, float(fitted_size[1]) * model_scale.y)
	fitted_screen = true

func _build_screen_hit_surface() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "DisplaySurface"
	body.collision_layer = SCREEN_COLLISION_LAYER
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "GlassShape"
	var shape: ConcavePolygonShape3D = screen.mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	screen.add_child(body)

func _frame_screen_views() -> void:
	var screen_center: Vector3 = to_local(screen.global_position)
	var normal: Vector3 = (global_basis.inverse() * screen.global_basis.z).normalized()
	var camera_node: Camera3D = get_node("Camera") as Camera3D
	var aspect: float = 16.0 / 9.0
	var half_fov: float = tan(deg_to_rad(camera_node.fov * 0.5))
	var fit: float = maxf(screen_size.y / (2.0 * half_fov), screen_size.x / (2.0 * half_fov * aspect))
	var depth_margin: float = screen.get_aabb().size.z
	for entry: Array in [["Front", 1.5], ["ScreenClose", 1.18]]:
		var view: Node3D = get_node("Views/" + str(entry[0])) as Node3D
		(view.get_node("LookAt") as Node3D).position = screen_center
		(view.get_node("CameraPosition") as Node3D).position = screen_center + normal * (fit * float(entry[1]) + depth_margin)
