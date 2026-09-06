extends CharacterBody3D
class_name GoliathBoss3D

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_changed(phase: int)
signal boss_defeated_signal

enum Phase { PHASE_1 = 1, PHASE_2 = 2, PHASE_3 = 3 }
enum State { IDLE, CHASE, CLEAVE_WINDUP, CLEAVE_ATTACK, BOULDER_WINDUP, BOULDER_THROW, LEAP_WINDUP, LEAP_AIR, LEAP_LAND, STUNNED, DEAD }

@export var max_health: float = 2500.0
var current_health: float = 2500.0
var current_phase: Phase = Phase.PHASE_1
var current_state: State = State.IDLE

# Movement
@export var base_speed: float = 3.5
var current_speed: float = 3.5
var target_player: Node3D = null

# Attack timers & cooldowns
var state_timer: float = 0.0
var cleave_cooldown: float = 2.0
var boulder_cooldown: float = 5.0
var leap_cooldown: float = 8.0
var hound_spawn_cooldown: float = 12.0
var radiation_tick_timer: float = 0.0

# Leap Slam coordinates
var leap_target_pos: Vector3 = Vector3.ZERO
var leap_shadow_pos: Vector3 = Vector3.ZERO
var leap_start_y: float = 0.0

# Node References
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var mesh_root: Node3D = get_node_or_null("MeshRoot")
@onready var goliath_mesh: MeshInstance3D = get_node_or_null("MeshRoot/GoliathMesh")
@onready var core_light: OmniLight3D = get_node_or_null("MeshRoot/MoltenCoreLight")
@onready var weak_point_light: OmniLight3D = get_node_or_null("MeshRoot/WeakPointLight")
@onready var cleave_indicator: MeshInstance3D = get_node_or_null("CleaveIndicator")
@onready var leap_indicator: MeshInstance3D = get_node_or_null("LeapIndicator")
@onready var vent_smoke: CPUParticles3D = get_node_or_null("MeshRoot/VentSmokeParticles")
@onready var radiation_particles: CPUParticles3D = get_node_or_null("MeshRoot/RadiationParticles")
@onready var held_boulder: MeshInstance3D = get_node_or_null("MeshRoot/HeldBoulder")

const BOULDER_SCENE = preload("res://scenes/entities/BoulderProjectile3D.tscn")
const HOUND_SCENE = preload("res://scenes/enemies/PlagueHound3D.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_health = max_health
	current_speed = base_speed
	
	if cleave_indicator: cleave_indicator.visible = false
	if leap_indicator: leap_indicator.visible = false
	if held_boulder: held_boulder.visible = false
	if vent_smoke: vent_smoke.emitting = false
	if radiation_particles: radiation_particles.emitting = false
	if weak_point_light: weak_point_light.visible = false
	
	# Initial roar
	Global.play_sound("boss_roar", global_position)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or Global.is_game_over:
		return
	
	# Find player if null
	if not target_player or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player")
		if not target_player:
			return
	
	# Update cooldowns
	cleave_cooldown -= delta
	boulder_cooldown -= delta
	if current_phase >= Phase.PHASE_2:
		leap_cooldown -= delta
		hound_spawn_cooldown -= delta
		if hound_spawn_cooldown <= 0.0:
			spawn_plague_hounds()
	
	# Phase 3 Radiation Field
	if current_phase == Phase.PHASE_3:
		handle_radiation_field(delta)
	
	# Core light pulse
	if core_light:
		var pulse_spd = 0.008 if current_phase == Phase.PHASE_1 else (0.016 if current_phase == Phase.PHASE_2 else 0.028)
		core_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * pulse_spd) * 0.9
	
	match current_state:
		State.IDLE, State.CHASE:
			handle_chase_state(delta)
		State.CLEAVE_WINDUP:
			handle_cleave_windup(delta)
		State.CLEAVE_ATTACK:
			handle_cleave_attack(delta)
		State.BOULDER_WINDUP:
			handle_boulder_windup(delta)
		State.BOULDER_THROW:
			handle_boulder_throw(delta)
		State.LEAP_WINDUP:
			handle_leap_windup(delta)
		State.LEAP_AIR:
			handle_leap_air(delta)
		State.LEAP_LAND:
			handle_leap_land(delta)
		State.STUNNED:
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHASE
	
	# Apply standard gravity when not in leap air
	if current_state != State.LEAP_AIR:
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		else:
			if velocity.y < 0.0:
				velocity.y = -0.5
		move_and_slide()

