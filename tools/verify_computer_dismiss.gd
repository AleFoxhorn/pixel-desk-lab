extends SceneTree
## Real input regression for computer views, including empty space inside the old box.
var lab: Control
var failures: Array[String] = []
var hole_cases: int = 0
var other_prop_cases: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func find_point(kind: String) -> Vector2:
	var area: Rect2 = lab.image.get_global_rect()
	# Leave the UI bars out: they must retain their own GUI behavior.
	for y: int in range(90, 610, 16):
		for x: int in range(30, 1250, 16):
			var at: Vector2 = area.position + Vector2(float(x) / 1280.0, float(y) / 720.0) * area.size
			var contains: bool = lab.computer_contains(at)
			if kind == "outside" and not contains:
				return at
			if kind == "hole" and not contains and lab.computer_view_at(at).x >= 0:
				return at
			if kind == "other_prop" and not contains:
				var hit: Dictionary = lab.prop_input._pick(at, 8)
				if not hit.is_empty():
					var target: Node3D = (hit["collider"] as Node).get_meta("focus_target") as Node3D
					if target != null and str(target.name) != "Computer":
						return at
			if kind == "screen" and lab.screen_coordinates(at).x >= 0 and lab.prop_input._pick(at).is_empty():
				return at
			if kind == "body" and contains and lab.screen_coordinates(at).x < 0 and lab.prop_input._pick(at).is_empty():
				return at
	return Vector2(-1, -1)

func settle_view(index: int) -> void:
	lab.select_view(index, true)
	await process_frame
	await physics_frame

func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await create_timer(0.7).timeout
	check(lab.mode == 3 and lab.print_pass.visible, "Regression must run with the default stylized filter")
	check(lab.scene_view.size == Vector2i(640, 360), "Regression must run at the default pixel grid")
	for index: int in [0, 1, 2, 3]:
		await settle_view(index)
		var inside: Vector2 = find_point("body")
		check(inside.x >= 0, "View %d must expose a clickable computer body" % index)
		if inside.x >= 0:
			await click(inside)
			check(lab.camera.active_view != 4, "Inside body click must not dismiss view %d" % index)
		await settle_view(index)
		var hole: Vector2 = find_point("hole")
		if hole.x >= 0:
			hole_cases += 1
			print("COMPUTER_HOLE_CASE: view=", index, " at=", hole)
			await click(hole)
			check(lab.camera.active_view == 4, "Empty space inside old coarse box must dismiss view %d" % index)
		await settle_view(index)
		var other_prop: Vector2 = find_point("other_prop")
		if other_prop.x >= 0:
			other_prop_cases += 1
			await click(other_prop)
			check(lab.camera.active_view == 4 and lab.camera.focused_item.is_empty(), "Clicking another prop must exit first instead of focusing it")
			check(lab.prop_input.active.is_empty(), "Outside click must not activate the other prop's controls")
		await settle_view(index)
		var outside: Vector2 = find_point("outside")
		check(outside.x >= 0, "View %d must have outside scene space" % index)
		if outside.x >= 0:
			await click(outside)
			check(lab.camera.active_view == 4, "Outside click must dismiss view %d" % index)
	check(hole_cases > 0, "Test must cover the reported coarse-box empty-space bug")
	check(other_prop_cases > 0, "Test must cover an outside click on another prop")

	await settle_view(3)
	var screen_point: Vector2 = find_point("screen")
	check(screen_point.x >= 0, "Screen close view must expose screen input")
	if screen_point.x >= 0:
		await click(screen_point)
		check(lab.editing_screen, "Clicking screen must enter editing")
		check(lab.camera.active_view == 3, "Screen click must preserve screen close view")
		var outside: Vector2 = find_point("outside")
		if outside.x >= 0:
			await click(outside)
			check(lab.camera.active_view == 4 and not lab.editing_screen, "Outside click after editing must dismiss and release focus")
			check(not lab.desk.terminal_ui.password_input.has_focus(), "Dismiss must release password focus")

	await settle_view(0)
	if lab.prop_input.controls.has("computer.knob"):
		var pivot: Node3D = lab.prop_input.controls["computer.knob"]["pivot"] as Node3D
		var pixel: Vector2 = lab.camera.unproject_position(pivot.global_position)
		var at: Vector2 = lab.image.global_position + pixel / Vector2(lab.scene_view.size) * lab.image.size
		await click(at)
		check(lab.camera.active_view != 4, "Computer knob click must not dismiss the computer view")

	await settle_view(3)
	await click((lab.view_buttons[1] as Button).get_global_rect().get_center())
	check(lab.camera.active_view == 1, "Top view button must keep its GUI behavior instead of dismissing")
	await settle_view(3)
	await click((lab.view_buttons[4] as Button).get_global_rect().get_center())
	check(lab.camera.active_view == 4, "Environment button must still return to the overview")
	print("COMPUTER_DISMISS_VERIFY: ", "PASS" if failures.is_empty() else str(failures), " | coarse-box cases=", hole_cases, " | other-prop cases=", other_prop_cases)
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
