extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://verification/" + file_name + ".png") == OK)
func run() -> void:
	var lab: Control = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await process_frame
	await physics_frame
	lab.select_view(4, true)
	await create_timer(0.5).timeout
	var poster: MeshInstance3D = lab.desk.get_node("CabinEnvironment/AtomicHeartPoster/Artwork") as MeshInstance3D
	assert(poster.is_visible_in_tree())
	assert((poster.material_override as StandardMaterial3D).albedo_texture != null)
	await capture("poster_environment")
	var bounds: AABB = poster.global_transform * poster.get_aabb()
	lab.camera.focus_bounds(bounds, "Poster", 0.0)
	await create_timer(1.0).timeout
	await capture("poster_close")
	print("POSTER_PREVIEW_OK: wall poster rendered in full scene and close-up")
	lab.queue_free()
	await process_frame
	quit()
