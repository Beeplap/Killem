extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 1400.0
@export var friction: float = 1200.0

@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = get_node_or_null("Flashlight")
@onready var muzzle_flash: PointLight2D = get_node_or_null("MuzzleFlash")

var target_zoom: Vector2 = Vector2(1.15, 1.15)
var min_zoom: Vector2 = Vector2(0.65, 0.65)
var max_zoom: Vector2 = Vector2(1.85, 1.85)

var fire_cooldown: float = 0.0
var invulnerability_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

const CASING_POOL_SCRIPT = preload("res://scripts/casing_pool.gd")

# Screen shake & Trauma system
var trauma: float = 0.0
@export var trauma_decay: float = 1.5 # Decays smoothly by delta * 1.5
@export var max_shake_offset: Vector2 = Vector2(28.0, 20.0)
@export var max_shake_roll: float = 0.055 # Radians

# Bullet pool & Casing pool references
var bullet_pool: Node2D = null
var casing_pool: Node2D = null
var tactical_crosshair: Control = null

func _ready() -> void:
	add_to_group("player")
	Global.health_changed.emit(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	
	# Attach bottom-offset black elliptical drop shadow quad (modulate.a = 0.45)
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
	
	# Mouse scroll wheel strictly mapped to Camera Zoom (does not switch weapons)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = (target_zoom + Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = (target_zoom - Vector2(0.12, 0.12)).clamp(min_zoom, max_zoom)
	
	# Weapon Switching strictly mapped to Number Keys [1, 2, 3]
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			Global.set_weapon(Global.WeaponType.PISTOL)
		elif event.keycode == KEY_2:
			Global.set_weapon(Global.WeaponType.SHOTGUN)
		elif event.keycode == KEY_3:
			Global.set_weapon(Global.WeaponType.ASSAULT_RIFLE)

func _physics_process(delta: float) -> void:
	if Global.is_game_over:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	handle_movement(delta)
	handle_aiming()
	handle_shooting(delta)
	handle_camera_and_shake(delta)
	
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			if sprite:
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
	
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()

func handle_aiming() -> void:
	var mouse_pos = get_global_mouse_position()
	var aim_dir = (mouse_pos - global_position).normalized()
	var angle = aim_dir.angle()
	
	# 8-Directional 2.5D Isometric frame mapping
	# Angles: 0 = East, PI/4 = SE, PI/2 = South, 3PI/4 = SW, PI = West, -3PI/4 = NW, -PI/2 = North, -PI/4 = NE
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	dir_idx = dir_idx % 8
	
	if sprite:
		sprite.frame = dir_idx
	
	# Position flashlight and muzzle based on aim vector
	if flashlight:
		flashlight.rotation = angle
		flashlight.position = aim_dir * 16.0 + Vector2(0, -4)
	
	if muzzle:
		muzzle.position = aim_dir * 26.0 + Vector2(0, -4)
	
	if muzzle_flash:
		muzzle_flash.position = muzzle.position if muzzle else aim_dir * 26.0

func handle_shooting(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	var wants_to_shoot: bool = false
	if Global.current_weapon == Global.WeaponType.ASSAULT_RIFLE:
		wants_to_shoot = Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	else:
		wants_to_shoot = Input.is_action_just_pressed("shoot") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0)
	
	if wants_to_shoot and fire_cooldown <= 0.0:
		if not Global.has_ammo(Global.current_weapon):
			Global.play_sound("hit")
			fire_cooldown = 0.25
			return
		
		fire_weapon()

func fire_weapon() -> void:
	if bullet_pool == null:
		_find_dependencies()
		if bullet_pool == null:
			return
	
	var base_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	# Guaranteed safe spawn offset in front of the player's capsule
	var spawn_pos: Vector2 = global_position + base_dir * 32.0 + Vector2(0, -4)
	
	# Spawn physical ejected brass shell casing
	if casing_pool:
		casing_pool.spawn_casing(global_position + base_dir * 14.0 + Vector2(0, -2), base_dir)
	
	# Trigger Muzzle Flash Light
	if muzzle_flash:
		muzzle_flash.enabled = true
		muzzle_flash_timer = 0.04
	
	match Global.current_weapon:
		Global.WeaponType.PISTOL:
			Global.consume_ammo(Global.WeaponType.PISTOL)
			bullet_pool.spawn_bullet(spawn_pos, base_dir, 38.0, 950.0, 1.8)
			fire_cooldown = 0.20
			add_trauma(0.14)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(6.5)
			Global.play_sound("pistol")
		
		Global.WeaponType.SHOTGUN:
			Global.consume_ammo(Global.WeaponType.SHOTGUN)
			var pellet_count: int = 6
			var spread_angle: float = 0.28
			for i in range(pellet_count):
				var angle_offset: float = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
				var pellet_dir: Vector2 = base_dir.rotated(angle_offset)
				bullet_pool.spawn_bullet(spawn_pos, pellet_dir, 24.0, 800.0, 0.75)
			fire_cooldown = 0.70
			add_trauma(0.44) # Heavy weapon punch
			if tactical_crosshair:
				tactical_crosshair.add_bloom(19.0)
			Global.play_sound("shotgun")
		
		Global.WeaponType.ASSAULT_RIFLE:
			Global.consume_ammo(Global.WeaponType.ASSAULT_RIFLE)
			var spread: float = randf_range(-0.06, 0.06)
			bullet_pool.spawn_bullet(spawn_pos, base_dir.rotated(spread), 32.0, 1050.0, 1.8)
			fire_cooldown = 0.095
			add_trauma(0.18)
			if tactical_crosshair:
				tactical_crosshair.add_bloom(9.5)
			Global.play_sound("rifle")

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func trigger_shake(intensity: float, _duration: float = 0.1) -> void:
	add_trauma(clampf(intensity * 0.06, 0.1, 0.85))

func handle_camera_and_shake(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * 8.0)
		
		# Trauma decay shake (decays smoothly by delta * 1.5)
		if trauma > 0.0:
			trauma = max(0.0, trauma - trauma_decay * delta)
			var shake = trauma * trauma # Quadratic curve for punchy trauma
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
	invulnerability_timer = 0.4
	if sprite:
		sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	add_trauma(0.55)
	Global.play_sound("hit")
	
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir.normalized() * 320.0
