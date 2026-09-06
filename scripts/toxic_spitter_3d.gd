extends BaseZombie3D
class_name ToxicSpitter3D

@export var spit_cooldown_time: float = 2.8
@export var min_ranged_dist: float = 6.0
@export var max_ranged_dist: float = 16.0

var spit_cooldown_timer: float = 0.5
var is_spitting: bool = false
var spit_windup_timer: float = 0.0

@onready var pustule_light: OmniLight3D = $Visuals/Torso/PustuleLight
@onready var pustule_mesh1: MeshInstance3D = $Visuals/Torso/PustuleCluster/Pustule1
@onready var pustule_mesh2: MeshInstance3D = $Visuals/Torso/PustuleCluster/Pustule2
@onready var mouth_marker: Marker3D = $Visuals/Torso/Head/MouthMarker

const BILE_PROJECTILE_SCENE = preload("res://scenes/entities/BileProjectile3D.tscn")
const PUDDLE_SCENE = preload("res://scenes/entities/ToxicPuddle3D.tscn")

func _ready() -> void:
	max_hp = 130.0
	move_speed = 3.2
	attack_damage = 18.0
	attack_range = 1.6
	attack_cooldown = 1.2
	score_value = 250
	turn_speed = 8.0
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead:
		super._physics_process(delta)
		return
	
	if spit_cooldown_timer > 0.0:
		spit_cooldown_timer -= delta
	
	# Pustule pulsation glow
	if pustule_light:
		var pulse = sin(Time.get_ticks_msec() * 0.006) * 0.4 + 1.2
		pustule_light.light_energy = pulse if not is_spitting else 3.5
	
	if is_spitting:
		handle_spit_windup(delta)
		return
	
	find_player()
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		
		# If in ranged bracket and cooldown ready, initiate spit attack
		if dist >= min_ranged_dist and dist <= max_ranged_dist and spit_cooldown_timer <= 0.0:
			start_spit_attack()
			return
		
		# Tactical distancing: if player is too close, backpedal away
		if dist < min_ranged_dist - 1.5:
			var away_dir = (global_position - target_player.global_position)
			away_dir.y = 0.0
			if away_dir.length_squared() > 0.01:
				away_dir = away_dir.normalized()
				velocity.x = move_toward(velocity.x, away_dir.x * move_speed * 0.85, delta * 20.0)
				velocity.z = move_toward(velocity.z, away_dir.z * move_speed * 0.85, delta * 20.0)
				
				# Face the player while retreating
				var face_dir = (target_player.global_position - global_position).normalized()
				rotation.y = lerp_angle(rotation.y, atan2(face_dir.x, face_dir.z), delta * turn_speed)
				
				# Gravity & movement
				if not is_on_floor(): velocity.y -= 18.0 * delta
				else: velocity.y = -0.5
				move_and_slide()
				return
	
	super._physics_process(delta)

func start_spit_attack() -> void:
	is_spitting = true
	spit_windup_timer = 0.45
	velocity = Vector3.ZERO
	
	# Face player directly
	if target_player and is_instance_valid(target_player):
		var look_vec = target_player.global_position - global_position
		look_vec.y = 0.0
		if look_vec.length_squared() > 0.01:
			rotation.y = atan2(look_vec.x, look_vec.z)

func handle_spit_windup(delta: float) -> void:
	spit_windup_timer -= delta
	
	# Track player aiming
	if target_player and is_instance_valid(target_player):
		var look_vec = target_player.global_position - global_position
		look_vec.y = 0.0
		if look_vec.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(look_vec.x, look_vec.z), delta * 12.0)
	
	if spit_windup_timer <= 0.0:
		fire_bile_projectile()
		is_spitting = false
		spit_cooldown_timer = spit_cooldown_time

func fire_bile_projectile() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	find_player()
	if target_player == null or not is_instance_valid(target_player):
		return
	
	var spawn_pos = mouth_marker.global_position if mouth_marker else global_position + Vector3(0, 1.4, 0)
	var bile = BILE_PROJECTILE_SCENE.instantiate()
	scene.add_child(bile)
	bile.setup(spawn_pos, target_player.global_position + Vector3(0, 0.5, 0))
	
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("explode")

func on_death(_death_dir: Vector3) -> void:
	# Pustules burst into an acid puddle upon death
	var scene = get_tree().current_scene
	if not scene:
		scene = get_parent()
	if not scene:
		scene = get_tree().root
	if scene:
		var puddle = PUDDLE_SCENE.instantiate()
		var p_pos = global_position
		p_pos.y = 0.02
		scene.add_child(puddle)
		puddle.global_position = p_pos
