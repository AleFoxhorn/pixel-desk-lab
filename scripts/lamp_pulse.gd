extends OmniLight3D
## Slow warm breathing, with a matched luminous bulb and a real power switch.
@export var cycle_seconds: float = 3.8
@export var dim_energy: float = 0.22
@export var bright_energy: float = 1.15
var phase: float = 0.0
var powered: bool = true
var bulb: MeshInstance3D
var bulb_material: StandardMaterial3D

func attach_bulb(holder: Node3D, at: Vector3, radius: float) -> void:
	bulb = MeshInstance3D.new()
	bulb.name = "BreathingBulb"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.1
	bulb.mesh = sphere
	bulb.position = at
	bulb_material = StandardMaterial3D.new()
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.emission_enabled = true
	bulb_material.emission = Color("ffcc82")
	bulb.material_override = bulb_material
	holder.add_child(bulb)
	_update_light()

func set_powered(enabled: bool) -> void:
	powered = enabled
	visible = enabled
	if bulb != null:
		bulb.visible = enabled
	_update_light()

func _process(delta: float) -> void:
	if not powered:
		return
	phase = fposmod(phase + delta / maxf(cycle_seconds, 0.1), 1.0)
	_update_light()

func _update_light() -> void:
	var wave: float = (1.0 - cos(phase * TAU)) * 0.5
	light_energy = lerpf(dim_energy, bright_energy, wave) if powered else 0.0
	if bulb_material != null:
		bulb_material.albedo_color = Color("b68557").lerp(Color("fff0bc"), wave)
		bulb_material.emission_energy_multiplier = lerpf(0.15, 0.65, wave) if powered else 0.0
