extends Area3D

enum ProjectileType { BULLET, SHOTGUN_PELLET, FLAME, MINIGUN_ROUND }

var damage: float = 35.0
var speed: float = 45.0
var lifetime: float = 1.8
var timer: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var projectile_type: ProjectileType = ProjectileType.BULLET

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	setup_visuals()

func setup(spawn_pos: Vector3, shoot_dir: Vector3, bullet_damage: float, bullet_speed: float, bullet_lifetime: float, type: ProjectileType = ProjectileType.BULLET) -> void:
	global_position = spawn_pos
	direction = shoot_dir.normalized()
	damage = bullet_damage
	speed = bullet_speed
	lifetime = bullet_lifetime
	projectile_type = type
	timer = 0.0
	
	# Orient projectile towards travel direction
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
	
	setup_visuals()

func setup_visuals() -> void:
	if not is_inside_tree() or mesh_instance == null:
		return
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	match projectile_type:
		ProjectileType.BULLET:
			mat.albedo_color = Color(1.0, 0.88, 0.45)
		ProjectileType.SHOTGUN_PELLET:
			mat.albedo_color = Color(1.0, 0.72, 0.25)
		ProjectileType.FLAME:
			mat.albedo_color = Color(1.0, 0.42, 0.1)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.85
		ProjectileType.MINIGUN_ROUND:
			mat.albedo_color = Color(1.0, 0.95, 0.65)
	
	mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	# Continuous translation on horizontal XZ plane
	global_position += direction * speed * delta
	
	timer += delta
	if timer >= lifetime:
		queue_free()

func spawn_hit_sparks(is_flesh: bool, hit_pos: Vector3, hit_normal: Vector3) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 12 if not is_flesh else 16
	particles.lifetime = 0.28
	
	var reflect_dir = -direction.reflect(hit_normal) if hit_normal != Vector3.ZERO else -direction
	particles.direction = reflect_dir
	particles.spread = 55.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 10.0
	particles.gravity = Vector3(0, -9.8, 0)
	
	# Quad mesh for particles
	var quad = QuadMesh.new()
	quad.size = Vector2(0.06, 0.06) if not is_flesh else Vector2(0.08, 0.08)
	particles.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	if is_flesh:
		mat.albedo_color = Color(0.8, 0.05, 0.05) # Crimson blood droplets
	else:
		mat.albedo_color = Color(1.0, 0.85, 0.3) # Ricochet spark
	particles.material_override = mat
	
	scene.add_child(particles)
	particles.global_position = hit_pos
	particles.finished.connect(particles.queue_free)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	
	if body.is_in_group("enemies") or body.has_method("take_damage"):
		body.take_damage(damage, direction)
		spawn_hit_sparks(true, global_position, -direction)
		if projectile_type == ProjectileType.SHOTGUN_PELLET:
			Global.trigger_hitstop(0.04, 0.05)
		queue_free()
	elif body is StaticBody3D or body is CSGShape3D or body.is_in_group("obstacles"):
		spawn_hit_sparks(false, global_position, -direction)
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.get_parent().is_in_group("player"):
		return
	
	var target = area if area.has_method("take_damage") else area.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(damage, direction)
		spawn_hit_sparks(true, global_position, -direction)
		queue_free()
