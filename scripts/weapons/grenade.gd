extends Node2D

## Tactical Fragmentation Grenade
## Thrown in a parabolic arc, bounces, arms fuse, then detonates with radial damage and camera shake.

@export var damage: float = 160.0
@export var explosion_radius: float = 140.0
@export var fuse_time: float = 1.1

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_duration: float = 0.55
var flight_time: float = 0.0
var in_flight: bool = true
var fuse_timer: float = 1.1

@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse_light: PointLight2D = get_node_or_null("FuseLight")

func _ready() -> void:
	fuse_timer = fuse_time

func launch(from_pos: Vector2, to_pos: Vector2) -> void:
	start_pos = from_pos
	target_pos = to_pos
	global_position = from_pos
	flight_time = 0.0
	in_flight = true

func _process(delta: float) -> void:
	if in_flight:
		flight_time += delta
		var t = clampf(flight_time / flight_duration, 0.0, 1.0)
		
		# Linear interpolation on ground plane + parabolic arc
		var current_ground = start_pos.lerp(target_pos, t)
		var arc_offset = sin(t * PI) * -50.0 # 50px arc peak
		global_position = current_ground + Vector2(0, arc_offset)
		
		if sprite:
			sprite.rotation += delta * 14.0
		
		if t >= 1.0:
			in_flight = false
			global_position = target_pos
			Global.play_sound("hit")
	else:
		fuse_timer -= delta
		
		# Flashing red fuse indicator
		if fuse_light:
			fuse_light.enabled = true
			var flash = sin(fuse_timer * 22.0) > 0.0
			fuse_light.color = Color(1.0, 0.15, 0.15, 1.0) if flash else Color(0.2, 0.0, 0.0, 0.0)
		
		if fuse_timer <= 0.0:
			detonate()

func detonate() -> void:
	Global.play_sound("explode")
	Global.explosion_occurred.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(18.0, 0.35)
	
	# Damage all enemies and destructibles within blast radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				var falloff = 1.0 - (dist / explosion_radius) * 0.5
				var blast_dir = (enemy.global_position - global_position).normalized()
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage * falloff, blast_dir)
	
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if is_instance_valid(prop) and prop is Node2D:
			var dist = global_position.distance_to(prop.global_position)
			if dist <= explosion_radius:
				var blast_dir = (prop.global_position - global_position).normalized()
				if prop.has_method("take_damage"):
					prop.take_damage(damage * 0.9, blast_dir)
	
	# Blast particles and smoke
	var level = get_tree().current_scene
	if level:
		var burst = CPUParticles2D.new()
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 24
		burst.lifetime = 0.45
		burst.spread = 180.0
		burst.initial_velocity_min = 120.0
		burst.initial_velocity_max = 280.0
		burst.scale_amount_min = 3.0
		burst.scale_amount_max = 6.0
		burst.color = Color(1.0, 0.65, 0.15, 1.0)
		burst.global_position = global_position
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)
		
		# Blast crater decal
		if DecalManager and DecalManager.has_method("spawn_blood_splat"):
			DecalManager.spawn_blood_splat(global_position, Vector2.RIGHT, 1.5)
	
	queue_free()