func handle_chase_state(delta: float) -> void:
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	
	# Smooth rotation facing player
	if dist > 0.2:
		var face_dir = to_player.normalized()
		var target_rot = atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
	
	# AI Decision tree based on distance & cooldowns
	if current_phase >= Phase.PHASE_2 and leap_cooldown <= 0.0 and dist > 7.0:
		start_leap_slam()
		return
	
	if dist <= 5.5 and cleave_cooldown <= 0.0:
		start_cleave_attack()
		return
	
	if dist >= 7.5 and boulder_cooldown <= 0.0:
		start_boulder_hurl()
		return
	
	# Pursue player
	var move_dir = to_player.normalized()
	if nav_agent and not nav_agent.is_navigation_finished():
		nav_agent.target_position = target_player.global_position
		var next_point = nav_agent.get_next_path_position()
		var pdir = (next_point - global_position)
		pdir.y = 0.0
		if pdir.length_squared() > 0.04:
			move_dir = pdir.normalized()
	
	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed

# --- ATTACK 1: CLEAVE ATTACK (180° Frontal Arc) ---
func start_cleave_attack() -> void:
	current_state = State.CLEAVE_WINDUP
	state_timer = 0.65
	velocity.x = 0.0
	velocity.z = 0.0
	cleave_cooldown = 4.2 if current_phase == Phase.PHASE_1 else 3.2
	
	if cleave_indicator:
		cleave_indicator.visible = true
	
	Global.play_sound("boss_cleave", global_position)

func handle_cleave_windup(delta: float) -> void:
	state_timer -= delta
	# Slow pivot toward player during early windup
	if state_timer > 0.25 and target_player:
		var to_p = (target_player.global_position - global_position)
		to_p.y = 0.0
		var target_rot = atan2(-to_p.x, -to_p.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 6.0)
	
	if state_timer <= 0.0:
		execute_cleave_sweep()

func execute_cleave_sweep() -> void:
	current_state = State.CLEAVE_ATTACK
	state_timer = 0.25
	
	if cleave_indicator:
		cleave_indicator.visible = false
	
	Global.play_sound("boss_slam", global_position)
	
	# Check 180-degree frontal cone within 5.8m
	if target_player and is_instance_valid(target_player):
		var to_player = target_player.global_position - global_position
		to_player.y = 0.0
		var dist = to_player.length()
		
		if dist <= 5.8:
			var forward = -transform.basis.z.normalized()
			var pdir = to_player.normalized()
			var dot = forward.dot(pdir)
			
			# 180° arc corresponds to dot >= -0.05
			if dot >= -0.05:
				var dmg = 42.0 if current_phase == Phase.PHASE_1 else 52.0
				target_player.take_damage(dmg, forward)
				if target_player.has_method("add_trauma"):
					target_player.add_trauma(0.48)

