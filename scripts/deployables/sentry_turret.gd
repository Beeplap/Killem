extends CharacterBody2D
class_name SentryTurretEntity

@export var max_ammo: int = 100
@export var max_health: float = 180.0
@export var detection_radius: float = 440.0
@export var fire_rate: float = 10.0 # 10 rounds per second = 0.10s interval
@export var bullet_damage: float = 24.0

var current_ammo: int = 100
var current_health: float = 180.0
var fire_cooldown: float = 0.0
var target_enemy: Node2D = null

var placement_rotation: float = 0.0
var is_depleted: bool = false
var needs_ammo: bool = false
var flash_timer: float = 0.0

@onready var turret_base: Sprite2D = $TurretBase
@onready var turret_head: Node2D = $TurretHead
@onready var head_sprite: Sprite2D = $TurretHead/HeadSprite
@onready var muzzle: Marker2D = $TurretHead/Muzzle
@onready var muzzle_light: PointLight2D = $TurretHead/MuzzleLight
@onready var needs_ammo_indicator: Node2D = get_node_or_null("NeedsAmmoIndicator")
@onready var ammo_label: Label = get_node_or_null("NeedsAmmoIndicator/Label")
@onready var ammo_icon: Sprite2D = get_node_or_null("NeedsAmmoIndicator/Icon")

var bullet_pool: Node2D = null

func _ready() -> void:
	add_to_group("deployables")
	add_to_group("turrets")
	add_to_group("allies")
	current_ammo = max_ammo
	current_health = max_health
	
	if turret_base:
		turret_base.rotation = placement_rotation
	if turret_head:
		turret_head.rotation = placement_rotation
		
	if muzzle_light:
		muzzle_light.enabled = false
	if needs_ammo_indicator:
		needs_ammo_indicator.visible = false
		
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 10), Vector2(1.0, 0.5))
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool")

func setup_placement(rot: float) -> void:
	placement_rotation = rot
	if turret_base:
		turret_base.rotation = rot
	if turret_head:
		turret_head.rotation = rot

func _physics_process(delta: float) -> void:
	if current_health <= 0.0:
		return
	
	# Depleted ammo state handling
	if current_ammo <= 0:
		if not is_depleted:
			set_depleted_state(true)
		
		# Flashing amber [NEEDS AMMO] indicator
		flash_timer += delta * 4.0
		if needs_ammo_indicator:
			needs_ammo_indicator.visible = true
			var alpha = 0.4 + sin(flash_timer) * 0.4
			needs_ammo_indicator.modulate = Color(1.0, 0.8, 0.2, clampf(alpha, 0.2, 1.0))
		return
	
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	# Find target
	if target_enemy == null or not is_instance_valid(target_enemy) or global_position.distance_to(target_enemy.global_position) > detection_radius or (target_enemy.has_method("is_dead") and target_enemy.is_dead()):
		target_enemy = find_nearest_target()
	
	if target_enemy and is_instance_valid(target_enemy):
		var to_target = target_enemy.global_position - global_position
		var target_angle = to_target.angle()
		
		# Only the upper swivel mount (TurretHead) rotates 360 to track approaching zombies
		if turret_head:
			turret_head.rotation = lerp_angle(turret_head.rotation, target_angle, delta * 12.0)
		
		if fire_cooldown <= 0.0 and abs(angle_difference(turret_head.rotation if turret_head else target_angle, target_angle)) < 0.25:
			fire_shot(Vector2.RIGHT.rotated(turret_head.rotation if turret_head else target_angle))
	else:
		# Idle sweep scan when no target is in range
		if turret_head:
			turret_head.rotation = placement_rotation + sin(Time.get_ticks_msec() * 0.0018) * 0.65

func set_depleted_state(depleted: bool) -> void:
	is_depleted = depleted
	needs_ammo = depleted
	if needs_ammo_indicator:
		needs_ammo_indicator.visible = depleted
	
	if turret_head:
		if depleted:
			# Barrel tilts downwards 30 degrees into deactivated pose
			var tween = create_tween()
			tween.tween_property(turret_head, "rotation", placement_rotation + deg_to_rad(30.0), 0.35)
		else:
			var tween = create_tween()
			tween.tween_property(turret_head, "rotation", placement_rotation, 0.25)

func reload_turret() -> void:
	current_ammo = max_ammo
	set_depleted_state(false)
	Global.play_sound("reload_bolt_rack")

func needs_service() -> bool:
	return is_depleted or current_ammo <= 0 or current_health < max_health

func get_service_prompt() -> String:
	return "Reload Turret (100 rounds)"

func get_service_duration() -> float:
	return 3.0

func perform_service() -> void:
	reload_turret()
	current_health = max_health

func find_nearest_target() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist: float = detection_radius
	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = enemy
	return nearest

func fire_shot(dir: Vector2) -> void:
	if current_ammo <= 0:
		set_depleted_state(true)
		return
	
	current_ammo -= 1
	fire_cooldown = 1.0 / fire_rate
	
	if bullet_pool == null:
		bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	
	var spawn_pos = muzzle.global_position if muzzle else global_position + dir * 26.0
	var spread = randf_range(-0.06, 0.06)
	var final_dir = dir.rotated(spread)
	
	if bullet_pool and bullet_pool.has_method("spawn_bullet"):
		bullet_pool.spawn_bullet(spawn_pos, final_dir, bullet_damage, 920.0, 1.2)
	else:
		var bullet_scene = preload("res://scenes/Bullet.tscn")
		var b = bullet_scene.instantiate()
		b.global_position = spawn_pos
		b.direction = final_dir
		b.damage = bullet_damage
		b.speed = 920.0
		get_tree().current_scene.add_child(b)
	
	# Muzzle flash
	if muzzle_light:
		muzzle_light.enabled = true
		get_tree().create_timer(0.04).timeout.connect(func(): if muzzle_light: muzzle_light.enabled = false)
	
	Global.play_sound("rifle")
	
	if current_ammo <= 0:
		set_depleted_state(true)

func take_damage(amount: float, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	if head_sprite:
		head_sprite.modulate = Color(1.8, 0.5, 0.5, 1.0)
		get_tree().create_timer(0.08).timeout.connect(func(): if head_sprite: head_sprite.modulate = Color.WHITE)
	if current_health <= 0.0:
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
