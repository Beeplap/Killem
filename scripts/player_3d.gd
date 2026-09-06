extends CharacterBody3D
class_name Player3D

enum WeaponType3D { PISTOL, SHOTGUN, ASSAULT_RIFLE, FLAMETHROWER, MINIGUN }

@export var move_speed: float = 6.0
@export var acceleration: float = 85.0
@export var friction: float = 90.0
@export var step_height: float = 0.35

# Dodge Dash System
@export var dash_speed: float = 16.5
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.75
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_invulnerable: bool = false

# Aiming & Raycast
var aim_hit_point: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD

# Weapon System
var current_weapon: WeaponType3D = WeaponType3D.PISTOL
var fire_cooldown: float = 0.0
var muzzle_flash_timer: float = 0.0
var recoil_kick: float = 0.0
var minigun_spin_speed: float = 0.0
var minigun_is_spinning: bool = false

# Camera & Trauma Shake
var trauma: float = 0.0
@export var trauma_decay: float = 1.5
@export var max_shake_offset: Vector3 = Vector3(0.35, 0.25, 0.35)
@export var max_shake_pitch: float = 0.04
@export var max_shake_yaw: float = 0.04

# Node References
@onready var camera_mount: Node3D = get_node_or_null("CameraMount")
@onready var camera: Camera3D = get_node_or_null("CameraMount/Camera3D")
@onready var torso_pivot: Node3D = get_node_or_null("BodyMesh/TorsoPivot")
@onready var head_pivot: Node3D = get_node_or_null("BodyMesh/TorsoPivot/HeadPivot")
@onready var right_hand_socket: Node3D = get_node_or_null("BodyMesh/TorsoPivot/RightArm/RightHandSocket")
@onready var right_hand_attachment: Node3D = right_hand_socket if right_hand_socket else get_node_or_null("BodyMesh/TorsoPivot/RightArm/RightHandAttachment")
@onready var flashlight: SpotLight3D = get_node_or_null("BodyMesh/TorsoPivot/Flashlight")
@onready var step_ray_low: RayCast3D = get_node_or_null("StepRayLow")
@onready var step_ray_high: RayCast3D = get_node_or_null("StepRayHigh")

# Weapons Nodes
@onready var weapon_pistol: Node3D = _find_weapon_node("Pistol3D")
@onready var weapon_shotgun: Node3D = _find_weapon_node("Shotgun3D")
@onready var weapon_ak: Node3D = _find_weapon_node("AK3D")
@onready var weapon_rifle: Node3D = weapon_ak if weapon_ak else _find_weapon_node("Rifle3D")
@onready var weapon_flame: Node3D = _find_weapon_node("Flamethrower3D")
@onready var weapon_minigun: Node3D = _find_weapon_node("Minigun3D")

var default_hand_pos: Vector3 = Vector3.ZERO
var default_hand_rot: Vector3 = Vector3.ZERO
var current_recoil_offset_z: float = 0.0
var current_recoil_pitch_x: float = 0.0
var _equip_tween: Tween
var _footstep_dist: float = 0.0
const PROJECTILE_SCENE = preload("res://scenes/entities/Projectile3D.tscn")

func _find_weapon_node(w_name: String) -> Node3D:
	if right_hand_socket:
		var n = right_hand_socket.get_node_or_null(w_name)
		if n: return n
	if right_hand_attachment:
		var n = right_hand_attachment.get_node_or_null(w_name)
		if n: return n
	return null

func _ready() -> void:
	add_to_group("player")
	add_to_group("player3d")
	floor_constant_speed = true
	floor_snap_length = step_height
	floor_max_angle = deg_to_rad(45.0)
	
	var hand_node = right_hand_socket if right_hand_socket else right_hand_attachment
	if hand_node:
		default_hand_pos = hand_node.position
		default_hand_rot = hand_node.rotation
	
	switch_weapon(WeaponType3D.PISTOL)

func _unhandled_input(event: InputEvent) -> void:
	if Global.is_game_over:
		return
	
	# Weapon Switching [1, 2, 3, 4, 5]
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: switch_weapon(WeaponType3D.PISTOL)
		elif event.keycode == KEY_2: switch_weapon(WeaponType3D.SHOTGUN)
		elif event.keycode == KEY_3: switch_weapon(WeaponType3D.ASSAULT_RIFLE)
		elif event.keycode == KEY_4: switch_weapon(WeaponType3D.FLAMETHROWER)
		elif event.keycode == KEY_5: switch_weapon(WeaponType3D.MINIGUN)
		elif event.keycode == KEY_R:
			PlayerShooting.play_reload_sequence(get_tree(), global_position)
	
	# Combat Dodge Dash (Space)
	if event.is_action_pressed("dodge_roll") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if not is_dashing and dash_cooldown_timer <= 0.0:
			trigger_dodge_dash()

