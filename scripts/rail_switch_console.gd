extends Node3D
class_name RailSwitchConsole

signal switch_overridden

var is_overridden: bool = false
var player_in_range: bool = false

@onready var trigger_area: Area3D = $TriggerArea
@onready var status_label_3d: Label3D = $StatusLabel3D
@onready var terminal_light: OmniLight3D = $TerminalLight

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
	update_display()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_overridden:
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
			try_override()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		update_display()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		update_display()

func try_override() -> void:
	if is_overridden:
		return
	
	# Check if battery cells objective is completed
	var batteries_ready = false
	if CampaignManager:
		for obj in CampaignManager.active_objectives:
			if obj["id"] == "battery_cells" and obj["completed"]:
				batteries_ready = true
				break
	
	if not batteries_ready:
		Global.play_sound("hit")
		if status_label_3d:
			status_label_3d.text = "ERROR: INSUFFICIENT AUXILIARY POWER\nCOLLECT 2 BATTERY CELLS FIRST"
			status_label_3d.modulate = Color(1.0, 0.2, 0.2)
		return
	
	# Successful override
	is_overridden = true
	Global.play_sound("electric_zap")
	Global.play_sound("gate_slam")
	
	if terminal_light:
		terminal_light.light_color = Color(0.2, 1.0, 0.4)
	if status_label_3d:
		status_label_3d.text = "RAIL SWITCH OVERRIDDEN\nTRAIN ROUTE UNLOCKED"
		status_label_3d.modulate = Color(0.2, 1.0, 0.4)
	
	if CampaignManager:
		CampaignManager.update_objective("rail_switch", 1)
	
	switch_overridden.emit()

func update_display() -> void:
	if is_overridden:
		if status_label_3d:
			status_label_3d.text = "RAIL SWITCH ONLINE\nROUTE DIVERSIFIED"
			status_label_3d.modulate = Color(0.2, 1.0, 0.4)
		return
	
	if not player_in_range:
		if status_label_3d:
			status_label_3d.text = "RAIL SWITCH CONSOLE\n[STANDBY]"
			status_label_3d.modulate = Color(1.0, 0.7, 0.2)
	else:
		var count = 0
		if CampaignManager:
			for obj in CampaignManager.active_objectives:
				if obj["id"] == "battery_cells":
					count = obj["current"]
					break
		
		if count >= 2:
			if status_label_3d:
				status_label_3d.text = "POWER RESTORED\nPRESS [E] TO THROW SWITCH"
				status_label_3d.modulate = Color(0.3, 1.0, 0.5)
		else:
			if status_label_3d:
				status_label_3d.text = "AUX POWER REQUIRED (%d/2 BATTERIES)\nPRESS [E] TO ATTEMPT" % count
				status_label_3d.modulate = Color(1.0, 0.3, 0.2)
