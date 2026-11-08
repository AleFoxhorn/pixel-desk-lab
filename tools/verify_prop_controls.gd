extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab: Control = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await process_frame
	var controller: Node = lab.get_node("PropInteractions")
	var holder: Node3D = Node3D.new()
	lab.desk.add_child(holder)
	controller._add(holder, AABB(Vector3.ZERO, Vector3.ONE), "test.knob", "Test", Vector3(0.5, 0.5, 1), true)
	controller.set_value("test.knob", 10)
	assert(controller.states["test.knob"] == 1.0)
	controller.active = "test.knob"
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(-90, 0)
	controller._input(motion)
	assert(is_equal_approx(controller.states["test.knob"], 0.5))
	assert(is_zero_approx(controller.controls["test.knob"]["pivot"].rotation.z))
	controller.cancel()
	assert(controller.active.is_empty())
	controller._add(holder, AABB(Vector3.ZERO, Vector3.ONE), "lamp.power", "Lamp", Vector3.ZERO, false)
	var light: OmniLight3D = OmniLight3D.new()
	holder.add_child(light)
	controller.lamp_light = light
	controller.set_value("lamp.power", 0)
	assert(not light.visible)
	controller.set_value("lamp.power", 1)
	assert(light.visible)
	controller.active = "lamp.power"
	var pivot: Node3D = controller.controls["lamp.power"]["pivot"]
	pivot.position.z -= 0.025
	controller._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(pivot.position == controller.controls["lamp.power"]["rest"])
	assert(controller.active.is_empty())
	lab.queue_free()
	await process_frame
	print("PROP_CONTROLS_VERIFY: PASS (drag, limits, retained angle, lamp light, focus cancellation)")
	quit()
