extends CharacterBody2D
class_name Zombie

const BLOOD_SPLAT_SCRIPT = preload("res://scripts/blood_splat.gd")

enum ZombieType { REGULAR, INFECTED_DOG, HEAVY, SPITTER, ARMORED, COLOSSUS }

@export var zombie_type: ZombieType = ZombieType.REGULAR
@export var wave_number: int = 1
@export var max_health: float = 70.0
@export var speed: float = 125.0
@export var attack_damage: float = 6.0
@export var attack_range: float = 38.0
@export var attack_cooldown: float = 0.9
@export var score_value: int = 100

var current_health: float = 70.0
var attack_timer: float = 0.0
var hit_flash_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var player: Node2D = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemies")
	configure_type()
	current_health = max_health
	
	# Hit-Flash shader material
	if sprite:
		var flash_mat = ShaderMaterial.new()
		flash_mat.shader = preload("res://shaders/hit_flash.gdshader")
		sprite.material = flash_mat
	
	# Bottom-offset black elliptical drop shadow quad (modulate.a = 0.45)
	var shadow_scale = Vector2(0.85, 0.42)
	if zombie_type == ZombieType.HEAVY:
		shadow_scale = Vector2(1.2, 0.58)
	elif zombie_type == ZombieType.ARMORED:
		shadow_scale = Vector2(1.05, 0.5)
	elif zombie_type == ZombieType.COLOSSUS:
		shadow_scale = Vector2(1.8, 0.85)
	elif zombie_type == ZombieType.INFECTED_DOG:
		shadow_scale = Vector2(0.75, 0.35)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 14), shadow_scale)
	
	call_deferred("_find_player")

func configure_type() -> void:
	var base_scale: float = 1.0
	
	match zombie_type:
		ZombieType.REGULAR:
			max_health = 70.0
			speed = 125.0
			attack_damage = 6.0 # Reduced from 18
			attack_range = 38.0
			attack_cooldown = 0.95
			score_value = 100
			base_scale = 1.0
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_regular_8dir.png")
				sprite.hframes = 8
		
		ZombieType.INFECTED_DOG:
			max_health = 40.0
			speed = 235.0
			attack_damage = 4.0 # Reduced from 14
			attack_range = 40.0
			attack_cooldown = 0.65
			score_value = 140
			base_scale = 0.95
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_dog_8dir.png")
				sprite.hframes = 8
		
		ZombieType.HEAVY:
			max_health = 250.0
			speed = 70.0
			attack_damage = 14.0 # Reduced from 40
			attack_range = 50.0
			attack_cooldown = 1.3
			score_value = 280
			base_scale = 1.35
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_heavy_8dir.png")
				sprite.hframes = 8
		
		ZombieType.SPITTER:
			max_health = 90.0
			speed = 145.0
			attack_damage = 6.0
			attack_range = 44.0
			attack_cooldown = 0.85
			score_value = 180
			base_scale = 1.05
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_spitter_8dir.png")
				sprite.hframes = 8
		
		ZombieType.ARMORED:
			max_health = 180.0
			speed = 105.0
			attack_damage = 8.5
			attack_range = 40.0
			attack_cooldown = 1.0
			score_value = 250
			base_scale = 1.12
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_armored_8dir.png")
				sprite.hframes = 8
		
		ZombieType.COLOSSUS:
			max_health = 750.0
			speed = 52.0
			attack_damage = 22.0
			attack_range = 65.0
			attack_cooldown = 1.6
			score_value = 850
			base_scale = 1.75
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_colossus_8dir.png")
				sprite.hframes = 8
	
	# Progressive growth in size as waves and time pass
	var wave_growth = 1.0 + min((wave_number - 1) * 0.045, 0.40)
	var final_scale = base_scale * wave_growth
	scale = Vector2(final_scale, final_scale)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if current_health <= 0.0:
		return
	
	if player == null or not is_instance_valid(player):
		_find_player()
		return
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("flash_amount", 0.0)
			elif sprite:
				sprite.modulate = Color.WHITE
	
	# Apply knockback decay
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	
	var target_pos = player.global_position
	var dist_to_player = global_position.distance_to(target_pos)
	
	# 8-Directional 2.5D Isometric orientation (do not rotate node, change sprite frame)
	var face_dir = (target_pos - global_position).normalized()
	update_facing(face_dir)
	
	# Pathfinding using NavigationAgent2D with direct fallback
	var move_dir: Vector2 = Vector2.ZERO
	if nav_agent and not nav_agent.is_navigation_finished():
		nav_agent.target_position = target_pos
		var next_path_pos = nav_agent.get_next_path_position()
		move_dir = (next_path_pos - global_position).normalized()
	
	# Fallback if navigation path is not ready or blocked
	if move_dir == Vector2.ZERO or nav_agent.is_target_reached():
		move_dir = (target_pos - global_position).normalized()
	
	if dist_to_player > (attack_range * 0.75):
		velocity = (move_dir * speed) + knockback_velocity
	else:
		velocity = knockback_velocity
		if attack_timer <= 0.0 and dist_to_player <= attack_range:
			perform_attack()
	
	move_and_slide()

