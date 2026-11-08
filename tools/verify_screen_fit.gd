extends SceneTree
var failures: Array[String] = []
var lab: Control

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await process_frame
	await physics_frame
	lab.set_print_preset(0)
	check(lab.desk.fitted_screen, "Imported computer uses its calibrated glass profile")
	check(lab.desk.screen.scale.is_equal_approx(Vector3.ONE), "Display must not retain the old nonuniform stretch")
	var bounds: AABB = lab.desk.screen.get_aabb()
	check(bounds.size.z > 0.1, "Display follows the glass depth, rather than floating on a front plane")
	var arrays: Array = lab.desk.screen.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var report: Array[Dictionary] = []
	for view: int in [0, 3, 1]:
		lab.select_view(view, true)
		await process_frame
		await physics_frame
		var tested: int = 0
		var maximum_error: float = 0
		for index: int in range(0, indices.size(), 273):
			var a: int = indices[index]
			var b: int = indices[index + 1]
			var c: int = indices[index + 2]
			var local_point: Vector3 = (vertices[a] + vertices[b] + vertices[c]) / 3.0
			var expected: Vector2 = (uvs[a] + uvs[b] + uvs[c]) / 3.0 * Vector2(lab.desk.ScreenSurface.TEXTURE_SIZE)
			var pixel: Vector2 = lab.camera.unproject_position(lab.desk.screen.to_global(local_point))
			if not Rect2(Vector2.ZERO, Vector2(lab.scene_view.size)).has_point(pixel):
				continue
			var at: Vector2 = lab.image.global_position + pixel / Vector2(lab.scene_view.size) * lab.image.size
			var actual: Vector2 = lab.screen_coordinates(at)
			var error: float = actual.distance_to(expected)
			maximum_error = maxf(maximum_error, error)
			check(error < 0.6, "Curved screen UV picking mismatch in view %d: %s vs %s" % [view, actual, expected])
			tested += 1
		check(tested >= 10, "Check enough surface points per view")
		if view in [0, 3]:
			for vertex: Vector3 in vertices:
				var projected: Vector2 = lab.camera.unproject_position(lab.desk.screen.to_global(vertex))
				check(Rect2(Vector2.ZERO, Vector2(lab.scene_view.size)).has_point(projected), "Screen is fully framed in view %d" % view)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://verification/screen_fit_view_%d.png" % view)
		report.append({"view": view, "points": tested, "max_error_pixels": maximum_error})
	var output: FileAccess = FileAccess.open("res://verification/screen_fit.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"size": str(lab.desk.screen_size), "bounds": str(bounds), "ray_checks": report, "failures": failures}, "\t"))
	output.close()
	print("SCREEN_FIT_VERIFY: ", "PASS" if failures.is_empty() else str(failures))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
