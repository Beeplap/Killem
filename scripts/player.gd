extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 2800.0
@export var friction: float = 3200.0

@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = get_node_or_null("Flashlight")
@onready var muzzle_flash: PointLight2D = get_node_or_null("MuzzleFlash")
@onready var weapon_mount: PlayerWeapons2D = get_node_or_null("WeaponMount")
@onready var placement_ghost: PlacementGhost = get_node_or_null("PlacementGhost")

var target_zoom: Vector2 = Vector2(1.15, 1.15)
var min_zoom: Vector2 = Vector2(0.65, 0.65)
var max_zoom: Vector2 = Vector2(1.85, 1.85)

var fire_cooldown: float = 0.0
var invulnerability_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

# Dodge Roll State
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var roll_cooldown_timer: float = 0.0
var ghost_trail_timer: float = 0.0
const ROLL_COOLDOWN: float = 1.5
const ROLL_DURATION: float = 0.25
const ROLL_SPEED_MULT: float = 2.5

# Minigun State
var minigun_spin_timer: float = 0.0
const MINIGUN_SPINUP_TIME: float = 0.40

# Deployables selection
var active_deployable_type: int = 0 # 0: Wire, 1: Claymore, 2: Turret

const CASING_POOL_SCRIPT = preload("res://scripts/casing_pool.gd")

# Screen shake & Trauma system
var trauma: float = 0.0
@export var trauma_decay: float = 1.5
@export var max_shake_offset: Vector2 = Vector2(28.0, 20.0)
@export var max_shake_roll: float = 0.055

# Dependencies
var bullet_pool: Node2D = null
var casing_pool: Node2D = null
var tactical_crosshair: Control = null

func _ready() -> void:
	add_to_group("player")
	Global.health_changed.emit(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	Global.deployables_updated.emit(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)
	Global.active_deployable_changed.connect(func(type: int):
		active_deployable_type = type
	)
	active_deployable_type = Global.active_deployable_type
	
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 14), Vector2(0.85, 0.42))
	
	if muzzle_flash:
		muzzle_flash.enabled = false
	
	call_deferred("_find_dependencies")

func _find_dependencies() -> void:
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	tactical_crosshair = get_tree().get_first_node_in_group("crosshair")
	
	casing_pool = get_tree().get_first_node_in_group("casing_pool")
	if casing_pool == null:
		var level = get_tree().current_scene
		if level:
			casing_pool = CASING_POOL_SCRIPT.new()
			casing_pool.name = "CasingPool"
			casing_pool.add_to_group("casing_pool")
			level.add_child(casing_pool)

func _unhandled_input(event: InputEvent) -> void:
	if Global.is_game_over:
		return
	
	# Camera zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = (target_zoom + Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = (target_zoom - Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
	
	# Weapon Switching [1, 2, 3, 4, 5]
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			Global.set_weapon(Global.WeaponType.PISTOL)
		elif event.keycode == KEY_2:
			Global.set_weapon(Global.WeaponType.SHOTGUN)
		elif event.keycode == KEY_3:
			Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)
		elif event.keycode == KEY_4:
			Global.set_weapon(Global.WeaponType.FLAMETHROWER)
		elif event.keycode == KEY_5:
			Global.set_weapon(Global.WeaponType.MINIGUN)
		elif event.keycode == KEY_R:
			PlayerShooting.play_reload_sequence(get_tree(), global_position)
		elif event.keycode == KEY_SPACE:
			start_dodge_roll()
		elif event.keycode == KEY_E:
			deploy_current_item()
		elif event.keycode == KEY_Q:
			cycle_deployable()

var footstep_distance_traveled: float = 0.0
const FOOTSTEP_STRIDE_LENGTH: float = 110.0

func cycle_deployable() -> void:
	Global.set_active_deployable(Global.active_deployable_type + 1)
	Global.play_sound("hit")

func start_dodge_roll() -> void:
	if is_rolling or roll_cooldown_timer > 0.0 or Global.is_game_over:
		return
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	
	if input_dir != Vector2.ZERO:
		roll_dir = input_dir.normalized()
	else:
		roll_dir = (get_global_mouse_position() - global_position).normalized()
	
	is_rolling = true
	roll_timer = ROLL_DURATION
	roll_cooldown_timer = ROLL_COOLDOWN
	invulnerability_timer = max(invulnerability_timer, ROLL_DURATION + 0.05) # Full i-frames during roll
	velocity = roll_dir * (move_speed * ROLL_SPEED_MULT)
	ghost_trail_timer = 0.0
	spawn_ghost_trail()
	Global.play_sound("roll")

func spawn_ghost_trail() -> void:
	if sprite == null:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.global_scale
	ghost.rotation = sprite.global_rotation
	ghost.modulate = Color(0.4, 0.75, 1.0, 0.55)
	ghost.z_index = z_index - 1
	var level = get_tree().current_scene
	if level:
		level.add_child(ghost)
		var tween = level.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
		tween.tween_callback(ghost.queue_free)

