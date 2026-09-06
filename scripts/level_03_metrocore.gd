extends Node3D

@onready var player: CharacterBody3D = $Player3D
@onready var radio_tower: RadioTower = $RadioTower
@onready var boss_trigger: BossArenaController = $BossArenaTrigger
@onready var extraction_zone: ExtractionZone = $ExtractionZone
@onready var enemies_container: Node3D = $Enemies

var siege_started: bool = false

func _ready() -> void:
	print("[CAMPAIGN] Initialized Level 3 - Fallen Metropolitan Core")
	
	if CampaignManager:
		CampaignManager.restore_player_state(player)
	
	if radio_tower:
		radio_tower.sos_transmitted.connect(_on_sos_transmitted)
	
	if boss_trigger:
		boss_trigger.arena_cleared.connect(_on_titan_defeated)

func _on_sos_transmitted() -> void:
	if siege_started:
		return
	siege_started = true
	
	Global.play_sound("boss_roar")
	Global.play_sound("wave_start")
	
	# Trigger Titan Siege waves
	spawn_siege_wave()
	
	# Mark siege survived after wave cleared
	var t = get_tree().create_timer(4.0)
	await t.timeout
	if CampaignManager:
		CampaignManager.update_objective("survive_siege", 1)

func spawn_siege_wave() -> void:
	var mut_scene = load("res://scenes/enemies/SuperMutant3D.tscn")
	var hound_scene = load("res://scenes/enemies/PlagueHound3D.tscn")
	
	if mut_scene and enemies_container:
		var m1 = mut_scene.instantiate()
		enemies_container.add_child(m1)
		m1.global_position = Vector3(6, 0.1, 4)
	
	if hound_scene and enemies_container:
		var h1 = hound_scene.instantiate()
		enemies_container.add_child(h1)
		h1.global_position = Vector3(-6, 0.1, 2)

func _on_titan_defeated() -> void:
	if CampaignManager:
		CampaignManager.update_objective("defeat_boss", 1)
	if extraction_zone:
		extraction_zone.check_unlock_condition()
