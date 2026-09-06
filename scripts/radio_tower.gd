extends StaticBody3D
class_name RadioTower

signal sos_transmitted

var is_transmitted: bool = false
var player_in_range: bool = false

@onready var trigger_area: Area3D = $TriggerArea
@onready var beacon_light: OmniLight3D = $BeaconLight
@onready var status_label_3d: Label3D = $StatusLabel3D

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
	update_display()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_transmitted:
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			transmit_sos()

func _process(delta: float) -> void:
	if is_transmitted:
		if beacon_light:
			var pulse = sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5
			beacon_light.light_energy = 2.0 + pulse * 2.5
	else:
		if beacon_light:
			var pulse = sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5
			beacon_light.light_energy = 1.0 + pulse * 0.8

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		update_display()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		update_display()

func transmit_sos() -> void:
	if is_transmitted:
		return
	
	is_transmitted = true
	Global.play_sound("boss_alarm")
	Global.play_sound("wave_start")
	
	if beacon_light:
		beacon_light.light_color = Color(0.2, 0.7, 1.0)
	
	if CampaignManager:
		CampaignManager.update_objective("radio_tower", 1)
	
	update_display()
	sos_transmitted.emit()

func update_display() -> void:
	if is_transmitted:
		if status_label_3d:
			status_label_3d.text = "SOS TRANSMITTED • MILITARY EVAC DISPATCHED\nSURVIVE TITAN SIEGE"
			status_label_3d.modulate = Color(0.2, 1.0, 0.4)
	else:
		if status_label_3d:
			if player_in_range:
				status_label_3d.text = "MILITARY RADIO RELAY\nPRESS [E] TO TRANSMIT AIR EVAC SOS"
				status_label_3d.modulate = Color(0.3, 0.9, 1.0)
			else:
				status_label_3d.text = "RADIO TOWER [STANDBY]"
				status_label_3d.modulate = Color(1.0, 0.75, 0.2)