func deploy_current_item() -> void:
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - global_position
	var deploy_pos = global_position + to_mouse.limit_length(110.0)
	var level = get_tree().current_scene
	if not level:
		return
	
	# Auto switch to available item if current type has 0
	if active_deployable_type == 0 and Global.deployable_barbed_wire <= 0:
		if Global.deployable_claymores > 0: active_deployable_type = 1
		elif Global.deployable_turrets > 0: active_deployable_type = 2
	elif active_deployable_type == 1 and Global.deployable_claymores <= 0:
		if Global.deployable_turrets > 0: active_deployable_type = 2
		elif Global.deployable_barbed_wire > 0: active_deployable_type = 0
	elif active_deployable_type == 2 and Global.deployable_turrets <= 0:
		if Global.deployable_barbed_wire > 0: active_deployable_type = 0
		elif Global.deployable_claymores > 0: active_deployable_type = 1
	
	match active_deployable_type:
		0:
			if Global.deployable_barbed_wire > 0:
				Global.deployable_barbed_wire -= 1
				var wire = preload("res://scenes/deployables/BarbedWire.tscn").instantiate()
				wire.global_position = deploy_pos
				wire.rotation = to_mouse.angle()
				level.add_child(wire)
				Global.play_sound("hit")
				Global.deployables_updated.emit(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)
		1:
			if Global.deployable_claymores > 0:
				Global.deployable_claymores -= 1
				var mine = preload("res://scenes/deployables/ClaymoreMine.tscn").instantiate()
				mine.global_position = deploy_pos
				mine.set_facing(to_mouse.normalized())
				level.add_child(mine)
				Global.play_sound("hit")
				Global.deployables_updated.emit(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)
		2:
			if Global.deployable_turrets > 0:
				Global.deployable_turrets -= 1
				var turret = preload("res://scenes/deployables/SentryTurret.tscn").instantiate()
				turret.global_position = deploy_pos
				level.add_child(turret)
				Global.play_sound("hit")
				Global.deployables_updated.emit(Global.deployable_barbed_wire, Global.deployable_claymores, Global.deployable_turrets)

func _physics_process(delta: float) -> void:
	if Global.is_game_over:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	# Roll cooldown timer
	if roll_cooldown_timer > 0.0:
		roll_cooldown_timer -= delta
		Global.roll_cooldown_updated.emit(max(0.0, ROLL_COOLDOWN - roll_cooldown_timer), ROLL_COOLDOWN)
	
	# Active Dodge Roll burst
	if is_rolling:
		roll_timer -= delta
		ghost_trail_timer -= delta
		if ghost_trail_timer <= 0.0:
			ghost_trail_timer = 0.045
			spawn_ghost_trail()
		
		velocity = roll_dir * (move_speed * ROLL_SPEED_MULT)
		move_and_slide()
		
		if roll_timer <= 0.0:
			is_rolling = false
		
		handle_camera_and_shake(delta)
		return
	
	handle_movement(delta)
	handle_aiming()
	handle_shooting(delta)
	handle_camera_and_shake(delta)
	
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.enabled = false

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
		input_dir = input_dir.normalized()
	
	var effective_speed = move_speed
	# -20% movement penalty while spooling or firing rotary minigun
	if Global.current_weapon == Global.WeaponType.MINIGUN and minigun_spin_timer > 0.05:
		effective_speed *= 0.80
	
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * effective_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	
	if velocity.length_squared() > 100.0:
		footstep_distance_traveled += velocity.length() * delta
		if footstep_distance_traveled >= FOOTSTEP_STRIDE_LENGTH:
			footstep_distance_traveled = 0.0
			_play_surface_footstep()

func _play_surface_footstep() -> void:
	var surface = "gravel"
	if global_position.y > 60.0 and global_position.y < 380.0:
		surface = "asphalt"
	elif global_position.x < -400.0:
		surface = "metal"
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_footstep"):
		audio_mgr.play_footstep(surface, global_position)

func _get_active_deployable_stock() -> int:
	match active_deployable_type:
		0: return Global.deployable_barbed_wire
		1: return Global.deployable_claymores
		2: return Global.deployable_turrets
	return 0

