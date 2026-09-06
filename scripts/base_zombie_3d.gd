extends CharacterBody3D
class_name BaseZombie3D

signal enemy_died(enemy: BaseZombie3D)

@export var max_hp: float = 100.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.4
@export var attack_cooldown: float = 1.0
@export var knockback_resistance: float = 0.0 # 0.0 = full knockback, 1.0 = immune
@export var turn_speed: float = 10.0
@export var score_value: int = 100

var current_hp: float = 100.0
var is_dead: bool = false
var is_nav_ready: bool = false
var attack_timer: float = 0.0
var flash_timer: float = 0.0
var repath_timer: float = 0.0
var repath_interval: float = 0.28
var knockback_velocity: Vector3 = Vector3.ZERO
var death_timer: float = 0.0
var target_player: CharacterBody3D = null

# Node References
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals

var mesh_instances: Array[MeshInstance3D] = []
var hit_flash_material: ShaderMaterial = null

const HIT_FLASH_SHADER = preload("res://shaders/hit_flash_3d.gdshader")
const BLOOD_TEXTURES = [
	preload("res://assets/textures/decals/blood_splat_1.png"),
	preload("res://assets/textures/decals/blood_splat_2.png"),
	preload("res://assets/textures/decals/blood_splat_3.png")
]

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 7
	
	current_hp = max_hp
	setup_hit_flash()
	
	# Configure NavigationAgent3D
	if nav_agent:
		nav_agent.path_desired_distance = 0.6
		nav_agent.target_desired_distance = attack_range
		nav_agent.path_max_distance = 3.5
		nav_agent.avoidance_enabled = false
	
	# Safe deferred navigation setup to avoid map synchronization warnings
	call_deferred("_setup_navigation")

func setup_hit_flash() -> void:
	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = HIT_FLASH_SHADER
	hit_flash_material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	hit_flash_material.set_shader_parameter("flash_amount", 0.0)
	
	find_mesh_instances(self)
	for mesh in mesh_instances:
		# Apply next_pass hit flash overlay to materials
		if mesh.material_override:
			mesh.material_override.next_pass = hit_flash_material
		elif mesh.get_surface_override_material(0):
			mesh.get_surface_override_material(0).next_pass = hit_flash_material

func find_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_instances.append(node)
	for child in node.get_children():
		find_mesh_instances(child)

func _setup_navigation() -> void:
	# Await first physics frame for NavigationServer synchronization
	await get_tree().physics_frame
	find_player()
	is_nav_ready = true
	_update_nav_target()

func find_player() -> void:
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player3d") as CharacterBody3D
		if target_player == null:
			target_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func _update_nav_target() -> void:
	find_player()
	if target_player and is_instance_valid(target_player) and nav_agent:
		nav_agent.target_position = target_player.global_position

func _physics_process(delta: float) -> void:
	if is_dead:
		handle_death_process(delta)
		return
	
	# Handle hit flash decay
	if flash_timer > 0.0:
		flash_timer -= delta
		var flash_val = clampf(flash_timer / 0.12, 0.0, 1.0) * 0.95
		if hit_flash_material:
			hit_flash_material.set_shader_parameter("flash_amount", flash_val)
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if not is_nav_ready:
		return
	
	# Repath timer
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = repath_interval + randf_range(-0.05, 0.05)
		_update_nav_target()
	
	handle_movement_and_combat(delta)

