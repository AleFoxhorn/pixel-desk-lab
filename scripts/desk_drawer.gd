extends Node3D
## Self-contained furniture motion and camera framing; the lab routes picked actions here.
signal open_changed(open: bool)

const CameraDirector: Script = preload("res://scripts/camera_director.gd")
const TRAVEL: float = 1.58
var is_open: bool = false
var slide_motion: Tween = null
var camera_motion: Tween = null
var interaction_host: Control = null
var return_view: Dictionary = {}
@onready var slide: Node3D = get_node("Slide") as Node3D
@onready var hitbox: StaticBody3D = get_node("Slide/HandleHit") as StaticBody3D

func _ready() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.has_method("pick"):
			interaction_host = ancestor as Control
			break
		ancestor = ancestor.get_parent()

func interact(action: String) -> void:
	if action == "desk_drawer":
		set_open(not is_open)
	elif action.begins_with("desk_file_") and is_open and interaction_host != null:
		interaction_host.call("open_desk_file", action.trim_prefix("desk_file_").to_int())

func set_open(open: bool, frame_contents: bool = true) -> void:
	if is_open == open:
		return
	is_open = open
	_set_files_pickable(false)
	if not open and interaction_host != null:
		var reader: Control = interaction_host.get("file_reader") as Control
		if reader != null:
			reader.call("close")
	if slide_motion != null and slide_motion.is_valid():
		slide_motion.kill()
	slide_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	slide_motion.tween_property(slide, "position:z", TRAVEL if open else 0.0, 0.65)
	slide_motion.tween_callback(_set_files_pickable.bind(open))
	if frame_contents and interaction_host != null:
		_frame_contents(open)
	open_changed.emit(open)

func _set_files_pickable(enabled: bool) -> void:
	for node: Node in get_node("Slide/Files").find_children("PaperHit", "StaticBody3D", true, false):
		(node as StaticBody3D).collision_layer = 1 if enabled else 0

func _frame_contents(open: bool) -> void:
	var camera: CameraDirector = interaction_host.get("camera") as CameraDirector
	if camera == null:
		return
	# A view button replaces camera.motion; respect a view chosen while the drawer is open.
	if not open and (return_view.is_empty() or camera.motion != camera_motion or camera.active_view != int(return_view["view"])):
		return_view.clear()
		return
	if open:
		# Save the original destination when reopening during the return transition.
		if return_view.is_empty() or camera.motion != camera_motion or camera.active_view != int(return_view["view"]):
			return_view = {"yaw": camera.orbit_yaw, "pitch": camera.orbit_pitch,
				"distance": camera.orbit_distance, "focus": camera.focus_point, "view": camera.active_view}
	if camera.motion != null and camera.motion.is_valid():
		camera.motion.kill()
	camera_motion = camera.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera.motion = camera_motion
	var focus: Vector3 = global_position + Vector3(0.0, 0.14, 0.72) if open else return_view["focus"]
	var yaw: float = camera.orbit_yaw + wrapf(deg_to_rad(14.0) - camera.orbit_yaw, -PI, PI) if open else float(return_view["yaw"])
	camera_motion.tween_property(camera, "orbit_yaw", yaw, 0.85)
	camera_motion.tween_property(camera, "orbit_pitch", deg_to_rad(34.0) if open else float(return_view["pitch"]), 0.85)
	camera_motion.tween_property(camera, "orbit_distance", 5.9 if open else float(return_view["distance"]), 0.85)
	camera_motion.tween_property(camera, "focus_point", focus, 0.85)