func handle_aiming() -> void:
	var mouse_pos = get_global_mouse_position()
	var aim_dir = (mouse_pos - global_position).normalized()
	var angle = aim_dir.angle()
	
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	dir_idx = dir_idx % 8
	
	if sprite:
		sprite.frame = dir_idx
	
	if weapon_mount:
		weapon_mount.position = Vector2(0, -4)
		weapon_mount.rotation = angle
		if aim_dir.x < 0.0:
			weapon_mount.scale.y = -1.0
		else:
			weapon_mount.scale.y = 1.0
	
	if flashlight:
		flashlight.rotation = angle
		flashlight.position = aim_dir * 16.0 + Vector2(0, -4)
	
	if muzzle:
		var custom_muzzle = weapon_mount.get_muzzle_marker() if weapon_mount else null
		if custom_muzzle:
			muzzle.global_position = custom_muzzle.global_position
		else:
			muzzle.position = aim_dir * 26.0 + Vector2(0, -4)
		muzzle.rotation = angle
	
	if muzzle_flash:
		muzzle_flash.position = muzzle.position if muzzle else aim_dir * 26.0
	
	if placement_ghost:
		placement_ghost.update_ghost(global_position, mouse_pos, active_deployable_type, _get_active_deployable_stock())

func handle_shooting(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	var is_pressing_fire: bool = Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Rotary Minigun Spool-up handling
	if Global.current_weapon == Global.WeaponType.MINIGUN:
		if is_pressing_fire:
			minigun_spin_timer += delta
			if weapon_mount:
				weapon_mount.update_minigun_spin(delta, true, minigun_spin_timer / MINIGUN_SPINUP_TIME)
			if minigun_spin_timer < MINIGUN_SPINUP_TIME and fmod(minigun_spin_timer, 0.20) < delta:
				Global.play_sound("minigun_spin")
		else:
			minigun_spin_timer = max(0.0, minigun_spin_timer - delta * 2.5)
			if weapon_mount:
				weapon_mount.update_minigun_spin(delta, minigun_spin_timer > 0.05, minigun_spin_timer / MINIGUN_SPINUP_TIME)
	
	var wants_to_shoot: bool = false
	if Global.current_weapon == Global.WeaponType.ASSAULT_RIFLE or Global.current_weapon == Global.WeaponType.FLAMETHROWER:
		wants_to_shoot = is_pressing_fire
	elif Global.current_weapon == Global.WeaponType.MINIGUN:
		wants_to_shoot = is_pressing_fire and minigun_spin_timer >= MINIGUN_SPINUP_TIME
	else:
		# Pistol / Shotgun
		if Global.perk_full_auto and Global.current_weapon == Global.WeaponType.PISTOL:
			wants_to_shoot = is_pressing_fire
		else:
			wants_to_shoot = Input.is_action_just_pressed("shoot") or (is_pressing_fire and fire_cooldown <= 0.0)
	
	if wants_to_shoot and fire_cooldown <= 0.0:
		if not Global.has_ammo(Global.current_weapon):
			PlayerShooting.play_empty_click(global_position)
			fire_cooldown = 0.25
			return
		
		fire_weapon()

func fire_weapon() -> void:
	if bullet_pool == null:
		_find_dependencies()
	
	var base_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	var custom_muzzle = weapon_mount.get_muzzle_marker() if weapon_mount else null
	var spawn_pos: Vector2 = custom_muzzle.global_position if custom_muzzle else global_position + base_dir * 32.0 + Vector2(0, -4)
	
	# Apply visual procedural recoil kick
	if weapon_mount:
		var kick_amount = 3.5
		match Global.current_weapon:
			Global.WeaponType.PISTOL: kick_amount = 3.0
			Global.WeaponType.SHOTGUN: kick_amount = 6.0
			Global.WeaponType.ASSAULT_RIFLE: kick_amount = 3.2
			Global.WeaponType.FLAMETHROWER: kick_amount = 1.5
			Global.WeaponType.MINIGUN: kick_amount = 2.0
		weapon_mount.apply_recoil_kick(kick_amount)
	
	# Eject brass casing (except flamethrower)
	if Global.current_weapon != Global.WeaponType.FLAMETHROWER and casing_pool:
		var custom_eject = weapon_mount.get_ejection_marker() if weapon_mount else null
		var eject_pos = custom_eject.global_position if custom_eject else global_position + base_dir * 14.0 + Vector2(0, -2)
		casing_pool.spawn_casing(eject_pos, base_dir)
	
	if muzzle_flash and Global.current_weapon != Global.WeaponType.FLAMETHROWER:
		muzzle_flash.enabled = true
		muzzle_flash_timer = 0.04
	
	Global.player_fired.emit()
	
	var laser = muzzle.get_node_or_null("LaserSight") if muzzle else null
	if laser and laser.has_method("add_recoil_scatter"):
		laser.add_recoil_scatter(0.04)
	
	match Global.current_weapon:
		Global.WeaponType.PISTOL:
			Global.consume_ammo(Global.WeaponType.PISTOL)
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, base_dir, 38.0, 950.0, 1.8)
			fire_cooldown = 0.12 if Global.perk_full_auto else 0.20
			add_trauma(0.14)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(6.5)
			PlayerShooting.play_weapon_fire_audio("pistol", global_position)
		
		Global.WeaponType.SHOTGUN:
			Global.consume_ammo(Global.WeaponType.SHOTGUN)
			var pellet_count: int = 6
			var spread_angle: float = 0.28
			for i in range(pellet_count):
				var angle_offset: float = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
				var pellet_dir: Vector2 = base_dir.rotated(angle_offset)
				if bullet_pool:
					bullet_pool.spawn_bullet(spawn_pos, pellet_dir, 24.0, 800.0, 0.75)
			fire_cooldown = 0.70
			add_trauma(0.44)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(19.0)
			PlayerShooting.play_weapon_fire_audio("shotgun", global_position)
		
		Global.WeaponType.ASSAULT_RIFLE:
			Global.consume_ammo(Global.WeaponType.ASSAULT_RIFLE)
			var spread: float = randf_range(-0.06, 0.06)
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, base_dir.rotated(spread), 32.0, 1050.0, 1.8)
			fire_cooldown = 0.095
			# Screen shake removed completely for Assault Rifle / AK
			if tactical_crosshair:
				tactical_crosshair.add_bloom(9.5)
			PlayerShooting.play_weapon_fire_audio("rifle", global_position)
		
		Global.WeaponType.FLAMETHROWER:
			Global.consume_ammo(Global.WeaponType.FLAMETHROWER)
			process_flame_cone(base_dir, spawn_pos)
			fire_cooldown = 0.08
			add_trauma(0.06)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(12.0)
			PlayerShooting.play_weapon_fire_audio("flame", global_position)
		
		Global.WeaponType.MINIGUN:
			Global.consume_ammo(Global.WeaponType.MINIGUN)
			var spread: float = randf_range(-0.11, 0.11)
			if bullet_pool:
				bullet_pool.spawn_bullet(spawn_pos, base_dir.rotated(spread), 28.0, 1150.0, 1.6)
			fire_cooldown = 0.05 # 20 rounds / sec
			add_trauma(0.12)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(14.0)
			PlayerShooting.play_weapon_fire_audio("minigun_fire", global_position)

