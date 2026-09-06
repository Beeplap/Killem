extends Node3D

@onready var player: CharacterBody3D = $Player3D
@onready var rail_console: Node3D = $RailSwitchConsole
@onready var boss_trigger: Node3D = $BossArenaTrigger
@onready var extraction_zone: Node3D = $ExtractionZone
@onready var yard_gate_barrier: StaticBody3D = $YardGate/Barrier
@onready var yard_gate_mesh: Node3D = $YardGate/GateMeshRoot

func _ready() -> void:
	print("[CAMPAIGN] Initialized Level 1 - Quarantine Rail Depot")
	
	if CampaignManager:
		CampaignManager.restore_player_state(player)
	
	if rail_console:
		rail_console.switch_overridden.connect(_on_rail_switch_overridden)
	
	if boss_trigger:
		boss_trigger.arena_cleared.connect(_on_boss_cleared)

func _on_rail_switch_overridden() -> void:
	Global.play_sound("gate_slam")
	# Open yard gate
	if yard_gate_barrier:
		yard_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	if yard_gate_mesh:
		var tween = create_tween()
		tween.tween_property(yard_gate_mesh, "position:y", 5.0, 1.2)

func _on_boss_cleared() -> void:
	if CampaignManager:
		CampaignManager.update_objective("defeat_boss", 1)
	if extraction_zone:
		extraction_zone.check_unlock_condition()
