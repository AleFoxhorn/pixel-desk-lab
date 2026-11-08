extends Node
## Runtime tabletop mirror. Portrait bytes can arrive after the scene has already started.
const COLLISION_LAYER: int = 512
const PORTRAIT_PATH: String = "res://art/mirror/purple_girl_face.png"
const GLASS_RADIUS: Vector2 = Vector2(0.54, 0.68)
const PORTRAIT_FADE_SECONDS: float = 1.1
const MIRROR_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D portrait : source_color, filter_nearest, repeat_disable;
uniform bool portrait_ready = false;
uniform bool show_portrait = false;
uniform float portrait_opacity : hint_range(0.0,1.0) = 0.0;
uniform float portrait_saturation = 0.28;
float noise(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
void fragment() {
	vec2 uv = (floor(UV * 128.0) + vec2(0.5)) / 128.0;
	vec2 ellipse = (UV - vec2(0.5)) * 2.0;
	if (dot(ellipse, ellipse) > 1.0) { discard; }
	vec3 blue = mix(vec3(0.11,0.17,0.27),vec3(0.28,0.38,0.52),uv.y);
	float diagonal = uv.x + uv.y * 0.55;
	float band = step(0.35,diagonal) * (1.0-step(0.405,diagonal));
	band += step(0.49,diagonal) * (1.0-step(0.515,diagonal));
	blue = mix(blue,vec3(0.62,0.74,0.80),band*0.55);
	if (show_portrait && portrait_ready) {
		// Keep an empty reflective rim around the face, entirely inside the glass.
		vec2 face_position = ellipse / vec2(0.76,0.78);
		float face_radius = length(face_position);
		float face_mask = 1.0-smoothstep(0.55,1.0,face_radius);
		vec2 warped = face_position * (1.0+dot(face_position,face_position)*0.035);
		float clock = floor(TIME*5.0);
		float tear_y = fract(TIME*0.27)*2.0-1.0;
		float tear = step(0.83,noise(vec2(clock,7.0))) * (1.0-smoothstep(0.018,0.045,abs(face_position.y-tear_y)));
		warped.x += sin(face_position.y*9.0+TIME*1.7)*0.006 + tear*0.025;
		vec2 portrait_uv = clamp(warped*0.5+vec2(0.5),vec2(0.004),vec2(0.996));
		portrait_uv = (floor(portrait_uv*128.0)+vec2(0.5))/128.0;
		vec4 face = texture(portrait,portrait_uv);
		float luminance = dot(face.rgb,vec3(0.299,0.587,0.114));
		vec3 faded = mix(vec3(luminance),face.rgb,portrait_saturation);
		float scan = mod(floor(portrait_uv.y*128.0),3.0) < 1.0 ? 0.93 : 1.0;
		float grain = (noise(floor(portrait_uv*128.0)+vec2(floor(TIME*8.0),0.0))-0.5)*0.012;
		faded = clamp(faded*scan+grain,vec3(0.0),vec3(1.0));
		blue = mix(blue,faded,face.a*face_mask*0.93*portrait_opacity);
	}
	ALBEDO = blue;
}
"""
var lab: Control
var active: bool = false
var mirror_root: Node3D
var glass: MeshInstance3D
var body: StaticBody3D
var material: ShaderMaterial
var portrait_texture: ImageTexture
var portrait_poll: float = 0.0
var reveal_generation: int = 0
var reveal_motion: Tween = null
var fade_motion: Tween = null

func setup(host: Control) -> void:
	if mirror_root != null:
		return
	lab = host
	process_priority = 3
	mirror_root = Node3D.new()
	mirror_root.name = "DeskMirror"
	mirror_root.position = Vector3(-2.9, 0.325, 3.55)
	mirror_root.scale = Vector3.ONE * 0.68
	lab.desk.add_child(mirror_root)
	_box("Foot", Vector3(0,0.065,0.025), Vector3(1.08,0.13,0.61), "c77c98", 0.055)
	_box("FootTop", Vector3(0,0.137,0.015), Vector3(0.91,0.018,0.48), "e49aa8", 0.006)
	_box("FootInlay", Vector3(0,0.145,0.255), Vector3(0.85,0.015,0.018), "ffe0a9", 0.004)
	_box("Stem", Vector3(0,0.35,-0.035), Vector3(0.16,0.43,0.16), "718db7", 0.045)
	_box("StemWarmStripe", Vector3(0,0.35,0.052), Vector3(0.028,0.34,0.012), "f3d2a6", 0.004)
	_oval("BlueFrame", Vector2(0.66,0.80), 0.12, 0.0, "607caa")
	_oval("RoseBevel", Vector2(0.62,0.76), 0.07, 0.084, "d8839c")
	_oval("CreamLip", Vector2(0.575,0.715), 0.035, 0.132, "f3d2a6")
	glass = MeshInstance3D.new()
	glass.name = "MirrorGlass"
	glass.position = Vector3(0,1.075,0.157)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(48):
		var angle: float = TAU * float(index) / 48.0
		var next_angle: float = TAU * float(index+1) / 48.0
		for point: Vector2 in [Vector2.ZERO, Vector2(cos(next_angle),sin(next_angle)), Vector2(cos(angle),sin(angle))]:
			surface.set_normal(Vector3.BACK)
			surface.set_uv(Vector2(point.x*0.5+0.5,0.5-point.y*0.5))
			surface.add_vertex(Vector3(point.x*GLASS_RADIUS.x,point.y*GLASS_RADIUS.y,0))
	glass.mesh = surface.commit()
	var shader: Shader = Shader.new()
	shader.code = MIRROR_SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("show_portrait",false)
	material.set_shader_parameter("portrait_opacity",0.0)
	material.set_shader_parameter("portrait_saturation",0.28)
	glass.material_override = material
	mirror_root.add_child(glass)
	body = StaticBody3D.new()
	body.name = "MirrorHit"
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var points: PackedVector3Array = PackedVector3Array()
	for index: int in range(48):
		var angle: float = TAU * float(index) / 48.0
		for z: float in [-0.012,0.012]:
			points.append(Vector3(cos(angle)*GLASS_RADIUS.x,sin(angle)*GLASS_RADIUS.y,z))
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = points
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "OvalGlass"
	collision.shape = shape
	body.add_child(collision)
	glass.add_child(body)
	load_portrait(PORTRAIT_PATH)
	for button: Button in lab.view_buttons:
		button.pressed.connect(_clear)

func _box(node_name: String, at: Vector3, dimensions: Vector3, hex: String, bevel: float) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.position = at
	part.mesh = lab.desk._bevel_mesh(dimensions,bevel)
	part.material_override = _color(hex)
	mirror_root.add_child(part)

func _color(hex: String) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func _oval(node_name: String, radius: Vector2, thickness: float, z: float, hex: String) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.position = Vector3(0,1.075,z)
	part.rotation_degrees.x = 90.0
	part.scale = Vector3(radius.x,1.0,radius.y)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = thickness
	mesh.radial_segments = 48
	mesh.rings = 1
	part.mesh = mesh
	part.material_override = _color(hex)
	mirror_root.add_child(part)

func load_portrait(path: String = PORTRAIT_PATH) -> bool:
	if material == null or not FileAccess.file_exists(path):
		return false
	var picture: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if picture == null or picture.is_empty():
		return false
	# Resource adaptation for the requested pixel style, with no texture import dependency.
	picture.resize(128,128,Image.INTERPOLATE_NEAREST)
	portrait_texture = ImageTexture.create_from_image(picture)
	material.set_shader_parameter("portrait",portrait_texture)
	material.set_shader_parameter("portrait_ready",true)
	return true

func pick_mirror(at: Vector2) -> bool:
	if lab == null or glass == null or lab.camera.global_position.z <= glass.global_position.z:
		return false
	var mask: int = COLLISION_LAYER | lab.desk.COMPUTER_COLLISION_LAYER | lab.desk.SCREEN_COLLISION_LAYER | 4 | 8 | 1
	var hit: Dictionary = lab.pick(at,mask)
	return not hit.is_empty() and hit.get("collider") == body

func open() -> void:
	if lab == null or (lab.file_reader != null and lab.file_reader.visible):
		return
	if active and lab.camera.focused_item == "Mirror":
		return
	lab.prop_input.cancel()
	lab.end_screen_editing()
	if fade_motion != null and fade_motion.is_valid():
		fade_motion.kill()
	reveal_generation += 1
	active = true
	material.set_shader_parameter("show_portrait",false)
	material.set_shader_parameter("portrait_opacity",0.0)
	lab.camera.focus_bounds((glass.global_transform * glass.get_aabb()).grow(0.12),"Mirror",5.0,0.0)
	reveal_motion = lab.camera.motion
	reveal_motion.finished.connect(_reveal_portrait.bind(reveal_generation,reveal_motion.get_instance_id()),CONNECT_ONE_SHOT)
	for button: Button in lab.view_buttons:
		button.set_pressed_no_signal(false)

func _reveal_portrait(generation: int, motion_id: int) -> void:
	if generation != reveal_generation or not active or lab.camera.focused_item != "Mirror":
		return
	if reveal_motion == null or reveal_motion.get_instance_id() != motion_id or lab.camera.motion != reveal_motion:
		return
	if lab.file_reader != null and lab.file_reader.visible:
		return
	material.set_shader_parameter("show_portrait",true)
	fade_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_motion.tween_method(_set_portrait_opacity,0.0,1.0,PORTRAIT_FADE_SECONDS)

func _set_portrait_opacity(amount: float) -> void:
	material.set_shader_parameter("portrait_opacity",amount)

func _clear() -> void:
	if fade_motion != null and fade_motion.is_valid():
		fade_motion.kill()
	fade_motion = null
	reveal_generation += 1
	reveal_motion = null
	active = false
	if material != null:
		material.set_shader_parameter("show_portrait",false)
		material.set_shader_parameter("portrait_opacity",0.0)

func close() -> void:
	_clear()
	if lab != null:
		lab.select_view(4)

func _unhandled_input(event: InputEvent) -> void:
	if lab == null or (lab.file_reader != null and lab.file_reader.visible):
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_ESCAPE and active:
		close()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if pick_mirror(click.position):
		open()
	elif active:
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if lab == null:
		return
	if active and lab.camera.focused_item != "Mirror":
		_clear()
	if portrait_texture == null:
		portrait_poll += delta
		if portrait_poll >= 0.5:
			portrait_poll = 0.0
			load_portrait(PORTRAIT_PATH)
	if lab.file_reader != null and lab.file_reader.visible:
		return
	if pick_mirror(lab.get_global_mouse_position()):
		lab.status.text = "镜子 · 点击查看"
		lab.image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