func process_flame_cone(base_dir: Vector2, spawn_pos: Vector2) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	# High pressure flame stream particles
	var flame = CPUParticles2D.new()
	flame.emitting = true
	flame.one_shot = true
	flame.explosiveness = 0.5
	flame.amount = 18
	flame.lifetime = 0.32
	flame.direction = base_dir
	flame.spread = 24.0
	flame.initial_velocity_min = 400.0
	flame.initial_velocity_max = 680.0
	flame.scale_amount_min = 5.0
	flame.scale_amount_max = 16.0
	flame.color = Color(1.0, 0.65, 0.15, 0.9)
	flame.global_position = spawn_pos
	flame.finished.connect(flame.queue_free)
	level.add_child(flame)
	
	var flame_range = 250.0
	var flame_cos = cos(deg_to_rad(28.0))
	
	# Damage & ignite enemies in cone
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var diff = enemy.global_position - spawn_pos
			var dist = diff.length()
			if dist <= flame_range:
				var dir = diff.normalized()
				if base_dir.dot(dir) >= flame_cos:
					if enemy.has_method("take_damage"):
						enemy.take_damage(16.0, dir)
					if enemy.has_method("ignite"):
						enemy.ignite(4.0, 32.0)
	
	# Ignite / damage destructibles
	var props = get_tree().get_nodes_in_group("destructibles")
	for prop in props:
		if is_instance_valid(prop) and not ("is_broken" in prop and prop.is_broken) and not ("is_burned_out" in prop and prop.is_burned_out):
			var diff = prop.global_position - spawn_pos
			if diff.length() <= flame_range:
				if base_dir.dot(diff.normalized()) >= flame_cos:
					prop.take_damage(26.0, base_dir)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	Global.camera_trauma_requested.emit(amount)

func trigger_shake(intensity: float, _duration: float = 0.1) -> void:
	add_trauma(clampf(intensity * 0.06, 0.1, 0.85))

func handle_camera_and_shake(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * 8.0)
		
		if trauma > 0.0:
			trauma = max(0.0, trauma - trauma_decay * delta)
			var shake = trauma * trauma
			camera.offset = Vector2(
				randf_range(-1.0, 1.0) * max_shake_offset.x * shake,
				randf_range(-1.0, 1.0) * max_shake_offset.y * shake
			)
			camera.rotation = randf_range(-1.0, 1.0) * max_shake_roll * shake
		else:
			camera.offset = Vector2.ZERO
			camera.rotation = 0.0

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or Global.is_game_over:
		return
	
	Global.take_player_damage(amount)
	invulnerability_timer = 0.40
	if sprite:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	add_trauma(0.55)
	Global.play_sound("hit")
	
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir.normalized() * 320.0
