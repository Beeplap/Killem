extends Area3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 35.0
var lifetime: float = 4.0
var timer: float = 0.0
var spin_axis: Vector3 = Vector3(1, 0.5, 0.2).normalized()
var spin_speed: float = 12.0

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(start_pos: Vector3, target_pos: Vector3, speed: float = 24.0, dmg: float = 35.0) -> void:
	global_position = start_pos
	damage = dmg
	
	var dir = (target_pos - start_pos)
	var horizontal_dist = Vector2(dir.x, dir.z).length()
	var travel_time = max(0.1, horizontal_dist / speed)
	
	# Parabolic / ballistic trajectory calculation
	var vx = dir.x / travel_time
	var vz = dir.z / travel_time
	var vy = (dir.y / travel_time) + 0.5 * 16.0 * travel_time
	
	velocity = Vector3(vx, vy, vz)

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		explode_boulder()
		return
	
	velocity.y -= 16.0 * delta # Gravity
	global_position += velocity * delta
	
	if mesh_instance:
		mesh_instance.rotate(spin_axis, spin_speed * delta)
	
	# If it touches the floor
	if global_position.y <= 0.2:
		explode_boulder()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("boss") or body.is_in_group("enemies"):
		return
	
	if body.is_in_group("player") or body.has_method("take_damage"):
		var hit_dir = velocity.normalized()
		body.take_damage(damage, hit_dir)
		explode_boulder()
	elif body is StaticBody3D or body.is_in_group("obstacles"):
		explode_boulder()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		var target = area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage, velocity.normalized())
		explode_boulder()

func explode_boulder() -> void:
	Global.play_sound("rock_impact")
	
	var scene = get_tree().current_scene
	if scene:
		var particles = CPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 18
		particles.lifetime = 0.45
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 75.0
		particles.initial_velocity_min = 5.0
		particles.initial_velocity_max = 12.0
		particles.gravity = Vector3(0, -14.0, 0)
		
		var box = BoxMesh.new()
		box.size = Vector3(0.22, 0.22, 0.22)
		particles.mesh = box
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_color = Color(0.35, 0.32, 0.28)
		mat.roughness = 0.9
		particles.material_override = mat
		
		scene.add_child(particles)
		particles.global_position = global_position
		particles.finished.connect(particles.queue_free)
	
	# Shake camera if player nearby
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_trauma"):
		var dist = global_position.distance_to(player.global_position)
		if dist < 12.0:
			player.add_trauma(lerp(0.5, 0.1, dist / 12.0))
	
	queue_free()
