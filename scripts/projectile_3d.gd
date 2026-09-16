extends Area3D

enum ProjectileType { BULLET, SHOTGUN_PELLET, FLAME, MINIGUN_ROUND }

var damage: float = 35.0
var speed: float = 45.0
var lifetime: float = 1.8
var timer: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var projectile_type: ProjectileType = ProjectileType.BULLET

var _has_hit: bool = false
var pierce_count: int = 0
var _hit_entities: Array[Node] = []

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	collision_mask = 22
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
	_hit_entities.clear()
	
	match type:
		ProjectileType.BULLET:
			pierce_count = 1
		ProjectileType.SHOTGUN_PELLET:
			pierce_count = 0
		ProjectileType.FLAME:
			pierce_count = 3
		ProjectileType.MINIGUN_ROUND:
			pierce_count = 2
	
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
	if _has_hit:
		return
	if body.is_in_group("player"):
		return
	
	# If this body has a HitboxPart3D currently overlapping our projectile, let _on_area_entered resolve it
	var overlapping = get_overlapping_areas()
	for area in overlapping:
		if area is HitboxPart3D and (area.parent_entity == body or area.get_parent() == body or body.is_ancestor_of(area)):
			_on_area_entered(area)
			return
	
	if body.is_in_group("enemies") or body.has_method("take_damage"):
		if body in _hit_entities:
			return
		_hit_entities.append(body)
		
		_call_take_damage(body, damage, direction)
		HitmarkerManager.show_normal_hitmarker()
		DamageTextManager.spawn_text(global_position, "%d" % int(damage), Color.WHITE)
		spawn_hit_sparks(true, global_position, -direction)
		if projectile_type == ProjectileType.SHOTGUN_PELLET:
			Global.trigger_hitstop(0.04, 0.05)
		
		if pierce_count > 0:
			pierce_count -= 1
			damage *= 0.75
		else:
			_has_hit = true
			queue_free()
	elif body is StaticBody3D or body is CSGShape3D or body.is_in_group("obstacles") or body is GridMap:
		_has_hit = true
		spawn_hit_sparks(false, global_position, -direction)
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _has_hit:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		return
	if area is Interactable3D or area.name == "Interactable3D" or area.is_in_group("interactable"):
		return
	
	if area is HitboxPart3D:
		var parent = area.parent_entity if area.parent_entity else area.get_parent()
		if parent in _hit_entities:
			return # Avoid hitting multiple hitbox parts of the same entity with one bullet
		_hit_entities.append(parent)
		
		var hit_info = area.receive_damage(damage, direction)
		var hit_pos = global_position
		
		if hit_info.get("is_crit", false):
			HitmarkerManager.show_crit_hitmarker()
			DamageTextManager.spawn_text(hit_pos, "%d" % int(hit_info.damage), Color.YELLOW)
		else:
			HitmarkerManager.show_normal_hitmarker()
			DamageTextManager.spawn_text(hit_pos, "%d" % int(hit_info.damage), Color.WHITE)
		
		spawn_hit_sparks(true, hit_pos, -direction)
		if projectile_type == ProjectileType.SHOTGUN_PELLET:
			Global.trigger_hitstop(0.04, 0.05)
		
		if pierce_count > 0:
			pierce_count -= 1
			damage *= 0.75
		else:
			_has_hit = true
			queue_free()
		return
	
	var target = area if area.has_method("take_damage") else area.get_parent()
	if target and target.has_method("take_damage"):
		if target in _hit_entities:
			return
		_hit_entities.append(target)
		_call_take_damage(target, damage, direction)
		HitmarkerManager.show_normal_hitmarker()
		DamageTextManager.spawn_text(global_position, "%d" % int(damage), Color.WHITE)
		spawn_hit_sparks(true, global_position, -direction)
		
		if pierce_count > 0:
			pierce_count -= 1
			damage *= 0.75
		else:
			_has_hit = true
			queue_free()

func _call_take_damage(target: Object, dmg: float, dir: Vector3) -> void:
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	
	var method_list = target.get_method_list()
	var args_count: int = 1
	for m in method_list:
		if m["name"] == "take_damage":
			args_count = m["args"].size()
			break
	
	if args_count >= 2:
		target.take_damage(dmg, dir)
	else:
		target.take_damage(dmg)
