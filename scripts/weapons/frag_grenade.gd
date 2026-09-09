class_name FragGrenade
extends Node2D

## Tactical M67 Frag Grenade Throwable
## Flung in a parabolic arc toward target_pos, bounces with a timed fuse, and detonates.

@export var damage: float = 140.0
@export var blast_radius: float = 130.0
@export var throw_duration: float = 0.52
@export var fuse_duration: float = 0.75

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_timer: float = 0.0
var fuse_timer: float = 0.0
var is_airborne: bool = true
var has_detonated: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var fuse_light: PointLight2D = get_node_or_null("FuseLight")

func _ready() -> void:
	z_index = 4
	top_level = true
	flight_timer = 0.0
	fuse_timer = fuse_duration

func launch(from: Vector2, to: Vector2) -> void:
	start_pos = from
	target_pos = to
	global_position = from
	flight_timer = 0.0
	is_airborne = true

func _process(delta: float) -> void:
	if has_detonated:
		return
	
	if is_airborne:
		flight_timer += delta
		var t = clampf(flight_timer / throw_duration, 0.0, 1.0)
		
		# Parabolic trajectory
		var current_ground = start_pos.lerp(target_pos, t)
		var height = sin(t * PI) * 55.0
		global_position = current_ground - Vector2(0, height)
		
		if sprite:
			sprite.rotation += delta * 14.0
		
		if t >= 1.0:
			is_airborne = false
			global_position = target_pos
			Global.play_sound("hit")
	else:
		# Armed ground fuse
		fuse_timer -= delta
		if sprite:
			# Fast blinking warning flash
			var blink = sin(Time.get_ticks_msec() * 0.025) > 0.0
			sprite.modulate = Color(2.0, 0.3, 0.3) if blink else Color(0.8, 0.8, 0.8)
		if fuse_light:
			fuse_light.enabled = true
			fuse_light.energy = 1.5 if sin(Time.get_ticks_msec() * 0.03) > 0.0 else 0.2
		
		if fuse_timer <= 0.0:
			detonate()

func detonate() -> void:
	if has_detonated:
		return
	has_detonated = true
	
	Global.play_sound("explode")
	Global.explosion_occurred.emit()
	Global.camera_trauma_requested.emit(0.75)
	
	# Damage nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= blast_radius:
				var falloff = 1.0 - (dist / blast_radius) * 0.4
				var dir = (enemy.global_position - global_position).normalized()
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage * falloff, dir)
	
	# Damage nearby destructibles
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if is_instance_valid(prop) and prop is Node2D:
			var dist = global_position.distance_to(prop.global_position)
			if dist <= blast_radius:
				if prop.has_method("take_damage"):
					prop.take_damage(damage * 1.1)
	
	# Spawn explosion particles and decals
	_spawn_fx()
	queue_free()

func _spawn_fx() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	# Blast fire/smoke particles
	var parts = CPUParticles2D.new()
	parts.global_position = global_position
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 28
	parts.lifetime = 0.55
	parts.spread = 180.0
	parts.initial_velocity_min = 80.0
	parts.initial_velocity_max = 240.0
	parts.scale_amount_min = 3.5
	parts.scale_amount_max = 7.0
	parts.color = Color(1.0, 0.55, 0.15, 1.0)
	parts.finished.connect(parts.queue_free)
	level.add_child(parts)
	
	# Expanding flash ring
	var ring = Node2D.new()
	ring.global_position = global_position
	ring.top_level = true
	level.add_child(ring)
	var tween = ring.create_tween()
	var duration = 0.28
	tween.tween_method(func(val: float):
		ring.queue_redraw()
	, 0.0, 1.0, duration)
	ring.draw.connect(func():
		var rad = lerpf(10.0, blast_radius, tween.get_total_elapsed_time() / duration)
		var alpha = lerpf(0.85, 0.0, tween.get_total_elapsed_time() / duration)
		ring.draw_circle(Vector2.ZERO, rad, Color(1.0, 0.65, 0.2, alpha * 0.35))
		ring.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, alpha), 3.0)
	)
	tween.tween_callback(ring.queue_free)