func handle_cleave_attack(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

# --- ATTACK 2: BOULDER HURL (3D Rock Debris) ---
func start_boulder_hurl() -> void:
	current_state = State.BOULDER_WINDUP
	state_timer = 0.85
	velocity.x = 0.0
	velocity.z = 0.0
	boulder_cooldown = 6.5 if current_phase == Phase.PHASE_1 else 5.2
	
	if held_boulder:
		held_boulder.visible = true
	
	Global.play_sound("rock_impact", global_position)

func handle_boulder_windup(delta: float) -> void:
	state_timer -= delta
	if target_player:
		var to_p = (target_player.global_position - global_position)
		to_p.y = 0.0
		var target_rot = atan2(-to_p.x, -to_p.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
	
	if state_timer <= 0.0:
		throw_boulder()

func throw_boulder() -> void:
	current_state = State.BOULDER_THROW
	state_timer = 0.3
	
	if held_boulder:
		held_boulder.visible = false
	
	if target_player and is_instance_valid(target_player):
		var scene = get_tree().current_scene
		if scene:
			var boulder = BOULDER_SCENE.instantiate()
			scene.add_child(boulder)
			var spawn_origin = global_position + Vector3(0, 3.2, 0) - transform.basis.z * 1.5
			var lead_pos = target_player.global_position + (target_player.velocity * 0.45)
			boulder.setup(spawn_origin, lead_pos, 22.0, 38.0)
	
	Global.play_sound("boss_slam", global_position)

func handle_boulder_throw(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

# --- ATTACK 3: LEAP SLAM (Phase 2 & 3) ---
func start_leap_slam() -> void:
	current_state = State.LEAP_WINDUP
	state_timer = 0.45
	velocity = Vector3.ZERO
	leap_cooldown = 9.5
	leap_start_y = global_position.y
	
	Global.play_sound("boss_roar", global_position)

func handle_leap_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		launch_into_air()

func launch_into_air() -> void:
	current_state = State.LEAP_AIR
	state_timer = 1.5
	
	if target_player:
		leap_target_pos = target_player.global_position
		leap_target_pos.y = leap_start_y
	else:
		leap_target_pos = global_position
	
	if leap_indicator:
		leap_indicator.visible = true
		leap_indicator.global_position = leap_target_pos + Vector3(0, 0.05, 0)
	
	# High jump
	velocity = Vector3(0, 24.0, 0)

func handle_leap_air(delta: float) -> void:
	state_timer -= delta
	
	# For first 1.0s, the shadow tracks player. In final 0.5s, shadow locks in place!
	if state_timer > 0.5 and target_player:
		leap_target_pos = target_player.global_position
		leap_target_pos.y = leap_start_y
	
	if leap_indicator:
		leap_indicator.global_position = leap_target_pos + Vector3(0, 0.05, 0)
	
	# Move position toward target XZ in mid-air
	var air_t = 1.0 - (state_timer / 1.5)
	global_position.x = lerpf(global_position.x, leap_target_pos.x, delta * 6.0)
	global_position.z = lerpf(global_position.z, leap_target_pos.z, delta * 6.0)
	
	if state_timer <= 0.3:
		# Rapid dive down
		velocity.y = -35.0
	
	global_position += velocity * delta
	
	if state_timer <= 0.0 or global_position.y <= leap_start_y + 0.1:
		crash_land()

func crash_land() -> void:
	current_state = State.LEAP_LAND
	state_timer = 0.5
	global_position = leap_target_pos
	global_position.y = leap_start_y
	velocity = Vector3.ZERO
	
	if leap_indicator:
		leap_indicator.visible = false
	
	Global.play_sound("boss_slam", global_position)
	
	# AoE Damage & Shockwave
	var scene = get_tree().current_scene
	if scene:
		var particles = CPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 32
		particles.lifetime = 0.5
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 85.0
		particles.initial_velocity_min = 8.0
		particles.initial_velocity_max = 18.0
		particles.gravity = Vector3(0, -16.0, 0)
		
		var box = BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		particles.mesh = box
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.38, 0.35)
		particles.material_override = mat
		
		scene.add_child(particles)
		particles.global_position = global_position
		particles.finished.connect(particles.queue_free)
	
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 6.5:
			var dmg = lerp(65.0, 20.0, dist / 6.5)
			var knock_dir = (target_player.global_position - global_position).normalized()
			target_player.take_damage(dmg, knock_dir)
			if target_player.has_method("add_trauma"):
				target_player.add_trauma(0.85)

func handle_leap_land(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

# --- PHASE 2 MINION SUMMONING ---
func spawn_plague_hounds() -> void:
	hound_spawn_cooldown = 14.0
	Global.play_sound("screamer", global_position)
	
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var offsets = [Vector3(-3.5, 0, -2.0), Vector3(3.5, 0, -2.0)]
	for off in offsets:
		var hound = HOUND_SCENE.instantiate()
		scene.add_child(hound)
		hound.global_position = global_position + off
		if hound.has_method("take_damage"):
			hound.velocity = off.normalized() * 5.0

# --- PHASE 3 RADIATION FIELD ---
func handle_radiation_field(delta: float) -> void:
	radiation_tick_timer -= delta
	if radiation_tick_timer <= 0.0:
		radiation_tick_timer = 0.4
		if target_player and is_instance_valid(target_player):
			var dist = global_position.distance_to(target_player.global_position)
			if dist <= 5.5:
				target_player.take_damage(5.0, Vector3.ZERO) # 12.5 DPS
				Global.play_sound("radiation_tick", global_position)

# --- DAMAGE & PHASE TRANSITIONS ---
func take_damage(dmg: float, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return
	
	# Check if hit is from behind or on the exposed weak point
	var is_back_hit: bool = false
	if hit_direction != Vector3.ZERO:
		var forward = -transform.basis.z.normalized()
		# If projectile is traveling in roughly the same direction as Goliath's forward, it entered from the rear
		var dot = forward.dot(hit_direction.normalized())
		if dot > 0.35:
			is_back_hit = true
	
	var final_dmg = dmg
	if current_phase == Phase.PHASE_3 and is_back_hit:
		# +200% Critical Damage on Exposed Weak Point
		final_dmg = dmg * 3.0
		Global.play_sound("hit", global_position)
		spawn_crit_sparks()
	
	current_health = max(0.0, current_health - final_dmg)
	boss_health_changed.emit(current_health, max_health)
	
	# Flash mesh damage
	flash_damage_tint(is_back_hit)
	
	# Phase transition checks
	var health_ratio = current_health / max_health
	if current_phase == Phase.PHASE_1 and health_ratio <= 0.60:
		transition_to_phase(Phase.PHASE_2)
	elif current_phase == Phase.PHASE_2 and health_ratio <= 0.20:
		transition_to_phase(Phase.PHASE_3)
	
	if current_health <= 0.0:
		die()

func transition_to_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	boss_phase_changed.emit(int(new_phase))
	
	if new_phase == Phase.PHASE_2:
		# Enrage: 35% speed boost, smoke vents
		current_speed = base_speed * 1.35
		if vent_smoke:
			vent_smoke.emitting = true
		Global.play_sound("boss_roar", global_position)
		spawn_plague_hounds()
		
	elif new_phase == Phase.PHASE_3:
		# Meltdown: Exposed glowing back weak point, radiation aura
		if radiation_particles:
			radiation_particles.emitting = true
		if weak_point_light:
			weak_point_light.visible = true
		Global.play_sound("boss_alarm", global_position)

func flash_damage_tint(is_crit: bool) -> void:
	if not mesh_root:
		return
	
	var punch = 1.05 if not is_crit else 1.12
	mesh_root.scale = Vector3(punch, punch, punch)
	var tween = create_tween()
	tween.tween_property(mesh_root, "scale", Vector3.ONE, 0.1)

func spawn_crit_sparks() -> void:
	var scene = get_tree().current_scene
	if not scene: return
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 20
	particles.lifetime = 0.3
	particles.direction = transform.basis.z # shoot backwards
	particles.spread = 45.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 14.0
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	particles.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	particles.material_override = mat
	
	scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 3.4, -0.9)
	particles.finished.connect(particles.queue_free)

func die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	boss_defeated_signal.emit()
	Global.play_sound("boss_roar", global_position)
	Global.add_kill(5000)
	
	# Death collapse tween
	var tween = create_tween()
	tween.tween_property(self, "position:y", global_position.y - 0.5, 1.2)
	tween.parallel().tween_property(mesh_root, "rotation:x", deg_to_rad(85.0), 1.2)
	tween.tween_callback(func():
		# Spawn massive death explosion
		Global.play_sound("explode", global_position)
		queue_free()
	)
