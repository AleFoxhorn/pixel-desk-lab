extends SceneTree
var lab: Control
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func capture(file_name: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	check(not result.is_empty(), "Rendered frame must exist")
	check(result.save_png("res://verification/" + file_name + ".png") == OK, "Screenshot must save")
	return result

func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await create_timer(0.7).timeout
	check(lab.scene_view.size == Vector2i(640, 360), "Default scene must use a true 640 by 360 render grid")
	check(lab.print_material.get_shader_parameter("source_size") == Vector2(640, 360), "Paper pass must use the same pixel grid")
	var props: Node = lab.desk.find_child("GeneratedProps", true, false)
	var targets: Array[MeshInstance3D] = []
	for item: String in ["Computer", "Lamp", "Radio", "Recorder"]:
		var holder: Node = props.get_node(item)
		for child: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			if str(mesh.name) == "geometry_0":
				targets.append(mesh)
	check(targets.size() == 4, "All four imported hero props must be found")
	for mesh: MeshInstance3D in targets:
		var mat: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
		check(mat != null and mat.shader.resource_path.ends_with("textured_toon.gdshader"), "Imported prop must actually use textured toon")
		if mat != null:
			check(mat.get_shader_parameter("albedo_texture") != null, "Toon must retain the original asset texture")
			check(mat.next_pass != null, "Toon must have an outline pass")
	lab.set_mode(2)
	for mesh: MeshInstance3D in targets:
		check(mesh.get_active_material(0) is StandardMaterial3D, "Post-only mode must restore the original material")
	if DisplayServer.get_name() != "headless":
		await capture("toon_before_materials")
	lab.set_mode(3)
	if DisplayServer.get_name() != "headless":
		var frame: Image = await capture("toon_after_environment")
		var matched: int = 0
		var sampled: int = 0
		for y: int in range(100, 600, 6):
			for x: int in range(50, 1230, 6):
				sampled += 1
				if frame.get_pixel(x, y) == frame.get_pixel(x + 1, y) and frame.get_pixel(x, y) == frame.get_pixel(x, y + 1):
					matched += 1
		check(float(matched) / float(sampled) > 0.95, "Enlarged pixels must stay crisp through the paper pass")
		print("PIXEL_GRID_MATCH: ", matched, "/", sampled)
		lab.prop_input.focus_item(props.get_node("Radio") as Node3D)
		await create_timer(1.0).timeout
		await capture("toon_after_radio")
		lab.select_view(3, true)
		await capture("toon_after_screen")
	lab.resolution.select(2)
	lab._update_resolution()
	check(lab.scene_view.size == Vector2i(320, 180), "Heavy pixel option must remain available")
	check(lab.print_material.get_shader_parameter("source_size") == Vector2(320, 180), "Changing resolution must update paper sampling")
	lab.set_mode(0)
	check(lab.scene_view.size == Vector2i(1280, 720) and not lab.print_pass.visible, "Original mode must bypass the pixel effects")
	print("PIXEL_TOON_VERIFY: ", "PASS" if failures.is_empty() else str(failures))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
