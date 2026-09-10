extends Node2D
class_name BossArenaTrigger2D

signal arena_locked
signal arena_cleared

@export var boss_scene: PackedScene = preload("res://scenes/enemies/bosses/GoliathBoss.tscn")
@export var boss_hud_scene: PackedScene = preload("res://scenes/ui/BossHUD.tscn")
@export var boss_name: String = "GOLIATH // BIO-WEAPON EXPERIMENT 00"
@export var auto_spawn_boss: bool = true

var is_locked_down: bool = false
var is_cleared: bool = false
var boss_instance: Node2D = null
var boss_hud: CanvasLayer = null

@onready var trigger_area: Area2D = get_node_or_null("TriggerArea")
@onready var gate_barrier: StaticBody2D = get_node_or_null("BlastGates/GateBarrier")
@onready var gate_polygon: CollisionPolygon2D = get_node_or_null("BlastGates/GateBarrier/CollisionPolygon2D")
@onready var gate_sprite: Sprite2D = get_node_or_null("BlastGates/GateSprite")
@onready var flame_particles: CPUParticles2D = get_node_or_null("BlastGates/FlameWallParticles")
@onready var boss_spawn_point: Marker2D = get_node_or_null("BossSpawnPoint")

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	
	# Initial gate state: open/unlocked
	if gate_barrier:
		gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	if gate_polygon:
		gate_polygon.set_deferred("disabled", true)
	if flame_particles:
		flame_particles.emitting = false
	if gate_sprite:
		gate_sprite.modulate.a = 0.0

func _on_trigger_body_entered(body: Node2D) -> void:
	if is_locked_down or is_cleared:
		return
	if body.is_in_group("player"):
		engage_lockdown()

func engage_lockdown() -> void:
	is_locked_down = true
	arena_locked.emit()
	
	# 1. Slam shut entrance blast gates & raise fire barricades
	if gate_barrier:
		gate_barrier.process_mode = Node.PROCESS_MODE_INHERIT
	if gate_polygon:
		gate_polygon.set_deferred("disabled", false)
	
	if gate_sprite:
		var tween = create_tween()
		tween.tween_property(gate_sprite, "modulate:a", 1.0, 0.35)
	
	if flame_particles:
		flame_particles.emitting = true
	
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
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.3)
	elif player and player.has_method("add_trauma"):
		player.add_trauma(0.5)
	
	# 2. Instantiate and awaken Boss entity at center of arena
	if auto_spawn_boss and boss_scene:
		boss_instance = boss_scene.instantiate()
		var level = get_tree().current_scene
		if level:
			level.add_child(boss_instance)
			if boss_spawn_point and "global_position" in boss_instance:
				boss_instance.global_position = boss_spawn_point.global_position
			elif "global_position" in boss_instance:
				boss_instance.global_position = global_position + Vector2(0, -180.0)
	
	# 3. Dedicated Boss HUD Overlay
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
	
	# 1. Lower blast barricades
	if gate_barrier:
		gate_barrier.process_mode = Node.PROCESS_MODE_DISABLED
	if gate_polygon:
		gate_polygon.set_deferred("disabled", true)
	if gate_sprite:
		var tween = create_tween()
		tween.tween_property(gate_sprite, "modulate:a", 0.0, 1.2)
	if flame_particles:
		flame_particles.emitting = false
	
	# 2. Waypoint beacon extraction alert
	Global.show_notification(
		"CONTAINMENT RESTORED",
		"EVACUATION CHOPPER READY • Proceed to extraction beacon",
		Color(0.3, 1.0, 0.45)
	)