func _physics_process(delta: float) -> void:
	if Global.is_game_over:
		velocity = velocity.move_toward(Vector3.ZERO, friction * delta)
		move_and_slide()
		return
	
	handle_dash(delta)
	handle_movement(delta)
	update_raycast_aiming(delta)
	handle_shooting(delta)
	update_weapon_recoil(delta)
	handle_camera_and_shake(delta)

func handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false
			dash_cooldown_timer = dash_cooldown

func trigger_dodge_dash() -> void:
	var input_vec = get_movement_input()
	if input_vec.length_squared() > 0.01:
		dash_direction = input_vec.normalized()
	else:
		dash_direction = aim_direction
	
	is_dashing = true
	is_invulnerable = true
	dash_timer = dash_duration
	add_trauma(0.18)
	Global.play_sound("hit")

func get_movement_input() -> Vector3:
	var move_vec: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A): move_vec.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D): move_vec.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W): move_vec.z -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S): move_vec.z += 1.0
	return move_vec.normalized()

func handle_movement(delta: float) -> void:
	if is_dashing:
		move_and_slide()
		return
	
	var input_vec: Vector3 = get_movement_input()
	var target_vel: Vector3 = input_vec * move_speed
	
	if input_vec != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
		
		# Align step-up raycasts along movement heading
		if step_ray_low and step_ray_high:
			step_ray_low.target_position = input_vec * 0.5
			step_ray_high.target_position = input_vec * 0.5
			
			# Step-up stair handling: if low obstacle hit but high is clear, step up smoothly
			if step_ray_low.is_colliding() and not step_ray_high.is_colliding():
				var col_normal = step_ray_low.get_collision_normal()
				if col_normal.y < 0.2: # vertical wall/step face
					velocity.y = 3.5
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	
	# Gravity on ground
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	
	move_and_slide()
	
	if is_on_floor() and Vector2(velocity.x, velocity.z).length_squared() > 0.5:
		_footstep_dist += Vector2(velocity.x, velocity.z).length() * delta
		if _footstep_dist >= 2.4:
			_footstep_dist = 0.0
			_play_surface_footstep_3d()

func _play_surface_footstep_3d() -> void:
	var surface = "concrete"
	if abs(global_position.z) > 12.0 or abs(global_position.x) > 14.0:
		surface = "gravel"
	elif global_position.x > 8.0 and global_position.z < -4.0:
		surface = "metal"
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_footstep"):
		audio_mgr.play_footstep(surface, global_position)

