extends Node3D

@onready var player: CharacterBody3D = $Player3D
@onready var boss_trigger: Node3D = $BossArenaTrigger
@onready var extraction_zone: Node3D = $ExtractionZone
@onready var chamber_gate_barrier: StaticBody3D = $ChamberGate/Barrier
@onready var chamber_gate_mesh: Node3D = $ChamberGate/GateMeshRoot

var keycard_ready: bool = false
var leaks_purged: bool = false

func _ready() -> void:
	print("[CAMPAIGN] Initialized Level 2 - Subterranean Research Labs")
	
	if CampaignManager:
		CampaignManager.restore_player_state(player)
		CampaignManager.objective_updated.connect(_on_objective_updated)
	
	if boss_trigger:
		boss_trigger.arena_cleared.connect(_on_boss_cleared)

func _on_objective_updated(id: String, _text: String, _cur: int, _tgt: int, done: bool) -> void:
	if id == "master_keycard" and done:
		keycard_ready = true
		check_chamber_access()
	elif id == "purge_leaks" and done:
		leaks_purged = true
		check_chamber_access()

func check_chamber_access() -> void:
	if keycard_ready and leaks_purged:
		Global.play_sound("gate_slam")
		# Open chamber gate
		if chamber_gate_barrier:
			chamber_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
		if chamber_gate_mesh:
			var tween = create_tween()
			tween.tween_property(chamber_gate_mesh, "position:y", 5.0, 1.2)

func _on_boss_cleared() -> void:
	if CampaignManager:
		CampaignManager.update_objective("defeat_boss", 1)
	if extraction_zone:
		extraction_zone.check_unlock_condition()