func handle_movement_and_combat(delta: float) -> void:
	find_player()
	if target_player == null or not is_instance_valid(target_player):
		velocity = velocity.move_toward(Vector3.ZERO, delta * 15.0)
		move_and_slide()
		return
	
	var dist_to_player: float = global_position.distance_to(target_player.global_position)
	
	# Rotate towards player or movement direction
	var look_dir = (target_player.global_position - global_position)
	look_dir.y = 0.0
	
	if dist_to_player <= attack_range:
		# In melee range - stop and attack
		velocity.x = move_toward(velocity.x, 0.0, delta * 25.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 25.0)
		
		if look_dir.length_squared() > 0.01:
			var target_yaw = atan2(look_dir.x, look_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, delta * turn_speed)
		
		if attack_timer <= 0.0:
			perform_melee_attack()
			attack_timer = attack_cooldown
	else:
		# Follow NavigationAgent3D path
		if nav_agent and not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			var move_vec = (next_pos - global_position)
			move_vec.y = 0.0
			
			if move_vec.length_squared() > 0.001:
				var move_dir = move_vec.normalized()
				velocity.x = move_toward(velocity.x, move_dir.x * move_speed, delta * 28.0)
				velocity.z = move_toward(velocity.z, move_dir.z * move_speed, delta * 28.0)
				
				var target_yaw = atan2(move_dir.x, move_dir.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, delta * turn_speed)
		else:
			# Fallback straight chase if nav finished or path direct
			if look_dir.length_squared() > 0.01:
				var direct_dir = look_dir.normalized()
				velocity.x = move_toward(velocity.x, direct_dir.x * move_speed, delta * 28.0)
				velocity.z = move_toward(velocity.z, direct_dir.z * move_speed, delta * 28.0)
				var target_yaw = atan2(direct_dir.x, direct_dir.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, delta * turn_speed)
	
	# Apply directional knockback
	if knockback_velocity.length_squared() > 0.01:
		velocity.x += knockback_velocity.x
		velocity.z += knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 32.0)
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5
	
	move_and_slide()

func perform_melee_attack() -> void:
	if target_player and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position).normalized()
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage, dir)
		Global.play_sound("zombie_aggro", global_position)

func trigger_hit_flash() -> void:
	flash_timer = 0.12
	if hit_flash_material:
		hit_flash_material.set_shader_parameter("flash_amount", 0.95)

func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	
	current_hp -= amount
	trigger_hit_flash()
	Global.play_sound("zombie_hurt", global_position)
	
	# Apply knockback scaled by resistance
	if knockback_dir != Vector3.ZERO and knockback_resistance < 1.0:
		var kb_power = 7.5 * (1.0 - knockback_resistance)
		knockback_velocity = knockback_dir.normalized() * kb_power
	
	if current_hp <= 0.0:
		die(knockback_dir)

func die(death_dir: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	is_dead = true
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Register kill, score, and visceral death rattle audio
	var global_singleton = get_node_or_null("/root/Global")
	if global_singleton and global_singleton.has_method("add_kill"):
		global_singleton.add_kill(score_value)
	Global.play_sound("zombie_death", global_position)
	
	# Spawn floor blood decal
	spawn_blood_decal()
	
	# Directional collapse / ragdoll impulse
	velocity = death_dir.normalized() * 4.5 + Vector3(0, 1.2, 0)
	
	on_death(death_dir)
	emit_signal("enemy_died", self)

func on_death(_death_dir: Vector3) -> void:
	# Virtual method for subclasses to override
	pass

func spawn_blood_decal() -> void:
	var scene = get_tree().current_scene
	if not scene:
		scene = get_parent()
	if not scene:
		scene = get_tree().root
	if not scene:
		return
	
	var decal = Decal.new()
	var sz = randf_range(2.2, 3.4)
	decal.size = Vector3(sz, 1.2, sz)
	decal.texture_albedo = BLOOD_TEXTURES[randi() % BLOOD_TEXTURES.size()]
	decal.rotation.y = randf_range(0.0, TAU)
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 50.0
	decal.distance_fade_length = 20.0
	
	var decals_parent = scene.find_child("Decals", true, false)
	if decals_parent:
		decals_parent.add_child(decal)
	else:
		scene.add_child(decal)
	
	decal.global_position = global_position + Vector3(0, 0.15, 0)

func handle_death_process(delta: float) -> void:
	death_timer += delta
	
	# Rapid collapse animation: tilts backwards/sideways and settles on the ground
	if visuals:
		visuals.rotation.x = lerpf(visuals.rotation.x, deg_to_rad(-82.0), delta * 12.0)
		visuals.position.y = lerpf(visuals.position.y, -0.65, delta * 10.0)
	
	# Slide to a halt
	velocity = velocity.move_toward(Vector3.ZERO, delta * 8.0)
	move_and_slide()
	
	# Despawn corpse after 3.5 seconds with fade-down
	if death_timer > 3.0:
		if visuals:
			visuals.scale = visuals.scale.move_toward(Vector3.ZERO, delta * 2.0)
		if death_timer >= 3.8:
			queue_free()
