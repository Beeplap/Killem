extends Node3D
class_name ExtractionZone

@export var required_objective_id: String = ""
var is_unlocked: bool = false
var has_evacuated: bool = false
var summary_data: Dictionary = {}
var countdown_timer: float = 6.0
var is_showing_summary: bool = false

@onready var trigger_area: Area3D = $TriggerArea
@onready var beacon_light: OmniLight3D = $BeaconLight
@onready var flare_particles: CPUParticles3D = $FlareParticles
@onready var ring_mesh: MeshInstance3D = $RingMesh
@onready var status_label_3d: Label3D = $StatusLabel3D
@onready var summary_canvas: CanvasLayer = $SummaryCanvas
@onready var summary_container: Control = $SummaryCanvas/SummaryContainer
@onready var title_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/TitleLabel
@onready var level_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/LevelLabel
@onready var kills_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/Grid/KillsVal
@onready var time_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/Grid/TimeVal
@onready var acc_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/Grid/AccVal
@onready var score_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/Grid/ScoreVal
@onready var proceed_btn: Button = $SummaryCanvas/SummaryContainer/Panel/VBox/ProceedButton
@onready var countdown_label: Label = $SummaryCanvas/SummaryContainer/Panel/VBox/CountdownLabel

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
	
	if summary_canvas:
		summary_canvas.visible = false
	
	if proceed_btn:
		proceed_btn.pressed.connect(_on_proceed_pressed)
	
	if CampaignManager:
		CampaignManager.objective_updated.connect(_on_objective_updated)
	
	# Initial lock state
	update_lock_state(false)
	check_unlock_condition()

func _process(delta: float) -> void:
	if not is_unlocked:
		# Slow amber pulse
		if beacon_light:
			var pulse = sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5
			beacon_light.light_energy = 1.2 + pulse * 0.8
	else:
		# Rapid green strobe
		if beacon_light:
			var pulse = sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
			beacon_light.light_energy = 2.5 + pulse * 2.0
	
	if is_showing_summary and not has_evacuated:
		countdown_timer -= delta
		if countdown_label:
			countdown_label.text = "PROCEEDING IN %d SECONDS (OR PRESS [SPACE] / CLICK)" % max(0, int(ceil(countdown_timer)))
		if countdown_timer <= 0.0:
			proceed_to_next()

func _unhandled_input(event: InputEvent) -> void:
	if is_showing_summary and not has_evacuated:
		if event.is_action_pressed("dodge_roll") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
			proceed_to_next()

func _on_objective_updated(_obj_id: String, _text: String, _cur: int, _tgt: int, _done: bool) -> void:
	check_unlock_condition()

func check_unlock_condition() -> void:
	if is_unlocked:
		return
	
	if CampaignManager and CampaignManager.are_all_objectives_complete():
		unlock_zone()

func unlock_zone() -> void:
	is_unlocked = true
	update_lock_state(true)
	Global.play_sound("wave_clear")

func update_lock_state(unlocked: bool) -> void:
	if unlocked:
		if beacon_light:
			beacon_light.light_color = Color(0.1, 1.0, 0.45)
		if flare_particles:
			flare_particles.emitting = true
		if status_label_3d:
			status_label_3d.text = "EXTRACTION ACTIVE\nPROCEED TO EVACUATION"
			status_label_3d.modulate = Color(0.2, 1.0, 0.4)
		if ring_mesh:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.1, 0.95, 0.4, 0.65)
			ring_mesh.material_override = mat
	else:
		if beacon_light:
			beacon_light.light_color = Color(1.0, 0.5, 0.1)
		if flare_particles:
			flare_particles.emitting = false
		if status_label_3d:
			status_label_3d.text = "EXTRACTION LOCKED\nOBJECTIVES INCOMPLETE"
			status_label_3d.modulate = Color(1.0, 0.6, 0.2)
		if ring_mesh:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.4, 0.1, 0.35)
			ring_mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if has_evacuated:
		return
	
	if body.is_in_group("player"):
		if not is_unlocked:
			# Temporary warning
			Global.play_sound("hit")
			return
		
		trigger_extraction(body)

func trigger_extraction(player: Node3D) -> void:
	has_evacuated = true
	is_showing_summary = true
	countdown_timer = 5.0
	
	if player:
		if player.get("is_invulnerable") != null:
			player.is_invulnerable = true
		player.set_physics_process(false)
	
	Global.play_sound("wave_clear")
	
	if CampaignManager:
		summary_data = CampaignManager.get_mission_summary()
		CampaignManager.save_player_state(player)
		CampaignManager.mission_completed.emit(summary_data)
	
	display_summary(summary_data)

func display_summary(data: Dictionary) -> void:
	if not summary_canvas:
		proceed_to_next()
		return
	
	summary_canvas.visible = true
	
	if level_label:
		level_label.text = data.get("level_name", "MISSION COMPLETE")
	if kills_label:
		kills_label.text = str(data.get("kills", 0))
	if time_label:
		time_label.text = data.get("time_formatted", "00:00")
	if acc_label:
		acc_label.text = "%.1f%%" % data.get("accuracy", 100.0)
	if score_label:
		score_label.text = "+%d PTS" % data.get("score", 0)
	
	if proceed_btn:
		if data.get("is_final_level", false):
			proceed_btn.text = "CAMPAIGN COMPLETE - RETURN TO MAIN BASE"
		else:
			proceed_btn.text = "CONTINUE TO NEXT SECTOR"
	
	# Smooth fade-in
	if summary_container:
		summary_container.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(summary_container, "modulate:a", 1.0, 0.4)

func _on_proceed_pressed() -> void:
	proceed_to_next()

func proceed_to_next() -> void:
	has_evacuated = true
	is_showing_summary = false
	if CampaignManager:
		CampaignManager.load_next_level()