func update_facing(face_dir: Vector2) -> void:
	var angle = face_dir.angle()
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	if sprite:
		sprite.frame = dir_idx % 8

func perform_attack() -> void:
	if player and player.has_method("take_damage"):
		var push_dir = (player.global_position - global_position).normalized()
		player.take_damage(attack_damage, push_dir)
		attack_timer = attack_cooldown
		Global.play_sound("zombie_groan")
		
		# Boss screen shake on impact
		if zombie_type == ZombieType.COLOSSUS and player.has_method("trigger_shake"):
			player.trigger_shake(8.0, 0.25)

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0.0:
		return
	
	# Armored zombie resists 40% of incoming bullet damage
	var effective_damage = amount
	if zombie_type == ZombieType.ARMORED:
		effective_damage *= 0.60
	
	current_health -= effective_damage
	hit_flash_timer = 0.08
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("flash_amount", 1.0)
	elif sprite:
		sprite.modulate = Color(1.8, 0.4, 0.4, 1.0)
	
	# Knockback resistance
	var knockback_scale = 180.0
	if zombie_type == ZombieType.HEAVY:
		knockback_scale = 40.0
	elif zombie_type == ZombieType.ARMORED:
		knockback_scale = 90.0
	elif zombie_type == ZombieType.COLOSSUS:
		knockback_scale = 15.0
	
	knockback_velocity += hit_direction.normalized() * knockback_scale
	
	if current_health <= 0.0:
		die(hit_direction)

func die(hit_direction: Vector2) -> void:
	Global.add_kill(score_value)
	spawn_blood_splat(hit_direction)
	
	# Micro-Hitstop freeze frame when killing a heavy zombie or boss
	if zombie_type in [ZombieType.HEAVY, ZombieType.ARMORED, ZombieType.COLOSSUS]:
		Global.trigger_hitstop(0.04, 0.05)
	
	if zombie_type == ZombieType.COLOSSUS:
		if player and player.has_method("trigger_shake"):
			player.trigger_shake(14.0, 0.4)
		# Colossus drops guaranteed health and ammo
		spawn_pickup(0)
		spawn_pickup(1)
	else:
		roll_loot()
		
	queue_free()

func spawn_blood_splat(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if level:
		BLOOD_SPLAT_SCRIPT.spawn_splat(level, global_position, hit_dir)

func roll_loot() -> void:
	var roll = randf()
	if roll < 0.40:
		spawn_pickup(0) # 0 = Health
	elif roll < 0.80:
		spawn_pickup(1) # 1 = Ammo

func spawn_pickup(pickup_type: int) -> void:
	var level = get_tree().current_scene
	if level:
		var pickup_scene = preload("res://scenes/Pickup.tscn")
		var pickup = pickup_scene.instantiate()
		pickup.global_position = global_position
		pickup.pickup_type = pickup_type
		level.add_child(pickup)
