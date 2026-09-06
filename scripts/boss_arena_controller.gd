extends Node3D
class_name BossArenaController

signal arena_locked
signal arena_cleared

@export var boss_scene: PackedScene = preload("res://scenes/enemies/bosses/GoliathBoss3D.tscn")
@export var boss_hud_scene: PackedScene = preload("res://scenes/ui/BossHUD.tscn")
@export var boss_name: String = "GOLIATH - BIO-CONTAINMENT SUBJECT 0"
@export var auto_spawn_boss: bool = true

var is_locked_down: bool = false
var is_cleared: bool = false
var boss_instance: CharacterBody3D = null
var boss_hud: CanvasLayer = null

# Original environment colors for restoring after victory
var original_ambient_color: Color = Color(0.88, 0.9, 0.94, 1.0)
var original_fog_color: Color = Color(0.75, 0.78, 0.84, 1.0)
var env_node: WorldEnvironment = null

@onready var trigger_area: Area3D = $TriggerArea
@onready var blast_gate_barrier: StaticBody3D = $BlastGates/GateBarrier
@onready var blast_gate_mesh: Node3D = $BlastGates/GateMeshRoot
@onready var flame_wall_particles: CPUParticles3D = $BlastGates/FlameWallParticles
@onready var emergency_light_1: OmniLight3D = $ArenaLights/EmergencyLight1
@onready var emergency_light_2: OmniLight3D = $ArenaLights/EmergencyLight2
@onready var boss_spawn_point: Marker3D = $BossSpawnPoint

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	
	# Initial gate state: open/unlocked
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	if blast_gate_mesh:
		blast_gate_mesh.position.y = 5.0 # Raised up
	if flame_wall_particles:
		flame_wall_particles.emitting = false
	
	if emergency_light_1: emergency_light_1.visible = false
	if emergency_light_2: emergency_light_2.visible = false
	
	# Check if world environment is in parent/root
	env_node = get_tree().current_scene.find_child("WorldEnvironment", true, false)
	if env_node and env_node.environment:
		original_ambient_color = env_node.environment.ambient_light_color
		if env_node.environment.volumetric_fog_enabled:
			original_fog_color = env_node.environment.volumetric_fog_albedo

func _process(delta: float) -> void:
	if is_locked_down and not is_cleared:
		# Pulsing ominous crimson emergency lighting shift
		var pulse = (sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5)
		var crimson_pulse = Color(0.9, 0.08, 0.12).lerp(Color(0.5, 0.02, 0.04), pulse)
		
		if emergency_light_1:
			emergency_light_1.light_energy = 2.0 + pulse * 2.5
			emergency_light_1.light_color = crimson_pulse
		if emergency_light_2:
			emergency_light_2.light_energy = 2.0 + (1.0 - pulse) * 2.5
			emergency_light_2.light_color = crimson_pulse
		
		if env_node and env_node.environment:
			env_node.environment.ambient_light_color = env_node.environment.ambient_light_color.lerp(crimson_pulse, delta * 2.0)
			if env_node.environment.volumetric_fog_enabled:
				var target_fog = Color(0.5, 0.1, 0.15)
				env_node.environment.volumetric_fog_albedo = env_node.environment.volumetric_fog_albedo.lerp(target_fog, delta * 2.0)

func _on_trigger_body_entered(body: Node3D) -> void:
	if is_locked_down or is_cleared:
		return
	
	if body.is_in_group("player"):
		engage_lockdown()

func engage_lockdown() -> void:
	is_locked_down = true
	arena_locked.emit()
	
	# 1. Slam shut metal blast gates & raise flame walls
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_INHERIT
	
	if blast_gate_mesh:
		var tween = create_tween()
		tween.tween_property(blast_gate_mesh, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE)
	
	if flame_wall_particles:
		flame_wall_particles.emitting = true
	
	Global.play_sound("gate_slam")
	
	# Camera shake from gate slam
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.4)
	
	# 2. Trigger ominous crimson lighting shift
	if emergency_light_1: emergency_light_1.visible = true
	if emergency_light_2: emergency_light_2.visible = true
	Global.play_sound("boss_alarm")
	
	# 3. Instantiate or initialize Boss
	if auto_spawn_boss and boss_scene:
		boss_instance = boss_scene.instantiate()
		get_tree().current_scene.add_child(boss_instance)
		if boss_spawn_point:
			boss_instance.global_position = boss_spawn_point.global_position
		else:
			boss_instance.global_position = global_position + Vector3(0, 0, -10.0)
	
	# 4. Instantiate and animate Dedicated Boss HUD
	if boss_hud_scene:
		boss_hud = boss_hud_scene.instantiate()
		get_tree().current_scene.add_child(boss_hud)
		
		var max_hp = 2500.0
		if boss_instance:
			max_hp = boss_instance.max_health
			boss_instance.boss_health_changed.connect(boss_hud.update_boss_health)
			boss_instance.boss_phase_changed.connect(boss_hud.set_phase)
			boss_instance.boss_defeated_signal.connect(_on_boss_defeated)
		
		boss_hud.activate_boss(boss_name, max_hp, max_hp)

func _on_boss_defeated() -> void:
	is_cleared = true
	arena_cleared.emit()
	
	if boss_hud:
		boss_hud.boss_defeated()
	
	Global.play_sound("wave_clear")
	
	# 1. Open blast gates / raise them back up
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	
	if blast_gate_mesh:
		var tween = create_tween()
		tween.tween_property(blast_gate_mesh, "position:y", 5.0, 1.2).set_trans(Tween.TRANS_CUBIC)
	
	# 2. Extinguish flame walls
	if flame_wall_particles:
		flame_wall_particles.emitting = false
	
	# 3. Restore ambient environment lighting
	if emergency_light_1: emergency_light_1.visible = false
	if emergency_light_2: emergency_light_2.visible = false
	
	if env_node and env_node.environment:
		var tween = create_tween()
		tween.tween_property(env_node.environment, "ambient_light_color", original_ambient_color, 2.5)
		if env_node.environment.volumetric_fog_enabled:
			tween.parallel().tween_property(env_node.environment, "volumetric_fog_albedo", original_fog_color, 2.5)
