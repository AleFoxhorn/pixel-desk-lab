extends Camera3D
## One camera stays in the same viewport through every move. No render-pipeline switch.

var orbit_yaw: float = deg_to_rad(27.0)
var orbit_pitch: float = deg_to_rad(18.0)
var orbit_distance: float = 8.7
var focus_point: Vector3 = Vector3(0.0, 1.20, 0.25)
var active_view: int = 0
var motion: Tween = null
var focused_item: String = ""

func focus_bounds(bounds: AABB, item: String, pitch: float = 10.0) -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	focused_item = item
	active_view = -1
	cull_mask = 3
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var half_fov: float = tan(deg_to_rad(fov * 0.5))
	var height: float = bounds.size.y * cos(deg_to_rad(pitch)) + bounds.size.z * sin(deg_to_rad(pitch))
	var fit: float = maxf(height / (2.0 * half_fov), bounds.size.x / (2.0 * half_fov * aspect))
	var distance: float = maxf(2.5, fit * 1.35 + bounds.size.z * 0.5)
	var yaw_target: float = orbit_yaw + wrapf(-orbit_yaw, -PI, PI)
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self, "orbit_yaw", yaw_target, 0.85)
	motion.tween_property(self, "orbit_pitch", deg_to_rad(pitch), 0.85)
	motion.tween_property(self, "orbit_distance", distance, 0.85)
	motion.tween_property(self, "focus_point", bounds.get_center(), 0.85)
const VIEWS: Array[Dictionary] = [
	{"yaw": 27.0, "pitch": 18.0, "distance": 8.7, "focus": Vector3(0.0, 1.20, 0.25)},
	{"yaw": -65.0, "pitch": 15.0, "distance": 7.7, "focus": Vector3(0.0, 1.32, 0.20)},
	{"yaw": 162.0, "pitch": 18.0, "distance": 7.7, "focus": Vector3(0.0, 1.34, -0.1)},
	{"yaw": 4.0, "pitch": 3.0, "distance": 3.4, "focus": Vector3(0.0, 1.95, 0.82)},
	{"yaw": 0.0, "pitch": 10.0, "distance": 15.2, "focus": Vector3(-0.6, 1.30, -0.2)}
]

func _process(_delta: float) -> void:
	position = focus_point + Vector3(sin(orbit_yaw) * cos(orbit_pitch),
		sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
	look_at(focus_point)

func go_to(index: int, immediate: bool = false, side: int = 0) -> void:
	focused_item = ""
	if motion != null and motion.is_valid():
		motion.kill()
	active_view = clampi(index, 0, VIEWS.size() - 1)
	# Rear inspection is outside the cabin: omit its architectural backdrop.
	cull_mask = 1 if active_view == 2 else 3
	var view: Dictionary = VIEWS[active_view]
	var view_names: Array[String] = ["Front", "Side", "Rear", "ScreenClose", "Environment"]
	var saved_view: Node3D = get_parent().get_node_or_null("Views/" + view_names[active_view]) as Node3D
	if saved_view != null:
		var camera_marker: Marker3D = saved_view.get_node("CameraPosition") as Marker3D
		var focus_marker: Marker3D = saved_view.get_node("LookAt") as Marker3D
		var offset: Vector3 = camera_marker.position - focus_marker.position
		var radius: float = offset.length()
		view = {"yaw": rad_to_deg(atan2(offset.x, offset.z)),
			"pitch": rad_to_deg(asin(offset.y / radius)), "distance": radius, "focus": focus_marker.position}
	var yaw_target: float = orbit_yaw + wrapf(deg_to_rad(float(view["yaw"])) - orbit_yaw, -PI, PI)
	if active_view == 1 and side != 0:
		view = view.duplicate()
		view["yaw"] = 65.0 * float(side)
		yaw_target = orbit_yaw + wrapf(deg_to_rad(float(view["yaw"])) - orbit_yaw, -PI, PI)
	if immediate:
		orbit_yaw = yaw_target
		orbit_pitch = deg_to_rad(float(view["pitch"]))
		orbit_distance = float(view["distance"])
		focus_point = view["focus"]
		_process(0.0)
		return
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self, "orbit_yaw", yaw_target, 1.05)
	motion.tween_property(self, "orbit_pitch", deg_to_rad(float(view["pitch"])), 1.05)
	motion.tween_property(self, "orbit_distance", float(view["distance"]), 1.05)
	motion.tween_property(self, "focus_point", view["focus"], 1.05)
