extends "res://scripts/zombie.gd"

enum DogState {
	CHASE,
	PREPARE_LEAP,
	LEAPING,
	COOLDOWN
}

@export var leap_min_distance: float = 175.0
@export var leap_max_distance: float = 225.0
@export var prepare_leap_duration: float = 0.25
@export var leap_duration: float = 0.35
@export var leap_landing_duration: float = 0.40
@export var leap_cooldown_time: float = 3.5
@export var leap_speed_multiplier: float = 3.2
@export var pounce_damage_multiplier: float = 1.75

var dog_state: DogState = DogState.CHASE
var state_timer: float = 0.0
var leap_cooldown_timer: float = 0.0
var leap_direction: Vector2 = Vector2.ZERO
var has_damaged_during_leap: bool = false
var normal_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	zombie_type = ZombieType.INFECTED_DOG
	super._ready()
	normal_scale = scale

func _physics_process(delta: float) -> void:
	if current_health <= 0.0:
		# Still run death fall animation if active
		if death_anim_progress >= 0.0:
			_animate_walk_cycle(delta)
		return
	
	if player == null or not is_instance_valid(player):
		_find_player()
		return
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("flash_amount", 0.0)
			elif sprite:
				sprite.modulate = Color.WHITE
	
	# Knockback decay
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	
	var target_pos = player.global_position
	var dist_to_player = global_position.distance_to(target_pos)
	
	# Distance-Based Hibernation (Off-Screen Culling)
	if dist_to_player > HIBERNATION_DISTANCE:
		if not is_hibernating:
			is_hibernating = true
			if collision_shape:
				collision_shape.disabled = true
			if sprite:
				sprite.visible = false
		velocity = (target_pos - global_position).normalized() * (speed * 0.75)
		global_position += velocity * delta
		return
	elif is_hibernating:
		is_hibernating = false
		if collision_shape:
			collision_shape.disabled = false
		if sprite:
			sprite.visible = true
	
	match dog_state:
		DogState.CHASE:
			_process_chase(delta, target_pos, dist_to_player)
		
		DogState.PREPARE_LEAP:
			_process_prepare_leap(delta, target_pos)
		
		DogState.LEAPING:
			_process_leaping(delta)
		
		DogState.COOLDOWN:
			_process_cooldown(delta)

func _process_chase(delta: float, target_pos: Vector2, dist_to_player: float) -> void:
	if leap_cooldown_timer > 0.0:
		leap_cooldown_timer -= delta
	
	# Check leap trigger: within 180px - 220px of player and leap cooldown is off
	if leap_cooldown_timer <= 0.0 and dist_to_player >= leap_min_distance and dist_to_player <= leap_max_distance:
		enter_prepare_leap(target_pos)
		return
	
	# Normal chase orientation
	var face_dir = (target_pos - global_position).normalized()
	update_facing(face_dir)
	
	# Staggered navigation updates
	nav_refresh_timer -= delta
	if nav_refresh_timer <= 0.0:
		nav_refresh_timer = 0.2 + randf_range(-0.05, 0.05)
		if nav_agent and is_instance_valid(player):
			nav_agent.target_position = target_pos
	
	# Pathfinding using NavigationAgent2D with direct fallback
	var move_dir: Vector2 = Vector2.ZERO
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		move_dir = (next_path_pos - global_position).normalized()
	
	if move_dir == Vector2.ZERO or nav_agent.is_target_reached():
		move_dir = (target_pos - global_position).normalized()
	
	if dist_to_player > (attack_range * 0.75):
		velocity = (move_dir * speed) + knockback_velocity
	else:
		velocity = knockback_velocity
		if attack_timer <= 0.0 and dist_to_player <= attack_range:
			perform_attack()
	
	move_and_slide()
	
	# Procedural gallop animation during chase
	_animate_walk_cycle(delta)

func enter_prepare_leap(target_pos: Vector2) -> void:
	dog_state = DogState.PREPARE_LEAP
	state_timer = prepare_leap_duration
	velocity = Vector2.ZERO
	
	# Look directly at the player's current position
	leap_direction = (target_pos - global_position).normalized()
	update_facing(leap_direction)
	
	# Slightly squash scale to visually telegraph the leap
	scale = normal_scale * Vector2(1.2, 0.8)

