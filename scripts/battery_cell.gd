extends Node3D
class_name BatteryCell

var is_collected: bool = false
@onready var trigger_area: Area3D = $TriggerArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var energy_light: OmniLight3D = $EnergyLight

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Gentle hover bob & rotation
	if mesh_instance:
		mesh_instance.rotation.y += delta * 2.0
		mesh_instance.position.y = 0.45 + sin(Time.get_ticks_msec() * 0.004) * 0.1
	
	if energy_light:
		energy_light.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.006) * 0.6

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	is_collected = true
	Global.play_sound("pickup")
	
	if CampaignManager:
		CampaignManager.update_objective("battery_cells", 1)
	
	# Particle burst
	var scene = get_tree().current_scene
	if scene:
		var p = CPUParticles3D.new()
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 16
		p.lifetime = 0.35
		p.direction = Vector3(0, 1, 0)
		p.spread = 75.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 6.0
		var quad = QuadMesh.new()
		quad.size = Vector2(0.08, 0.08)
		p.mesh = quad
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 0.7, 1.0)
		p.material_override = mat
		scene.add_child(p)
		p.global_position = global_position + Vector3(0, 0.5, 0)
		p.finished.connect(p.queue_free)
	
	queue_free()
