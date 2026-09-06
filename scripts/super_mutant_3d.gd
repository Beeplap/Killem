extends BaseZombie3D
class_name SuperMutant3D

enum BossState { CHASE, STOMP_WINDUP, STOMPING, RUSH_PREP, RUSHING, RUSH_STUN }

@export var stomp_cooldown_time: float = 7.0
@export var rush_cooldown_time: float = 9.0
@export var rush_speed: float = 14.5
@export var rush_duration: float = 1.5

var current_boss_state: BossState = BossState.CHASE
var stomp_cooldown_timer: float = 3.0
var rush_cooldown_timer: float = 5.0
var state_timer: float = 0.0
var rush_direction: Vector3 = Vector3.FORWARD
var step_shake_timer: float = 0.0

@onready var left_fist: Node3D = $Visuals/Torso/LeftArm
@onready var right_fist: Node3D = $Visuals/Torso/RightArm
@onready var mutant_visuals: Node3D = $Visuals

const SHOCKWAVE_SCENE = preload("res://scenes/entities/Shockwave3D.tscn")

func _ready() -> void:
	max_hp = 1500.0
	move_speed = 3.6
	attack_damage = 38.0
	attack_range = 2.4
	attack_cooldown = 1.6
	knockback_resistance = 0.95
	turn_speed = 5.0
	score_value = 1000
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return
	
	if stomp_cooldown_timer > 0.0:
		stomp_cooldown_timer -= delta
	if rush_cooldown_timer > 0.0:
		rush_cooldown_timer -= delta
	
	match current_boss_state:
		BossState.CHASE:
			handle_boss_chase(delta)
		BossState.STOMP_WINDUP:
			handle_stomp_windup(delta)
		BossState.STOMPING:
			handle_stomping(delta)
		BossState.RUSH_PREP:
			handle_rush_prep(delta)
		BossState.RUSHING:
			handle_rushing(delta)
		BossState.RUSH_STUN:
			handle_rush_stun(delta)

func handle_boss_chase(delta: float) -> void:
	find_player()
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		
		# Ground stomp attack check (close/medium range)
		if dist <= 6.5 and stomp_cooldown_timer <= 0.0:
			enter_stomp_windup()
			return
		
		# Bull rush attack check (medium/long range)
		if dist >= 9.0 and dist <= 24.0 and rush_cooldown_timer <= 0.0:
			enter_rush_prep()
			return
	
	# Heavy footsteps screen shake
	var current_move_spd = Vector2(velocity.x, velocity.z).length()
	if current_move_spd > 0.5:
		step_shake_timer += delta
		if step_shake_timer >= 0.55:
			step_shake_timer = 0.0
			trigger_footstep_impact()
	
	super._physics_process(delta)

func trigger_footstep_impact() -> void:
	find_player()
	if target_player and is_instance_valid(target_player):
		var d = global_position.distance_to(target_player.global_position)
		if d < 18.0 and "add_trauma" in target_player:
			var trauma_amount = (1.0 - (d / 18.0)) * 0.12
			target_player.add_trauma(trauma_amount)
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("mutant_step", global_position)

func enter_stomp_windup() -> void:
	current_boss_state = BossState.STOMP_WINDUP
	state_timer = 0.75
	velocity = Vector3.ZERO
	
	# Raise massive fists overhead
	if left_fist and right_fist:
		left_fist.rotation.x = deg_to_rad(-140.0)
		right_fist.rotation.x = deg_to_rad(-140.0)
	
	# Telegraph roar / screenshake
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("mutant_roar", global_position)
	trigger_footstep_impact()

func handle_stomp_windup(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
	move_and_slide()
	
	# Slight crouch & tremble
	if mutant_visuals:
		mutant_visuals.position.x = randf_range(-0.04, 0.04)
	
	if state_timer <= 0.0:
		execute_ground_stomp()

func execute_ground_stomp() -> void:
	current_boss_state = BossState.STOMPING
	state_timer = 0.4
	
	if mutant_visuals:
		mutant_visuals.position.x = 0.0
	
	# Slam fists into the ground
	if left_fist and right_fist:
		left_fist.rotation.x = deg_to_rad(-20.0)
		right_fist.rotation.x = deg_to_rad(-20.0)
	
	# Spawn shockwave
	var scene = get_tree().current_scene
	if not scene:
		scene = get_parent()
	if not scene:
		scene = get_tree().root
	if scene:
		var wave = SHOCKWAVE_SCENE.instantiate()
		var wave_pos = global_position
		wave_pos.y = 0.05
		scene.add_child(wave)
		wave.global_position = wave_pos
	
	# Major screen shake
	find_player()
	if target_player and is_instance_valid(target_player) and "add_trauma" in target_player:
		target_player.add_trauma(0.55)
	
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("stomp_crash", global_position)
	
	stomp_cooldown_timer = stomp_cooldown_time

func handle_stomping(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_boss_state = BossState.CHASE

func enter_rush_prep() -> void:
	current_boss_state = BossState.RUSH_PREP
	state_timer = 0.6
	velocity = Vector3.ZERO
	
	# Lock charge direction towards player
	find_player()
	if target_player and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position)
		dir.y = 0.0
		rush_direction = dir.normalized()
		rotation.y = atan2(rush_direction.x, rush_direction.z)
	else:
		rush_direction = -global_transform.basis.z
	
	# Lower horns/head forward
	if mutant_visuals:
		mutant_visuals.rotation.x = deg_to_rad(15.0)
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("mutant_roar", global_position)

func handle_rush_prep(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
	move_and_slide()
	
	if state_timer <= 0.0:
		enter_rush()

func enter_rush() -> void:
	current_boss_state = BossState.RUSHING
	state_timer = rush_duration
	rush_cooldown_timer = rush_cooldown_time
	
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("mutant_roar", global_position)

func handle_rushing(delta: float) -> void:
	state_timer -= delta
	
	# Bull rush velocity along locked heading
	velocity.x = rush_direction.x * rush_speed
	velocity.z = rush_direction.z * rush_speed
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = -0.5
	
	move_and_slide()
	
	# Destroy destructibles and damage player in path
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider:
			if collider.is_in_group("player") or collider.is_in_group("player3d"):
				if collider.has_method("take_damage"):
					collider.take_damage(45.0, rush_direction * 18.0)
				if "add_trauma" in collider:
					collider.add_trauma(0.6)
			elif collider.is_in_group("destructibles") or collider.is_in_group("obstacles"):
				# Smash through wooden pallets, barrels, fences
				if collider.name.begins_with("Pallet") or collider.name.begins_with("Fence") or collider.name.begins_with("Oil"):
					if collider.has_method("queue_free"):
						collider.queue_free()
			elif collider.name.begins_with("BlastWall") or collider is StaticBody3D:
				# Impacted massive concrete wall: stun!
				enter_rush_stun()
				return
	
	if state_timer <= 0.0 or is_on_wall():
		enter_rush_stun()

func enter_rush_stun() -> void:
	current_boss_state = BossState.RUSH_STUN
	state_timer = 1.1
	velocity = Vector3.ZERO
	
	if mutant_visuals:
		mutant_visuals.rotation.x = deg_to_rad(-12.0)
	
	# Heavy wall impact shake
	find_player()
	if target_player and is_instance_valid(target_player) and "add_trauma" in target_player:
		target_player.add_trauma(0.4)
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("stomp_crash", global_position)

func handle_rush_stun(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector3.ZERO, delta * 20.0)
	move_and_slide()
	
	if state_timer <= 0.0:
		if mutant_visuals:
			mutant_visuals.rotation.x = 0.0
		current_boss_state = BossState.CHASE