func _process_prepare_leap(delta: float, target_pos: Vector2) -> void:
	# Stop moving for 0.25s, track player gaze
	leap_direction = (target_pos - global_position).normalized()
	update_facing(leap_direction)
	
	velocity = knockback_velocity
	move_and_slide()
	
	# Crouching animation — compress sprite downward
	if sprite:
		var crouch_t = 1.0 - (state_timer / prepare_leap_duration)
		sprite.offset = sprite_base_offset + Vector2(0, crouch_t * 3.0)
		sprite.scale = Vector2(1.0 + crouch_t * 0.1, 1.0 - crouch_t * 0.15)
	
	state_timer -= delta
	if state_timer <= 0.0:
		enter_leaping()

func enter_leaping() -> void:
	dog_state = DogState.LEAPING
	state_timer = leap_duration
	has_damaged_during_leap = false
	
	# Set velocity to direction * (base_speed * 3.2)
	var leap_speed = speed * leap_speed_multiplier
	velocity = (leap_direction * leap_speed) + knockback_velocity
	
	# Stretch scale during forward thrust
	scale = normal_scale * Vector2(0.8, 1.3)
	update_facing(leap_direction)
	Global.play_sound("zombie_groan")

func _process_leaping(delta: float) -> void:
	# Direct linear movement burst (ignore pathfinding during leap)
	var leap_speed = speed * leap_speed_multiplier
	velocity = (leap_direction * leap_speed) + knockback_velocity
	move_and_slide()
	
	# Airborne stretch animation — elongate in movement direction
	if sprite:
		var leap_progress = 1.0 - (state_timer / leap_duration)
		# Arc motion: rise then fall
		var arc_height = sin(leap_progress * PI) * 6.0
		sprite.offset = sprite_base_offset + Vector2(0, -arc_height)
		sprite.scale = Vector2(0.88, 1.12)
		sprite.rotation = leap_direction.angle() * 0.15
	
	# Deal damage if it intersects the player during LEAPING
	if not has_damaged_during_leap and _check_player_leap_intersection():
		has_damaged_during_leap = true
		if player and player.has_method("take_damage"):
			player.take_damage(attack_damage * pounce_damage_multiplier, leap_direction)
			Global.play_sound("hit")
			if player.has_method("trigger_shake"):
				player.trigger_shake(6.0, 0.2)
	
	state_timer -= delta
	if state_timer <= 0.0:
		enter_cooldown()

func enter_cooldown() -> void:
	dog_state = DogState.COOLDOWN
	state_timer = leap_landing_duration
	
	# Restore normal scale upon landing
	scale = normal_scale
	velocity = Vector2.ZERO
	
	# Landing impact squash
	if sprite:
		sprite.scale = Vector2(1.15, 0.85)
		sprite.offset = sprite_base_offset + Vector2(0, 3.0)

func _process_cooldown(delta: float) -> void:
	# Pause movement for 0.4s upon landing
	velocity = knockback_velocity
	move_and_slide()
	
	# Recover from landing squash to normal
	if sprite:
		var recover_t = 1.0 - (state_timer / leap_landing_duration)
		sprite.scale = Vector2(
			lerp(1.15, 1.0, recover_t),
			lerp(0.85, 1.0, recover_t)
		)
		sprite.offset = sprite_base_offset + Vector2(0, lerp(3.0, 0.0, recover_t))
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
	
	state_timer -= delta
	if state_timer <= 0.0:
		# Return to normal CHASE state with 3.5s cooldown
		dog_state = DogState.CHASE
		leap_cooldown_timer = leap_cooldown_time

func _check_player_leap_intersection() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	
	# Distance proximity check
	if global_position.distance_to(player.global_position) <= (attack_range + 16.0):
		return true
	
	# Slide collision contact check
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player"):
			return true
	
	return false

func die(hit_direction: Vector2, is_headshot: bool = false) -> void:
	scale = normal_scale
	super.die(hit_direction, is_headshot)
