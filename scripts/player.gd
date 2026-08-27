extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 1400.0
@export var friction: float = 1200.0

@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle
@onready var flashlight: PointLight2D = get_node_or_null("Flashlight")

var target_zoom: Vector2 = Vector2(1.15, 1.15)
var min_zoom: Vector2 = Vector2(0.65, 0.65)
var max_zoom: Vector2 = Vector2(1.85, 1.85)

var fire_cooldown: float = 0.0
var invulnerability_timer: float = 0.0
var is_flashing: bool = false

# Screen shake
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

# Bullet pool reference
var bullet_pool: Node2D = null

func _ready() -> void:
	add_to_group("player")
	Global.health_changed.emit(Global.player_health, Global.player_max_health)
	Global.emit_current_ammo()
	
	# Find or wait for bullet pool
	call_deferred("_find_bullet_pool")

func _find_bullet_pool() -> void:
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool")

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
			is_flashing = false
			queue_redraw()

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Robust keyboard fallback if action mappings aren't triggered
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
	look_at(mouse_pos)

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
			# Dry fire sound
			Global.play_sound("hit")
			fire_cooldown = 0.25
			return
		
		fire_weapon()

func fire_weapon() -> void:
	if bullet_pool == null:
		_find_bullet_pool()
		if bullet_pool == null:
			return
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle else global_position
	var base_dir: Vector2 = (get_global_mouse_position() - spawn_pos).normalized()
	
	match Global.current_weapon:
		Global.WeaponType.PISTOL:
			Global.consume_ammo(Global.WeaponType.PISTOL)
			bullet_pool.spawn_bullet(spawn_pos, base_dir, 38.0, 950.0, 1.8)
			fire_cooldown = 0.20
			trigger_shake(2.5, 0.08)
			Global.play_sound("pistol")
		
		Global.WeaponType.SHOTGUN:
			Global.consume_ammo(Global.WeaponType.SHOTGUN)
			var pellet_count: int = 6
			var spread_angle: float = 0.28 # ~16 degrees
			for i in range(pellet_count):
				var angle_offset: float = randf_range(-spread_angle * 0.5, spread_angle * 0.5)
				var pellet_dir: Vector2 = base_dir.rotated(angle_offset)
				bullet_pool.spawn_bullet(spawn_pos, pellet_dir, 24.0, 800.0, 0.75)
			fire_cooldown = 0.70
			trigger_shake(6.5, 0.15)
			Global.play_sound("shotgun")
		
		Global.WeaponType.ASSAULT_RIFLE:
			Global.consume_ammo(Global.WeaponType.ASSAULT_RIFLE)
			var spread: float = randf_range(-0.06, 0.06)
			bullet_pool.spawn_bullet(spawn_pos, base_dir.rotated(spread), 32.0, 1050.0, 1.8)
			fire_cooldown = 0.095
			trigger_shake(3.2, 0.07)
			Global.play_sound("rifle")

func handle_camera_and_shake(delta: float) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * 8.0)
		
		if shake_timer > 0.0:
			shake_timer -= delta
			camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		else:
			camera.offset = Vector2.ZERO

func trigger_shake(intensity: float, duration: float = 0.1) -> void:
	shake_intensity = intensity
	shake_timer = duration

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or Global.is_game_over:
		return
	
	Global.take_player_damage(amount)
	invulnerability_timer = 0.4
	is_flashing = true
	trigger_shake(8.0, 0.2)
	Global.play_sound("hit")
	
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir.normalized() * 320.0
	
	queue_redraw()

func _draw() -> void:
	# Draw SWAT Commando character facing right (0 degrees)
	var body_color = Color(0.9, 0.2, 0.2, 1.0) if is_flashing else Color(0.18, 0.24, 0.35, 1.0)
	var vest_color = Color(0.12, 0.14, 0.18, 1.0)
	var skin_color = Color(0.92, 0.72, 0.58, 1.0)
	var gun_color = Color(0.15, 0.15, 0.15, 1.0)
	
	# Tactical Flashlight beam
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, 0),
		Vector2(240, -75),
		Vector2(260, 0),
		Vector2(240, 75)
	]), Color(1.0, 0.98, 0.85, 0.08))
	
	# Shoulders / Arms
	draw_circle(Vector2(6, -11), 6.5, vest_color)
	draw_circle(Vector2(6, 11), 6.5, vest_color)
	
	# Gun extending forward
	draw_rect(Rect2(8, 2, 22, 5), gun_color)
	draw_rect(Rect2(14, -6, 10, 4), gun_color)
	
	# Hands
	draw_circle(Vector2(18, 4), 3.5, skin_color)
	draw_circle(Vector2(28, 4), 3.5, skin_color)
	
	# Torso / Body armor
	draw_circle(Vector2(0, 0), 14.0, body_color)
	draw_rect(Rect2(-8, -9, 14, 18), vest_color)
	
	# Helmet / Head
	draw_circle(Vector2(-1, 0), 8.0, Color(0.14, 0.18, 0.26, 1.0))
	draw_arc(Vector2(2, 0), 5.0, -PI/2, PI/2, 8, Color(0.2, 0.7, 0.9, 0.8), 2.5) # Tactical Visor
