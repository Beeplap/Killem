extends StaticBody3D
class_name ChemicalValve

var is_purged: bool = false
var player_in_range: bool = false

@onready var trigger_area: Area3D = $TriggerArea
@onready var gas_particles: CPUParticles3D = $GasParticles
@onready var valve_mesh: MeshInstance3D = $MeshInstance3D
@onready var status_label_3d: Label3D = $StatusLabel3D

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
	update_display()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_purged:
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			purge_valve()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		update_display()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		update_display()

func purge_valve() -> void:
	if is_purged:
		return
	
	is_purged = true
	Global.play_sound("flame")
	
	if gas_particles:
		gas_particles.emitting = false
	
	if CampaignManager:
		CampaignManager.update_objective("purge_leaks", 1)
	
	update_display()

func update_display() -> void:
	if is_purged:
		if status_label_3d:
			status_label_3d.text = "VALVE PURGED\nLINE SEALED"
			status_label_3d.modulate = Color(0.2, 1.0, 0.4)
	else:
		if status_label_3d:
			if player_in_range:
				status_label_3d.text = "CHEMICAL LEAK DETECTED\nPRESS [E] TO PURGE VALVE"
				status_label_3d.modulate = Color(1.0, 0.4, 0.2)
			else:
				status_label_3d.text = "TOXIC LEAK HAZARD"
				status_label_3d.modulate = Color(0.9, 0.8, 0.1)
