extends Node3D
class_name MasterKeycard

var is_collected: bool = false
@onready var trigger_area: Area3D = $TriggerArea
@onready var card_light: OmniLight3D = $CardLight
@onready var status_label_3d: Label3D = $StatusLabel3D

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	if card_light:
		card_light.light_energy = 1.4 + sin(Time.get_ticks_msec() * 0.005) * 0.5

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	is_collected = true
	Global.play_sound("pickup")
	Global.play_sound("perk")
	
	if CampaignManager:
		CampaignManager.update_objective("master_keycard", 1)
	
	# Particle pickup
	var scene = get_tree().current_scene
	if scene:
		var p = CPUParticles3D.new()
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 18
		p.lifetime = 0.35
		p.direction = Vector3(0, 1, 0)
		p.spread = 65.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 6.0
		var quad = QuadMesh.new()
		quad.size = Vector2(0.08, 0.08)
		p.mesh = quad
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.2)
		p.material_override = mat
		scene.add_child(p)
		p.global_position = global_position + Vector3(0, 1.0, 0)
		p.finished.connect(p.queue_free)
	
	queue_free()