func update_raycast_aiming(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = cam.project_ray_normal(mouse_pos)
	
	# Ground plane raycasting on horizontal XZ plane at player elevation
	var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
	var hit_pos = ground_plane.intersects_ray(ray_origin, ray_normal)
	
	if hit_pos != null:
		aim_hit_point = hit_pos
		var aim_vec: Vector3 = aim_hit_point - global_position
		aim_vec.y = 0.0
		
		if aim_vec.length_squared() > 0.001:
			aim_direction = aim_vec.normalized()
			
			if torso_pivot:
				# Smooth 360-degree rotation of upper torso and weapon hierarchy
				var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
				torso_pivot.rotation.y = lerp_angle(torso_pivot.rotation.y, target_yaw, delta * 26.0)
				
				# Subtle distance elevation pitch
				var dist: float = aim_vec.length()
				var target_pitch: float = clampf((dist - 9.0) * -0.012, -0.14, 0.14)
				torso_pivot.rotation.x = lerp_angle(torso_pivot.rotation.x, target_pitch, delta * 14.0)

func handle_shooting(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			set_active_muzzle_flash(false)
	
	var wants_to_shoot: bool = Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Minigun spin-up logic
	if current_weapon == WeaponType3D.MINIGUN:
		if wants_to_shoot:
			minigun_spin_speed = minf(minigun_spin_speed + delta * 25.0, 48.0)
		else:
			minigun_spin_speed = maxf(minigun_spin_speed - delta * 18.0, 0.0)
		
		# Spin minigun barrels
		if weapon_minigun:
			weapon_minigun.rotation.z += minigun_spin_speed * delta
	
	# Flamethrower pilot flame flicker
	if current_weapon == WeaponType3D.FLAMETHROWER and weapon_flame:
		var pilot: OmniLight3D = weapon_flame.get_node_or_null("PilotLight")
		if pilot:
			pilot.light_energy = 0.8 + sin(Time.get_ticks_msec() * 0.02) * 0.22
	
	var can_fire: bool = false
	if current_weapon == WeaponType3D.MINIGUN:
		can_fire = (wants_to_shoot and minigun_spin_speed >= 30.0 and fire_cooldown <= 0.0)
	elif current_weapon in [WeaponType3D.ASSAULT_RIFLE, WeaponType3D.FLAMETHROWER]:
		can_fire = (wants_to_shoot and fire_cooldown <= 0.0)
	else:
		can_fire = (Input.is_action_just_pressed("shoot") or (wants_to_shoot and fire_cooldown <= 0.0))
	
	if can_fire:
		fire_current_weapon()

func get_active_muzzle_socket() -> Node3D:
	var active_w = get_active_weapon_node()
	if not active_w:
		return null
	var muzzle = active_w.get_node_or_null("Muzzle")
	if muzzle:
		return muzzle
	var legacy_marker = active_w.get_node_or_null("MuzzleMarker")
	if legacy_marker:
		return legacy_marker
	return null

func get_active_muzzle_position() -> Vector3:
	var active_w = get_active_weapon_node()
	if not active_w:
		return global_position + aim_direction * 0.8 + Vector3(0, 1.1, 0)
	if active_w.has_method("get_muzzle_position"):
		return active_w.get_muzzle_position()
	var muzzle = get_active_muzzle_socket()
	if muzzle:
		return muzzle.global_position
	return global_position + aim_direction * 0.8 + Vector3(0, 1.1, 0)

func apply_hand_recoil(kick_z: float, pitch_x: float) -> void:
	current_recoil_offset_z += kick_z
	current_recoil_pitch_x += pitch_x
	current_recoil_offset_z = clampf(current_recoil_offset_z, -0.16, 0.0)
	current_recoil_pitch_x = clampf(current_recoil_pitch_x, -0.28, 0.0)

func fire_current_weapon() -> void:
	var active_w = get_active_weapon_node()
	if active_w == null:
		return
	
	var spawn_pos: Vector3 = get_active_muzzle_position()
	
	# Flash light for 0.05s
	set_active_muzzle_flash(true)
	muzzle_flash_timer = 0.05
	
	# Trigger procedural moving parts on weapon model (slide blowback, pump cycle, bolt cycle)
	if active_w.has_method("fire"):
		active_w.fire()
	
	match current_weapon:
		WeaponType3D.PISTOL:
			spawn_projectile(spawn_pos, aim_direction, 38.0, 48.0, 1.8, 0)
			fire_cooldown = 0.22
			recoil_kick = 0.055
			apply_hand_recoil(-0.045, -0.09)
			add_trauma(0.12)
			PlayerShooting.play_weapon_fire_audio("pistol", spawn_pos)
		
		WeaponType3D.SHOTGUN:
			# 7 Conical spread pellets
			for _i in range(7):
				var spread_yaw: float = randf_range(-0.16, 0.16)
				var spread_pitch: float = randf_range(-0.06, 0.06)
				var pellet_dir: Vector3 = aim_direction.rotated(Vector3.UP, spread_yaw)
				pellet_dir = pellet_dir.rotated(Vector3.RIGHT, spread_pitch).normalized()
				spawn_projectile(spawn_pos, pellet_dir, 22.0, 40.0, 0.85, 1)
			fire_cooldown = 0.72
			recoil_kick = 0.13
			apply_hand_recoil(-0.095, -0.16)
			add_trauma(0.42)
			PlayerShooting.play_weapon_fire_audio("shotgun", spawn_pos)
		
		WeaponType3D.ASSAULT_RIFLE:
			var spread_yaw: float = randf_range(-0.035, 0.035)
			var spread_dir: Vector3 = aim_direction.rotated(Vector3.UP, spread_yaw)
			spawn_projectile(spawn_pos, spread_dir, 32.0, 56.0, 1.8, 0)
			fire_cooldown = 0.092
			recoil_kick = 0.045
			apply_hand_recoil(-0.038, -0.065)
			# Screen shake removed completely for Assault Rifle / AK
			PlayerShooting.play_weapon_fire_audio("rifle", spawn_pos)
		
		WeaponType3D.FLAMETHROWER:
			# Expanding flame stream
			var flame_yaw: float = randf_range(-0.12, 0.12)
			var flame_dir: Vector3 = aim_direction.rotated(Vector3.UP, flame_yaw)
			spawn_projectile(spawn_pos, flame_dir, 18.0, 22.0, 0.75, 2)
			fire_cooldown = 0.055
			recoil_kick = 0.02
			apply_hand_recoil(-0.015, -0.02)
			add_trauma(0.08)
			PlayerShooting.play_weapon_fire_audio("flame", spawn_pos)
		
		WeaponType3D.MINIGUN:
			var minigun_yaw: float = randf_range(-0.045, 0.045)
			var minigun_dir: Vector3 = aim_direction.rotated(Vector3.UP, minigun_yaw)
			spawn_projectile(spawn_pos, minigun_dir, 28.0, 62.0, 1.8, 3)
			fire_cooldown = 0.052
			recoil_kick = 0.038
			apply_hand_recoil(-0.028, -0.04)
			add_trauma(0.19)
			PlayerShooting.play_weapon_fire_audio("minigun_fire", spawn_pos)

func spawn_projectile(pos: Vector3, dir: Vector3, dmg: float, spd: float, life: float, type_idx: int) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	var proj = PROJECTILE_SCENE.instantiate()
	level.add_child(proj)
	proj.setup(pos, dir, dmg, spd, life, type_idx)

func set_active_muzzle_flash(enabled: bool) -> void:
	var active_w = get_active_weapon_node()
	if active_w:
		var flash: OmniLight3D = active_w.get_node_or_null("Muzzle/MuzzleFlash")
		if not flash:
			flash = active_w.get_node_or_null("MuzzleFlash")
		if flash:
			flash.visible = enabled

func update_weapon_recoil(delta: float) -> void:
	var hand_node = right_hand_socket if right_hand_socket else right_hand_attachment
	if not hand_node:
		return
	
	# Smooth damp / lerp calculation back to rest position
	current_recoil_offset_z = lerpf(current_recoil_offset_z, 0.0, delta * 16.0)
	current_recoil_pitch_x = lerpf(current_recoil_pitch_x, 0.0, delta * 18.0)
	recoil_kick = move_toward(recoil_kick, 0.0, delta * 1.8)
	
	if _equip_tween and _equip_tween.is_valid():
		return
	
	hand_node.position = default_hand_pos + Vector3(0, 0, current_recoil_offset_z)
	hand_node.rotation.x = default_hand_rot.x + current_recoil_pitch_x

func switch_weapon(weapon_type: WeaponType3D) -> void:
	current_weapon = weapon_type
	if weapon_pistol: weapon_pistol.visible = (weapon_type == WeaponType3D.PISTOL)
	if weapon_shotgun: weapon_shotgun.visible = (weapon_type == WeaponType3D.SHOTGUN)
	if weapon_ak: weapon_ak.visible = (weapon_type == WeaponType3D.ASSAULT_RIFLE)
	elif weapon_rifle: weapon_rifle.visible = (weapon_type == WeaponType3D.ASSAULT_RIFLE)
	if weapon_flame: weapon_flame.visible = (weapon_type == WeaponType3D.FLAMETHROWER)
	if weapon_minigun: weapon_minigun.visible = (weapon_type == WeaponType3D.MINIGUN)
	
	match weapon_type:
		WeaponType3D.PISTOL: Global.set_weapon(Global.WeaponType.PISTOL)
		WeaponType3D.SHOTGUN: Global.set_weapon(Global.WeaponType.SHOTGUN)
		WeaponType3D.ASSAULT_RIFLE: Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)
	
	# Equip transition: slight weapon draw dip and return via Tween
	var hand_node = right_hand_socket if right_hand_socket else right_hand_attachment
	if hand_node and is_inside_tree():
		if _equip_tween and _equip_tween.is_valid():
			_equip_tween.kill()
		_equip_tween = create_tween()
		var dip_pos = default_hand_pos + Vector3(0, -0.07, -0.04)
		_equip_tween.tween_property(hand_node, "position", dip_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_equip_tween.tween_property(hand_node, "position", default_hand_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func get_active_weapon_node() -> Node3D:
	match current_weapon:
		WeaponType3D.PISTOL: return weapon_pistol
		WeaponType3D.SHOTGUN: return weapon_shotgun
		WeaponType3D.ASSAULT_RIFLE: return weapon_ak if weapon_ak else weapon_rifle
		WeaponType3D.FLAMETHROWER: return weapon_flame
		WeaponType3D.MINIGUN: return weapon_minigun
	return weapon_pistol

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func handle_camera_and_shake(delta: float) -> void:
	if camera:
		if trauma > 0.0:
			trauma = max(0.0, trauma - trauma_decay * delta)
			var shake = trauma * trauma
			camera.h_offset = randf_range(-1.0, 1.0) * max_shake_offset.x * shake
			camera.v_offset = randf_range(-1.0, 1.0) * max_shake_offset.y * shake
			camera.rotation.x = deg_to_rad(-52.0) + (randf_range(-1.0, 1.0) * max_shake_pitch * shake)
			camera.rotation.y = randf_range(-1.0, 1.0) * max_shake_yaw * shake
		else:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			camera.rotation.x = deg_to_rad(-52.0)
			camera.rotation.y = 0.0

func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable or Global.is_game_over:
		return
	
	Global.take_player_damage(amount)
	add_trauma(0.55)
	Global.play_sound("hit")
	
	if knockback_dir != Vector3.ZERO:
		velocity += knockback_dir.normalized() * 5.0
