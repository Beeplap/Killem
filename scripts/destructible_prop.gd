extends StaticBody2D

enum PropType { WOODEN_CRATE, TRASH_BAG, OIL_BARREL }

@export var prop_type: PropType = PropType.WOODEN_CRATE
@export var max_health: float = 35.0
@export var explosion_radius: float = 135.0
@export var explosion_damage: float = 120.0

var current_health: float = 35.0
var is_broken: bool = false
var hit_flash_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

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
	
	# Bottom-offset black elliptical drop shadow (modulate.a = 0.45)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 8), Vector2(0.85, 0.42))

func _process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0 and sprite:
			sprite.modulate = Color.WHITE

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return
	
	current_health -= amount
	hit_flash_timer = 0.08
	if sprite:
		sprite.modulate = Color(1.8, 0.7, 0.7, 1.0)
	
	# Spawn small impact sparks/chips on hit
	spawn_hit_sparks(hit_direction)
	
	if current_health <= 0.0:
		break_prop(hit_direction)

func spawn_hit_sparks(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	var sparks = CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 6
	sparks.lifetime = 0.25
	sparks.direction = -hit_dir if hit_dir != Vector2.ZERO else Vector2.UP
	sparks.spread = 45.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 140.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = Color(1.0, 0.85, 0.3) if prop_type == PropType.OIL_BARREL else Color(0.8, 0.65, 0.45)
	sparks.global_position = global_position
	sparks.finished.connect(sparks.queue_free)
	level.add_child(sparks)

func break_prop(hit_direction: Vector2) -> void:
	is_broken = true
	
	if prop_type == PropType.OIL_BARREL:
		trigger_explosion()
	
	# Spawn debris pieces and smoke
	spawn_debris(hit_direction)
	
	# Roll loot table (40% Health, 40% Ammo, 20% Nothing)
	roll_loot()
	
	queue_free()

func trigger_explosion() -> void:
	Global.play_sound("explode")
	Global.explosion_occurred.emit()
	
	var level = get_tree().current_scene
	if level:
		# 1. Transient bright explosion flash light
		var flash = PointLight2D.new()
		flash.texture = preload("res://assets/textures/lighting/point_light_cookie.png")
		flash.texture_scale = 3.2
		flash.color = Color(1.0, 0.65, 0.2)
		flash.energy = 3.5
		flash.global_position = global_position
		level.add_child(flash)
		
		# Fade flash over 0.25s
		var tween = level.create_tween()
		tween.tween_property(flash, "energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)
		
		# 2. Fire and thick smoke particles
		var smoke = CPUParticles2D.new()
		smoke.emitting = true
		smoke.one_shot = true
		smoke.explosiveness = 0.95
		smoke.amount = 28
		smoke.lifetime = 0.85
		smoke.spread = 180.0
		smoke.initial_velocity_min = 60.0
		smoke.initial_velocity_max = 240.0
		smoke.gravity = Vector2(0, -60)
		smoke.scale_amount_min = 6.0
		smoke.scale_amount_max = 16.0
		smoke.color = Color(0.22, 0.22, 0.25, 0.85)
		smoke.global_position = global_position
		smoke.finished.connect(smoke.queue_free)
		level.add_child(smoke)
		
		var fire = CPUParticles2D.new()
		fire.emitting = true
		fire.one_shot = true
		fire.explosiveness = 0.9
		fire.amount = 24
		fire.lifetime = 0.45
		fire.spread = 180.0
		fire.initial_velocity_min = 80.0
		fire.initial_velocity_max = 280.0
		fire.scale_amount_min = 4.0
		fire.scale_amount_max = 9.0
		fire.color = Color(1.0, 0.7, 0.1, 1.0)
		fire.global_position = global_position
		fire.finished.connect(fire.queue_free)
		level.add_child(fire)
	
	# Trigger hitstop for intense detonation feel
	Global.trigger_hitstop(0.045, 0.04)
	
	# Screen shake if player is nearby
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.35)
	
	# Damage entities in explosion radius
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
	
	# Interlinking fuel barrels cascading chain explosions within 180px
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if prop != self and is_instance_valid(prop) and not prop.get("is_broken"):
			var dist = global_position.distance_to(prop.global_position)
			if dist <= 180.0:
				# Guard: not all destructibles have prop_type (e.g. power_transformer)
				if "prop_type" in prop and prop.prop_type == PropType.OIL_BARREL:
					# Staggered cascade delay of 0.12s - 0.16s for dynamic chain detonation
					var delay = randf_range(0.12, 0.16)
					get_tree().create_timer(delay).timeout.connect(func():
						if is_instance_valid(prop) and not prop.get("is_broken"):
							prop.take_damage(explosion_damage * 1.5)
					)
				elif prop.has_method("take_damage"):
					prop.take_damage(explosion_damage * 0.8)

func spawn_debris(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var debris_color = Color(0.55, 0.38, 0.22)
	if prop_type == PropType.TRASH_BAG:
		debris_color = Color(0.18, 0.20, 0.22)
	elif prop_type == PropType.OIL_BARREL:
		debris_color = Color(0.75, 0.20, 0.15)
	
	# Shrapnel
	var part = CPUParticles2D.new()
	part.emitting = true
	part.one_shot = true
	part.explosiveness = 0.95
	part.amount = 14
	part.lifetime = 0.6
	part.direction = hit_dir if hit_dir != Vector2.ZERO else Vector2(randf_range(-1, 1), randf_range(-1, 1))
	part.spread = 80.0
	part.initial_velocity_min = 90.0
	part.initial_velocity_max = 220.0
	part.scale_amount_min = 3.0
	part.scale_amount_max = 7.0
	part.color = debris_color
	part.global_position = global_position
	part.finished.connect(part.queue_free)
	level.add_child(part)
	
	# Smoke puff
	var smoke = CPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.amount = 8
	smoke.lifetime = 0.7
	smoke.spread = 180.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 12.0
	smoke.color = Color(0.3, 0.32, 0.35, 0.6)
	smoke.global_position = global_position
	smoke.finished.connect(smoke.queue_free)
	level.add_child(smoke)

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
