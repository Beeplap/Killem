extends Node3D
class_name BossArenaTrigger

signal arena_locked
signal arena_cleared

@export var boss_scene: PackedScene = preload("res://scenes/enemies/bosses/GoliathBoss3D.tscn")
@export var boss_hud_scene: PackedScene = preload("res://scenes/ui/BossHUD.tscn")
@export var boss_name: String = "GOLIATH // BIO-WEAPON EXPERIMENT 00"
@export var auto_spawn_boss: bool = true

var is_locked_down: bool = false
var is_cleared: bool = false
var boss_instance: Node = null
var boss_hud: CanvasLayer = null

# Original environment colors for restoring after victory
var original_ambient_color: Color = Color(0.88, 0.9, 0.94, 1.0)
var original_fog_color: Color = Color(0.75, 0.78, 0.84, 1.0)
var env_node: WorldEnvironment = null

@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var blast_gate_barrier: StaticBody3D = get_node_or_null("BlastGates/GateBarrier")
@onready var blast_gate_mesh: Node3D = get_node_or_null("BlastGates/GateMeshRoot")
@onready var flame_wall_particles: CPUParticles3D = get_node_or_null("BlastGates/FlameWallParticles")
@onready var emergency_light_1: OmniLight3D = get_node_or_null("ArenaLights/EmergencyLight1")
@onready var emergency_light_2: OmniLight3D = get_node_or_null("ArenaLights/EmergencyLight2")
@onready var boss_spawn_point: Marker3D = get_node_or_null("BossSpawnPoint")

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	
	# Initial gate state: open/unlocked
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	if blast_gate_mesh:
		blast_gate_mesh.position.y = 5.0
	if flame_wall_particles:
		flame_wall_particles.emitting = false
	
	if emergency_light_1: emergency_light_1.visible = false
	if emergency_light_2: emergency_light_2.visible = false
	
	var cur_scene = get_tree().current_scene
	if cur_scene:
		env_node = cur_scene.find_child("WorldEnvironment", true, false)
		if env_node and env_node.environment:
			original_ambient_color = env_node.environment.ambient_light_color
			if env_node.environment.volumetric_fog_enabled:
				original_fog_color = env_node.environment.volumetric_fog_albedo

func _process(delta: float) -> void:
	if is_locked_down and not is_cleared:
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
	
	# 1. Slam shut metal blast gates & raise fire barricades
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_INHERIT
	
	if blast_gate_mesh:
		var tween = create_tween()
		tween.tween_property(blast_gate_mesh, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE)
	
	if flame_wall_particles:
		flame_wall_particles.emitting = true
	
	Global.play_sound("gate_slam")
	Global.play_sound("boss_alarm")
	
	# Alert Banner
	Global.show_notification(
		"THREAT LEVEL: APEX ABOMINATION DETECTED",
		"Perimeter lockdown engaged • Containment protocol active",
		Color(1.0, 0.15, 0.2)
	)
	
	# Camera shake from gate slam
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.5)
	elif player and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.3)
	
	# 2. Emergency lighting
	if emergency_light_1: emergency_light_1.visible = true
	if emergency_light_2: emergency_light_2.visible = true
	
	# 3. Instantiate and awaken Boss entity at center of arena
	if auto_spawn_boss and boss_scene:
		boss_instance = boss_scene.instantiate()
		var level = get_tree().current_scene
		if level:
			level.add_child(boss_instance)
			if boss_spawn_point and "global_position" in boss_instance:
				boss_instance.global_position = boss_spawn_point.global_position
			elif "global_position" in boss_instance:
				boss_instance.global_position = global_position + Vector3(0, 0, -10.0)
	
	# 4. Dedicated Boss HUD Overlay
	if boss_hud_scene:
		boss_hud = boss_hud_scene.instantiate()
		var level = get_tree().current_scene
		if level:
			level.add_child(boss_hud)
		
		var max_hp = 2500.0
		if boss_instance:
			if "max_health" in boss_instance:
				max_hp = boss_instance.max_health
			if boss_instance.has_signal("boss_health_changed"):
				boss_instance.boss_health_changed.connect(boss_hud.update_boss_health)
			if boss_instance.has_signal("boss_phase_changed"):
				boss_instance.boss_phase_changed.connect(boss_hud.set_phase)
			if boss_instance.has_signal("boss_defeated_signal"):
				boss_instance.boss_defeated_signal.connect(_on_boss_defeated)
		
		if boss_hud.has_method("activate_boss"):
			boss_hud.activate_boss(boss_name, max_hp, max_hp)

func _on_boss_defeated() -> void:
	is_cleared = true
	arena_cleared.emit()
	
	if boss_hud and boss_hud.has_method("boss_defeated"):
		boss_hud.boss_defeated()
	
	Global.play_sound("wave_clear")
	
	# 1. Open blast gates / lower barricades
	if blast_gate_barrier:
		blast_gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	
	if blast_gate_mesh:
		var tween = create_tween()
		tween.tween_property(blast_gate_mesh, "position:y", 5.0, 1.2).set_trans(Tween.TRANS_CUBIC)
	
	# 2. Extinguish flame walls
	if flame_wall_particles:
		flame_wall_particles.emitting = false
	
	# 3. Restore ambient lighting
	if emergency_light_1: emergency_light_1.visible = false
	if emergency_light_2: emergency_light_2.visible = false
	
	if env_node and env_node.environment:
		var tween = create_tween()
		tween.tween_property(env_node.environment, "ambient_light_color", original_ambient_color, 2.5)
		if env_node.environment.volumetric_fog_enabled:
			tween.parallel().tween_property(env_node.environment, "volumetric_fog_albedo", original_fog_color, 2.5)
	
	# 4. Waypoint beacon extraction alert
	Global.show_notification(
		"CONTAINMENT RESTORED",
		"EVACUATION CHOPPER READY • Proceed to extraction beacon",
		Color(0.3, 1.0, 0.45)
	)
