extends CharacterBody2D

@export var max_ammo: int = 200
@export var max_health: float = 120.0
@export var detection_radius: float = 420.0
@export var fire_rate: float = 10.0 # 10 rounds per second = 0.10 interval
@export var bullet_damage: float = 22.0

var current_ammo: int = 200
var current_health: float = 120.0
var fire_cooldown: float = 0.0
var target_enemy: Node2D = null
var barrel_angle: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_light: PointLight2D = $MuzzleLight

var bullet_pool: Node2D = null

func _ready() -> void:
	add_to_group("deployables")
	add_to_group("allies")
	current_ammo = max_ammo
	current_health = max_health
	if muzzle_light:
		muzzle_light.enabled = false
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 10), Vector2(0.95, 0.45))
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool")

func _physics_process(delta: float) -> void:
	if current_ammo <= 0 or current_health <= 0:
		return
	
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	# Find target
	if target_enemy == null or not is_instance_valid(target_enemy) or global_position.distance_to(target_enemy.global_position) > detection_radius:
		target_enemy = find_nearest_target()
	
	if target_enemy and is_instance_valid(target_enemy):
		var aim_dir = (target_enemy.global_position - global_position).normalized()
		barrel_angle = aim_dir.angle()
		if sprite:
			sprite.rotation = barrel_angle
		if muzzle:
			muzzle.position = aim_dir * 22.0
		
		if fire_cooldown <= 0.0:
			fire_shot(aim_dir)

func find_nearest_target() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist: float = detection_radius
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = enemy
	return nearest

func fire_shot(dir: Vector2) -> void:
	if current_ammo <= 0:
		expire()
		return
	
	current_ammo -= 1
	fire_cooldown = 1.0 / fire_rate
	
	if bullet_pool == null:
		bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	
	var spawn_pos = global_position + dir * 26.0
	var spread = randf_range(-0.08, 0.08)
	var final_dir = dir.rotated(spread)
	
	if bullet_pool and bullet_pool.has_method("spawn_bullet"):
		bullet_pool.spawn_bullet(spawn_pos, final_dir, bullet_damage, 900.0, 1.2)
	else:
		var bullet_scene = preload("res://scenes/Bullet.tscn")
		var b = bullet_scene.instantiate()
		b.global_position = spawn_pos
		b.direction = final_dir
		b.damage = bullet_damage
		b.speed = 900.0
		get_tree().current_scene.add_child(b)
	
	# Muzzle flash
	if muzzle_light:
		muzzle_light.enabled = true
		muzzle_light.position = dir * 26.0
		get_tree().create_timer(0.04).timeout.connect(func(): if muzzle_light: muzzle_light.enabled = false)
	
	Global.play_sound("rifle")
	
	if current_ammo <= 0:
		expire()

func take_damage(amount: float, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	if sprite:
		sprite.modulate = Color(1.8, 0.5, 0.5, 1.0)
		get_tree().create_timer(0.08).timeout.connect(func(): if sprite: sprite.modulate = Color.WHITE)
	if current_health <= 0:
		expire()

func expire() -> void:
	Global.play_sound("explode")
	var level = get_tree().current_scene
	if level:
		var parts = CPUParticles2D.new()
		parts.emitting = true
		parts.one_shot = true
		parts.explosiveness = 0.95
		parts.amount = 16
		parts.lifetime = 0.6
		parts.spread = 180.0
		parts.initial_velocity_min = 60.0
		parts.initial_velocity_max = 180.0
		parts.scale_amount_min = 3.0
		parts.scale_amount_max = 6.0
		parts.color = Color(0.3, 0.3, 0.35, 1.0)
		parts.global_position = global_position
		parts.finished.connect(parts.queue_free)
		level.add_child(parts)
	queue_free()
