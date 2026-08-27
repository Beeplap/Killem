extends CharacterBody2D

enum ZombieType { REGULAR, INFECTED_DOG, HEAVY }

@export var zombie_type: ZombieType = ZombieType.REGULAR
@export var max_health: float = 80.0
@export var speed: float = 130.0
@export var attack_damage: float = 18.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.9
@export var score_value: int = 100

var current_health: float = 80.0
var attack_timer: float = 0.0
var hit_flash_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var player: Node2D = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	configure_type()
	current_health = max_health
	call_deferred("_find_player")

func configure_type() -> void:
	match zombie_type:
		ZombieType.REGULAR:
			max_health = 80.0
			speed = 130.0
			attack_damage = 18.0
			attack_range = 38.0
			attack_cooldown = 0.9
			score_value = 100
		
		ZombieType.INFECTED_DOG:
			max_health = 45.0
			speed = 240.0
			attack_damage = 14.0
			attack_range = 42.0
			attack_cooldown = 0.55
			score_value = 150
		
		ZombieType.HEAVY:
			max_health = 260.0
			speed = 75.0
			attack_damage = 40.0
			attack_range = 48.0
			attack_cooldown = 1.3
			score_value = 300

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
			queue_redraw()
	
	# Apply knockback decay
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	
	var target_pos = player.global_position
	var dist_to_player = global_position.distance_to(target_pos)
	
	# Rotate towards player or path
	look_at(target_pos)
	
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

func perform_attack() -> void:
	if player and player.has_method("take_damage"):
		var push_dir = (player.global_position - global_position).normalized()
		player.take_damage(attack_damage, push_dir)
		attack_timer = attack_cooldown
		Global.play_sound("zombie_groan")

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0.0:
		return
	
	current_health -= amount
	hit_flash_timer = 0.08
	queue_redraw()
	
	# Knockback (Heavy has high resistance)
	var knockback_scale = 180.0 if zombie_type != ZombieType.HEAVY else 40.0
	knockback_velocity += hit_direction.normalized() * knockback_scale
	
	if current_health <= 0.0:
		die(hit_direction)

func die(hit_direction: Vector2) -> void:
	Global.add_kill(score_value)
	
	# Spawn permanent blood decal on ground
	spawn_blood_splat(hit_direction)
	
	# Roll loot table (40% Health, 40% Ammo, 20% Nothing)
	roll_loot()
	
	queue_free()

func spawn_blood_splat(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if level:
		var blood = Node2D.new()
		blood.set_script(preload("res://scripts/blood_splat.gd"))
		blood.global_position = global_position
		blood.rotation = hit_dir.angle() + randf_range(-0.4, 0.4)
		level.add_child(blood)

func roll_loot() -> void:
	var roll = randf()
	if roll < 0.40:
		# Health drop
		spawn_pickup(0) # 0 = Health
	elif roll < 0.80:
		# Ammo drop
		spawn_pickup(1) # 1 = Ammo

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
	
	match zombie_type:
		ZombieType.REGULAR:
			var skin = Color(1.0, 0.4, 0.4) if flash else Color(0.35, 0.48, 0.28)
			var shirt = Color(0.24, 0.32, 0.38)
			# Shoulders / rot arms reaching forward
			draw_circle(Vector2(6, -11), 5.5, skin)
			draw_circle(Vector2(6, 11), 5.5, skin)
			draw_rect(Rect2(8, -12, 16, 5), skin)
			draw_rect(Rect2(8, 7, 16, 5), skin)
			# Torso
			draw_circle(Vector2(0, 0), 13.0, shirt)
			# Head with open jaw
			draw_circle(Vector2(1, 0), 8.5, skin)
			draw_circle(Vector2(4, -2), 1.5, Color(0.8, 0.1, 0.1)) # Red glowing eye
			draw_circle(Vector2(4, 2), 1.5, Color(0.8, 0.1, 0.1))
		
		ZombieType.INFECTED_DOG:
			var dog_skin = Color(1.0, 0.5, 0.5) if flash else Color(0.55, 0.28, 0.20)
			var teeth = Color(0.95, 0.95, 0.95)
			# Elongated feral canine body
			draw_rect(Rect2(-14, -6, 26, 12), dog_skin)
			# Snout & Fangs
			draw_polygon(PackedVector2Array([Vector2(12, -4), Vector2(24, 0), Vector2(12, 4)]), [dog_skin])
			draw_circle(Vector2(20, -1), 1.5, teeth)
			draw_circle(Vector2(20, 1), 1.5, teeth)
			# Paws
			draw_circle(Vector2(8, -8), 3.5, dog_skin)
			draw_circle(Vector2(8, 8), 3.5, dog_skin)
			draw_circle(Vector2(-10, -8), 3.5, dog_skin)
			draw_circle(Vector2(-10, 8), 3.5, dog_skin)
		
		ZombieType.HEAVY:
			var brute_skin = Color(1.0, 0.4, 0.4) if flash else Color(0.42, 0.35, 0.32)
			var armor = Color(0.18, 0.18, 0.20)
			# Massive brute torso
			draw_circle(Vector2(0, 0), 22.0, brute_skin)
			draw_rect(Rect2(-12, -14, 24, 28), armor)
			# Massive shoulders
			draw_circle(Vector2(10, -16), 9.0, brute_skin)
			draw_circle(Vector2(10, 16), 9.0, brute_skin)
			draw_rect(Rect2(12, -16, 20, 8), brute_skin)
			draw_rect(Rect2(12, 8, 20, 8), brute_skin)
			# Head
			draw_circle(Vector2(4, 0), 11.0, brute_skin)
			draw_circle(Vector2(8, -3), 2.5, Color(0.9, 0.2, 0.1))
			draw_circle(Vector2(8, 3), 2.5, Color(0.9, 0.2, 0.1))
