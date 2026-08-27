extends StaticBody2D

enum PropType { WOODEN_CRATE, TRASH_BAG, OIL_BARREL }

@export var prop_type: PropType = PropType.WOODEN_CRATE
@export var max_health: float = 35.0
@export var explosion_radius: float = 120.0
@export var explosion_damage: float = 110.0

var current_health: float = 35.0
var is_broken: bool = false
var hit_flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("obstacles")
	add_to_group("destructibles")
	match prop_type:
		PropType.WOODEN_CRATE:
			max_health = 35.0
		PropType.TRASH_BAG:
			max_health = 20.0
		PropType.OIL_BARREL:
			max_health = 25.0
	current_health = max_health

func _process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			queue_redraw()

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return
	
	current_health -= amount
	hit_flash_timer = 0.08
	queue_redraw()
	
	if current_health <= 0.0:
		break_prop(hit_direction)

func break_prop(hit_direction: Vector2) -> void:
	is_broken = true
	
	if prop_type == PropType.OIL_BARREL:
		trigger_explosion()
	
	# Spawn debris pieces
	spawn_debris(hit_direction)
	
	# Roll loot table (40% Health, 40% Ammo, 20% Nothing)
	roll_loot()
	
	queue_free()

func trigger_explosion() -> void:
	Global.play_sound("explode")
	
	# Screen shake if player is nearby
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.3)
	
	# Damage entities in explosion radius
	var space_state = get_world_2d().direct_space_state
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				var falloff = 1.0 - (dist / explosion_radius)
				var push = (enemy.global_position - global_position).normalized()
				enemy.take_damage(explosion_damage * falloff, push)
	
	if player and is_instance_valid(player):
		var p_dist = global_position.distance_to(player.global_position)
		if p_dist <= explosion_radius:
			var falloff = 1.0 - (p_dist / explosion_radius)
			var push = (player.global_position - global_position).normalized()
			player.take_damage(explosion_damage * 0.45 * falloff, push)
	
	# Chain react other destructibles
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if prop != self and is_instance_valid(prop) and not prop.is_broken:
			if global_position.distance_to(prop.global_position) <= explosion_radius:
				prop.take_damage(explosion_damage * 0.8)

func spawn_debris(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var debris_count = 5
	var debris_color = Color(0.55, 0.38, 0.22)
	if prop_type == PropType.TRASH_BAG:
		debris_color = Color(0.2, 0.22, 0.24)
	elif prop_type == PropType.OIL_BARREL:
		debris_color = Color(0.85, 0.25, 0.15)
	
	for i in range(debris_count):
		var part = CPUParticles2D.new()
		part.emitting = true
		part.one_shot = true
		part.explosiveness = 0.95
		part.amount = 8
		part.lifetime = 0.6
		part.direction = hit_dir if hit_dir != Vector2.ZERO else Vector2(randf_range(-1, 1), randf_range(-1, 1))
		part.spread = 70.0
		part.initial_velocity_min = 90.0
		part.initial_velocity_max = 240.0
		part.scale_amount_min = 3.0
		part.scale_amount_max = 7.0
		part.color = debris_color
		part.global_position = global_position
		level.add_child(part)

func roll_loot() -> void:
	var roll = randf()
	if roll < 0.40:
		spawn_pickup(0) # Health
	elif roll < 0.80:
		spawn_pickup(1) # Ammo

func spawn_pickup(pickup_type: int) -> void:
	var level = get_tree().current_scene
	if level:
		var pickup_scene = preload("res://scenes/Pickup.tscn")
		var pickup = pickup_scene.instantiate()
		pickup.global_position = global_position
		pickup.pickup_type = pickup_type
		level.add_child(pickup)

func _draw() -> void:
	var flash = hit_flash_timer > 0.0
	
	match prop_type:
		PropType.WOODEN_CRATE:
			var wood = Color(1.0, 0.6, 0.6) if flash else Color(0.55, 0.38, 0.22)
			var border = Color(0.35, 0.24, 0.12)
			# Outer square
			draw_rect(Rect2(-16, -16, 32, 32), wood)
			draw_rect(Rect2(-16, -16, 32, 32), border, false, 2.5)
			# Crossed wooden braces
			draw_line(Vector2(-14, -14), Vector2(14, 14), border, 2.0)
			draw_line(Vector2(-14, 14), Vector2(14, -14), border, 2.0)
		
		PropType.TRASH_BAG:
			var bag_color = Color(0.8, 0.8, 0.8) if flash else Color(0.18, 0.20, 0.22)
			var highlight = Color(0.32, 0.34, 0.38)
			# Irregular squished garbage sack
			draw_circle(Vector2(0, 2), 15.0, bag_color)
			draw_circle(Vector2(-4, -2), 11.0, bag_color)
			draw_circle(Vector2(5, -3), 10.0, bag_color)
			draw_circle(Vector2(0, -11), 5.0, highlight) # Tied knot
		
		PropType.OIL_BARREL:
			var barrel_color = Color(1.0, 0.5, 0.5) if flash else Color(0.75, 0.18, 0.12)
			var rim = Color(0.25, 0.12, 0.10)
			var hazard = Color(0.95, 0.85, 0.15)
			# Cylinder barrel body
			draw_circle(Vector2(0, 0), 16.0, barrel_color)
			draw_circle(Vector2(0, 0), 16.0, rim, false, 2.5)
			draw_circle(Vector2(0, 0), 9.0, rim, false, 1.5)
			# Biohazard skull / exclamation
			draw_circle(Vector2(0, 0), 4.5, hazard)
