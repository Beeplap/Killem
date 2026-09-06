extends BaseZombie3D
class_name PlagueHound3D

enum HoundState { CHASE, PREPARE_LEAP, LEAPING, COOLDOWN }

@export var leap_speed: float = 17.5
@export var leap_duration: float = 0.38
@export var leap_cooldown_time: float = 3.2
@export var leap_min_range: float = 4.5
@export var leap_max_range: float = 9.5

var current_state: HoundState = HoundState.CHASE
var leap_cooldown_timer: float = 1.0 # Initial warmup
var leap_timer: float = 0.0
var leap_direction: Vector3 = Vector3.FORWARD
var has_hit_player_in_leap: bool = false
var gallop_cycle: float = 0.0

@onready var hound_visuals: Node3D = $Visuals
@onready var eye_light: OmniLight3D = $Visuals/Torso/Head/EyeLight
@onready var front_left_leg: Node3D = $Visuals/Torso/FrontLeftLeg
@onready var front_right_leg: Node3D = $Visuals/Torso/FrontRightLeg
@onready var back_left_leg: Node3D = $Visuals/Torso/BackLeftLeg
@onready var back_right_leg: Node3D = $Visuals/Torso/BackRightLeg

func _ready() -> void:
	max_hp = 75.0
	move_speed = 7.2
	attack_damage = 22.0
	attack_range = 1.2
	attack_cooldown = 0.8
	turn_speed = 14.0
	score_value = 150
	add_to_group("plague_hounds")
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return
	
	if leap_cooldown_timer > 0.0:
		leap_cooldown_timer -= delta
	
	match current_state:
		HoundState.CHASE:
			handle_chase_state(delta)
		HoundState.PREPARE_LEAP:
			handle_prepare_leap_state(delta)
		HoundState.LEAPING:
			handle_leaping_state(delta)
		HoundState.COOLDOWN:
			handle_cooldown_state(delta)

func handle_chase_state(delta: float) -> void:
	find_player()
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist >= leap_min_range and dist <= leap_max_range and leap_cooldown_timer <= 0.0:
			enter_prepare_leap()
			return
	
	# Normal chase movement
	super._physics_process(delta)
	
	# Gallop animation
	var spd = Vector2(velocity.x, velocity.z).length()
	if spd > 0.5:
		gallop_cycle += delta * 18.0
		if front_left_leg and front_right_leg:
			front_left_leg.rotation.x = sin(gallop_cycle) * 0.45
			front_right_leg.rotation.x = -sin(gallop_cycle) * 0.45
		if back_left_leg and back_right_leg:
			back_left_leg.rotation.x = -sin(gallop_cycle) * 0.45
			back_right_leg.rotation.x = sin(gallop_cycle) * 0.45

func enter_prepare_leap() -> void:
	current_state = HoundState.PREPARE_LEAP
	leap_timer = 0.28
	velocity = Vector3.ZERO
	
	# Face player directly
	if target_player and is_instance_valid(target_player):
		var look_vec = target_player.global_position - global_position
		look_vec.y = 0.0
		if look_vec.length_squared() > 0.01:
			rotation.y = atan2(look_vec.x, look_vec.z)
	
	# Visual telegraph: crouch squash
	if hound_visuals:
		hound_visuals.scale = Vector3(1.25, 0.65, 1.25)
	if eye_light:
		eye_light.light_energy = 4.0
	
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("hit")

func handle_prepare_leap_state(delta: float) -> void:
	leap_timer -= delta
	# Keep facing player during telegraph
	if target_player and is_instance_valid(target_player):
		var look_vec = target_player.global_position - global_position
		look_vec.y = 0.0
		if look_vec.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(look_vec.x, look_vec.z), delta * 20.0)
	
	if leap_timer <= 0.0:
		enter_leaping()

func enter_leaping() -> void:
	current_state = HoundState.LEAPING
	leap_timer = leap_duration
	has_hit_player_in_leap = false
	
	# Lock leap trajectory
	if target_player and is_instance_valid(target_player):
		var to_player = (target_player.global_position - global_position)
		to_player.y = 0.0
		leap_direction = to_player.normalized()
	else:
		leap_direction = -global_transform.basis.z
	
	# Visual stretch
	if hound_visuals:
		hound_visuals.scale = Vector3(0.75, 1.35, 0.75)
	if eye_light:
		eye_light.light_energy = 2.0

func handle_leaping_state(delta: float) -> void:
	leap_timer -= delta
	
	# High velocity linear movement ignoring obstacles/nav
	velocity.x = leap_direction.x * leap_speed
	velocity.z = leap_direction.z * leap_speed
	velocity.y = sin((1.0 - (leap_timer / leap_duration)) * PI) * 2.5
	
	move_and_slide()
	
	# Check collision with player during burst
	if not has_hit_player_in_leap:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var col_obj = col.get_collider()
			if col_obj and (col_obj.is_in_group("player") or col_obj.is_in_group("player3d")):
				if col_obj.has_method("take_damage"):
					col_obj.take_damage(attack_damage, leap_direction * 10.0)
				has_hit_player_in_leap = true
				break
	
	if leap_timer <= 0.0 or is_on_wall():
		enter_cooldown()

func enter_cooldown() -> void:
	current_state = HoundState.COOLDOWN
	leap_timer = 0.35 # Recovery pause on landing
	leap_cooldown_timer = leap_cooldown_time
	velocity = Vector3.ZERO
	
	# Restore normal scale
	if hound_visuals:
		hound_visuals.scale = Vector3(1.0, 1.0, 1.0)
	if eye_light:
		eye_light.light_energy = 1.0

func handle_cooldown_state(delta: float) -> void:
	leap_timer -= delta
	velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
	move_and_slide()
	
	if leap_timer <= 0.0:
		current_state = HoundState.CHASE
