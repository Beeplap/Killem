extends CharacterBody2D
class_name GoliathBoss

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_changed(phase: int)
signal boss_defeated_signal

enum Phase { PHASE_1 = 1, PHASE_2 = 2, PHASE_3 = 3 }
enum State {
	IDLE,
	CHASE,
	GROUND_QUAKE_WINDUP,
	GROUND_QUAKE_ATTACK,
	SWEEP_WINDUP,
	SWEEP_ATTACK,
	CHARGE_TELEGRAPH,
	CHARGE_RUSH,
	CHARGE_STUNNED,
	DEBRIS_WINDUP,
	DEBRIS_THROW,
	ROAR_RALLY,
	DEAD
}

@export var max_health: float = 2500.0
var current_health: float = 2500.0
var current_phase: Phase = Phase.PHASE_1
var current_state: State = State.IDLE

# Movement tuning
@export var base_speed: float = 95.0
var current_speed: float = 95.0
var current_facing_dir: Vector2 = Vector2.DOWN

# Target
var target_player: Node2D = null

# Attack Timers & Cooldowns
var state_timer: float = 0.0
var ground_quake_cooldown: float = 3.0
var sweep_cooldown: float = 1.5
var charge_cooldown: float = 7.0
var debris_cooldown: float = 4.5
var horde_rally_cooldown: float = 8.0
var radiation_tick_timer: float = 0.0

# Charge Attack parameters
var charge_dir: Vector2 = Vector2.DOWN
var charge_speed: float = 330.0 # 3.5x base speed
var charge_duration_timer: float = 0.0
const CHARGE_MAX_DURATION: float = 1.5

# Telegraph Engine parameters
enum TelegraphType { NONE, CONE_180, LINEAR_LANE, CIRCLE }
var active_telegraph_type: TelegraphType = TelegraphType.NONE
var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.8
var telegraph_angle: float = 0.0
var telegraph_range: float = 180.0
var telegraph_width: float = 70.0

# Node references
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var weak_point_light: PointLight2D = get_node_or_null("WeakPointLight")
@onready var radiation_particles: CPUParticles2D = get_node_or_null("RadiationParticles")
@onready var telegraph_drawer: Node2D = get_node_or_null("TelegraphDrawer")
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")

const BOULDER_SCENE = preload("res://scenes/entities/BoulderProjectile2D.tscn")
const PICKUP_SCENE = preload("res://scenes/Pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	
	current_health = max_health
	current_speed = base_speed
	
	if weak_point_light:
		weak_point_light.enabled = false
	if radiation_particles:
		radiation_particles.emitting = false
	
	# Configure visual drop shadow
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 32), Vector2(2.8, 1.2))
	
	# Initial boss awakening roar
	Global.play_sound("boss_roar", global_position)
	
	boss_health_changed.emit(current_health, max_health)
	boss_phase_changed.emit(1)
	
	call_deferred("_find_player")

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or Global.is_game_over:
		return
	
	if target_player == null or not is_instance_valid(target_player):
		_find_player()
	
	# Decrement attack cooldowns
	ground_quake_cooldown -= delta
	sweep_cooldown -= delta
	charge_cooldown -= delta
	debris_cooldown -= delta
	horde_rally_cooldown -= delta
	
	# Phase 3: Toxic radiation aura
	if current_phase == Phase.PHASE_3:
		handle_radiation_aura(delta)
		if horde_rally_cooldown <= 0.0:
			horde_rally_cooldown = 8.0
			summon_perimeter_reinforcements()
	
	# Update telegraph animation if active
	if active_telegraph_type != TelegraphType.NONE:
		telegraph_timer += delta
		if telegraph_drawer:
			telegraph_drawer.queue_redraw()
	
	match current_state:
		State.IDLE, State.CHASE:
			handle_chase_state(delta)
		State.GROUND_QUAKE_WINDUP:
			handle_ground_quake_windup(delta)
		State.GROUND_QUAKE_ATTACK:
			handle_ground_quake_attack(delta)
		State.SWEEP_WINDUP:
			handle_sweep_windup(delta)
		State.SWEEP_ATTACK:
			handle_sweep_attack(delta)
		State.CHARGE_TELEGRAPH:
			handle_charge_telegraph(delta)
		State.CHARGE_RUSH:
			handle_charge_rush(delta)
		State.CHARGE_STUNNED:
			handle_charge_stunned(delta)
		State.DEBRIS_WINDUP:
			handle_debris_windup(delta)
		State.DEBRIS_THROW:
			handle_debris_throw(delta)
		State.ROAR_RALLY:
			handle_roar_rally(delta)

# -------------------------------------------------------------------------
# State Machine Implementations
# -------------------------------------------------------------------------

func handle_chase_state(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		# Headless or player dead: idle safely
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	current_facing_dir = to_player.normalized()
	update_sprite_facing(current_facing_dir)
	
	# Phase decision tree
	if current_phase == Phase.PHASE_1:
		# Phase 1: Heavy Cleave & Ground Smash (100% - 65% HP)
		if dist <= 85.0 and sweep_cooldown <= 0.0:
			start_sweep_attack()
			return
		elif dist <= 190.0 and ground_quake_cooldown <= 0.0:
			start_ground_quake()
			return
	elif current_phase == Phase.PHASE_2:
		# Phase 2: Bull Rush & Boulder Hurl (65% - 25% HP)
		if dist >= 160.0 and charge_cooldown <= 0.0:
			start_charge_telegraph()
			return
		elif dist >= 140.0 and debris_cooldown <= 0.0:
			start_debris_hurl()
			return
		elif dist <= 90.0 and sweep_cooldown <= 0.0:
			start_sweep_attack()
			return
		elif dist <= 180.0 and ground_quake_cooldown <= 0.0:
			start_ground_quake()
			return
	else:
		# Phase 3: Core Meltdown & Horde Rally (< 25% HP)
		if dist >= 180.0 and charge_cooldown <= 0.0:
			start_charge_telegraph()
			return
		elif debris_cooldown <= 0.0:
			start_debris_hurl()
			return
		elif dist <= 100.0 and sweep_cooldown <= 0.0:
			start_sweep_attack()
			return
		elif ground_quake_cooldown <= 0.0:
			start_ground_quake()
			return
	
	# Standard movement navigation
	velocity = current_facing_dir * current_speed
	move_and_slide()

# -------------------------------------------------------------------------
# Phase 1: Ground Quake Slam (180° Frontal Cone)
# -------------------------------------------------------------------------
func start_ground_quake() -> void:
	current_state = State.GROUND_QUAKE_WINDUP
	state_timer = 0.8 # 0.8s warning window
	velocity = Vector2.ZERO
	
	if target_player and is_instance_valid(target_player):
		current_facing_dir = (target_player.global_position - global_position).normalized()
	update_sprite_facing(current_facing_dir)
	
	# Telegraph 180° frontal cone
	active_telegraph_type = TelegraphType.CONE_180
	telegraph_timer = 0.0
	telegraph_duration = 0.8
	telegraph_angle = current_facing_dir.angle()
	telegraph_range = 190.0
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	Global.play_sound("mutant_step", global_position)

func handle_ground_quake_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		execute_ground_quake_slam()

func execute_ground_quake_slam() -> void:
	current_state = State.GROUND_QUAKE_ATTACK
	state_timer = 0.4
	active_telegraph_type = TelegraphType.NONE
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	ground_quake_cooldown = 4.0
	
	# Visceral sound and camera trauma
	Global.play_sound("stomp_crash", global_position)
	Global.play_sound("boss_slam", global_position)
	
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(16.0, 0.45)
	elif player and player.has_method("add_trauma"):
		player.add_trauma(0.7)
	
	# Particle shockwave explosion
	spawn_ground_shockwave_fx()
	
	# Damage player within 180° cone (distance <= 190, dot >= -0.1)
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var to_player = player.global_position - global_position
		if to_player.length() <= 190.0:
			var dot = to_player.normalized().dot(current_facing_dir)
			if dot >= -0.15:
				player.take_damage(45.0, to_player.normalized())
	
	# Obliterate nearby player deployables (Barbwire, Turrets)
	destroy_nearby_deployables(190.0, current_facing_dir)

func handle_ground_quake_attack(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

func destroy_nearby_deployables(range_dist: float, facing: Vector2) -> void:
	var targets = get_tree().get_nodes_in_group("barbwire") + get_tree().get_nodes_in_group("turrets") + get_tree().get_nodes_in_group("deployables")
	for d in targets:
		if is_instance_valid(d) and "global_position" in d:
			var to_d = d.global_position - global_position
			if to_d.length() <= range_dist:
				if to_d.normalized().dot(facing) >= -0.2:
					if d.has_method("take_damage"):
						d.take_damage(999.0)
					elif d.has_method("destroy"):
						d.destroy()
					else:
						d.queue_free()

func spawn_ground_shockwave_fx() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	var wave = CPUParticles2D.new()
	wave.global_position = global_position
	wave.emitting = true
	wave.one_shot = true
	wave.explosiveness = 0.95
	wave.amount = 32
	wave.lifetime = 0.45
	wave.direction = current_facing_dir
	wave.spread = 90.0
	wave.initial_velocity_min = 160.0
	wave.initial_velocity_max = 340.0
	wave.scale_amount_min = 3.5
	wave.scale_amount_max = 7.0
	wave.color = Color(0.85, 0.2, 0.15, 0.9)
	wave.finished.connect(wave.queue_free)
	level.add_child(wave)

# -------------------------------------------------------------------------
# Phase 1: Crushing Sweep (Close Melee Cleave)
# -------------------------------------------------------------------------
func start_sweep_attack() -> void:
	current_state = State.SWEEP_WINDUP
	state_timer = 0.45
	velocity = Vector2.ZERO
	
	active_telegraph_type = TelegraphType.CIRCLE
	telegraph_timer = 0.0
	telegraph_duration = 0.45
	telegraph_range = 110.0
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	Global.play_sound("boss_cleave", global_position)

func handle_sweep_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		execute_sweep_attack()

func execute_sweep_attack() -> void:
	current_state = State.SWEEP_ATTACK
	state_timer = 0.3
	active_telegraph_type = TelegraphType.NONE
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	sweep_cooldown = 2.2
	Global.play_sound("dog_whoosh", global_position)
	
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var to_player = player.global_position - global_position
		if to_player.length() <= 115.0:
			player.take_damage(30.0, to_player.normalized())
			if "velocity" in player:
				player.velocity += to_player.normalized() * 550.0

func handle_sweep_attack(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

# -------------------------------------------------------------------------
# Phase 2: Unstoppable Charge & Bull Rush
# -------------------------------------------------------------------------
func start_charge_telegraph() -> void:
	current_state = State.CHARGE_TELEGRAPH
	state_timer = 0.6 # Pauses for 0.6s
	velocity = Vector2.ZERO
	
	if target_player and is_instance_valid(target_player):
		charge_dir = (target_player.global_position - global_position).normalized()
	else:
		charge_dir = current_facing_dir
	
	current_facing_dir = charge_dir
	update_sprite_facing(current_facing_dir)
	
	active_telegraph_type = TelegraphType.LINEAR_LANE
	telegraph_timer = 0.0
	telegraph_duration = 0.6
	telegraph_angle = charge_dir.angle()
	telegraph_range = 460.0
	telegraph_width = 75.0
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	Global.play_sound("mutant_roar", global_position)

func handle_charge_telegraph(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		execute_charge_rush()

func execute_charge_rush() -> void:
	current_state = State.CHARGE_RUSH
	charge_duration_timer = CHARGE_MAX_DURATION
	charge_cooldown = 7.5
	active_telegraph_type = TelegraphType.NONE
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	velocity = charge_dir * charge_speed

func handle_charge_rush(delta: float) -> void:
	charge_duration_timer -= delta
	velocity = charge_dir * charge_speed
	
	var col = move_and_collide(velocity * delta)
	
	# Check collision with player
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= 65.0:
			player.take_damage(50.0, charge_dir)
			if "velocity" in player:
				player.velocity += charge_dir * 700.0
			if player.has_method("trigger_shake"):
				player.trigger_shake(12.0, 0.3)
	
	# Wall collision / obstacle crash -> STUNNED
	if col != null:
		var collider = col.get_collider()
		if collider != player:
			on_charge_wall_impact()
			return
	
	if is_on_wall() or charge_duration_timer <= 0.0:
		on_charge_wall_impact()

func on_charge_wall_impact() -> void:
	current_state = State.CHARGE_STUNNED
	state_timer = 1.8 # Stunned for 1.8s
	velocity = Vector2.ZERO
	
	Global.play_sound("stomp_crash", global_position)
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(14.0, 0.4)
	
	# Wall debris dust
	var level = get_tree().current_scene
	if level:
		var dust = CPUParticles2D.new()
		dust.global_position = global_position
		dust.emitting = true
		dust.one_shot = true
		dust.amount = 25
		dust.lifetime = 0.5
		dust.spread = 180.0
		dust.initial_velocity_min = 100.0
		dust.initial_velocity_max = 260.0
		dust.scale_amount_min = 3.0
		dust.scale_amount_max = 6.5
		dust.color = Color(0.7, 0.65, 0.6)
		dust.finished.connect(dust.queue_free)
		level.add_child(dust)
	
	# Visual stun modulate flash
	if sprite:
		sprite.modulate = Color(1.8, 1.8, 0.6, 1.0)

func handle_charge_stunned(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		if sprite:
			sprite.modulate = Color.WHITE
		current_state = State.CHASE

# -------------------------------------------------------------------------
# Phase 2: Debris Hurl (Throws 3 Spread Concrete Projectiles)
# -------------------------------------------------------------------------
func start_debris_hurl() -> void:
	current_state = State.DEBRIS_WINDUP
	state_timer = 0.55
	velocity = Vector2.ZERO
	debris_cooldown = 5.0
	
	if target_player and is_instance_valid(target_player):
		current_facing_dir = (target_player.global_position - global_position).normalized()
	update_sprite_facing(current_facing_dir)
	
	Global.play_sound("rock_impact", global_position)

func handle_debris_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		execute_debris_throw()

func execute_debris_throw() -> void:
	current_state = State.DEBRIS_THROW
	state_timer = 0.25
	
	var base_angle = current_facing_dir.angle()
	var spread_angles = [-deg_to_rad(20.0), 0.0, deg_to_rad(20.0)]
	
	var level = get_tree().current_scene
	if level:
		for angle_offset in spread_angles:
			var dir = Vector2.from_angle(base_angle + angle_offset)
			var rock = BOULDER_SCENE.instantiate()
			rock.global_position = global_position + dir * 35.0
			level.add_child(rock)
			if rock.has_method("launch"):
				rock.launch(global_position + dir * 35.0, dir, 420.0, 25.0)
	
	Global.play_sound("boss_cleave", global_position)

func handle_debris_throw(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

# -------------------------------------------------------------------------
# Phase 3: Core Meltdown & Horde Rally
# -------------------------------------------------------------------------
func trigger_phase_3_transition() -> void:
	current_phase = Phase.PHASE_3
	current_state = State.ROAR_RALLY
	state_timer = 1.2
	velocity = Vector2.ZERO
	
	boss_phase_changed.emit(3)
	
	# Expose illuminated crimson weak-point cyst on back
	if weak_point_light:
		weak_point_light.enabled = true
		weak_point_light.color = Color(1.0, 0.1, 0.2, 1.0)
		weak_point_light.energy = 2.0
	
	# Activate toxic radiation particles
	if radiation_particles:
		radiation_particles.emitting = true
	
	# Roar shockwave & trauma
	Global.play_sound("boss_roar", global_position)
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(18.0, 0.6)
	
	summon_perimeter_reinforcements()

func handle_roar_rally(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.CHASE

func summon_perimeter_reinforcements() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	Global.play_sound("screamer", global_position)
	
	# Summon 2-3 fast runners or infected dogs around perimeter
	var dog_scene = preload("res://scenes/InfectedDog.tscn")
	var zombie_scene = preload("res://scenes/Zombie.tscn")
	
	for i in range(3):
		var angle = randf() * TAU
		var offset = Vector2.from_angle(angle) * randf_range(220.0, 320.0)
		var spawn_pos = global_position + offset
		
		var minion = dog_scene.instantiate() if (i % 2 == 0) else zombie_scene.instantiate()
		minion.global_position = spawn_pos
		level.call_deferred("add_child", minion)

func handle_radiation_aura(delta: float) -> void:
	radiation_tick_timer -= delta
	if radiation_tick_timer <= 0.0:
		radiation_tick_timer = 0.8
		var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player) and player.has_method("take_damage"):
			if global_position.distance_to(player.global_position) <= 80.0:
				player.take_damage(4.0, Vector2.ZERO)
				Global.play_sound("radiation_tick", global_position)

# -------------------------------------------------------------------------
# Damage & Weakpoint System
# -------------------------------------------------------------------------
func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD or current_health <= 0.0:
		return
	
	var effective_damage = amount
	var is_crit: bool = false
	
	# Phase 3 Weak-Point Cyst: deals 2.5x critical damage when shot from behind
	if current_phase == Phase.PHASE_3 and hit_direction != Vector2.ZERO:
		var dot = hit_direction.normalized().dot(current_facing_dir)
		if dot > 0.3:
			is_crit = true
			effective_damage *= 2.5
			spawn_weakpoint_crit_fx()
	
	current_health -= effective_damage
	boss_health_changed.emit(current_health, max_health)
	
	if Global.has_signal("enemy_hit"):
		Global.enemy_hit.emit(self, effective_damage, is_crit, current_health <= 0.0, hit_direction)
	
	# White flash feedback
	if sprite:
		sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	
	# Check Phase Transitions
	if current_phase == Phase.PHASE_1 and current_health <= (max_health * 0.65):
		current_phase = Phase.PHASE_2
		boss_phase_changed.emit(2)
		Global.play_sound("mutant_roar", global_position)
	elif current_phase == Phase.PHASE_2 and current_health <= (max_health * 0.25):
		trigger_phase_3_transition()
	
	if current_health <= 0.0:
		die()

func spawn_weakpoint_crit_fx() -> void:
	Global.play_sound("kill_bone_crack", global_position)
	var level = get_tree().current_scene
	if level:
		var burst = CPUParticles2D.new()
		burst.global_position = global_position - current_facing_dir * 25.0
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 18
		burst.lifetime = 0.35
		burst.spread = 180.0
		burst.initial_velocity_min = 120.0
		burst.initial_velocity_max = 280.0
		burst.scale_amount_min = 2.5
		burst.scale_amount_max = 5.0
		burst.color = Color(1.0, 0.1, 0.2, 1.0)
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)

# -------------------------------------------------------------------------
# Death Sequence & Extraction Trigger
# -------------------------------------------------------------------------
func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	current_health = 0.0
	velocity = Vector2.ZERO
	active_telegraph_type = TelegraphType.NONE
	if telegraph_drawer:
		telegraph_drawer.queue_redraw()
	
	boss_health_changed.emit(0.0, max_health)
	boss_defeated_signal.emit()
	if Global.has_signal("boss_defeated"):
		Global.boss_defeated.emit(self)
	
	# Slow-motion micro-freeze: Engine.time_scale = 0.2 for 0.5s
	Engine.time_scale = 0.2
	var timer = get_tree().create_timer(0.5 * 0.2, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)
	
	# Boss collapse audio & camera rumble
	Global.play_sound("kill_bone_crack", global_position)
	Global.play_sound("stomp_crash", global_position)
	var player = target_player if is_instance_valid(target_player) else get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(22.0, 0.7)
	
	# Loot Cascade
	trigger_loot_cascade()
	
	# Extraction Waypoint Beacon Alert
	Global.show_notification(
		"CONTAINMENT RESTORED",
		"EVACUATION CHOPPER READY • Proceed to extraction beacon",
		Color(0.3, 1.0, 0.45)
	)
	
	# Fade out & destroy
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 2.0).set_delay(0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func trigger_loot_cascade() -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	# 1. Drops 150 Scrap currency
	if EconomyManager and EconomyManager.has_method("spawn_scrap"):
		EconomyManager.spawn_scrap(global_position, 150)
	
	# 2. Bulk ammo crates and guaranteed medical packs
	for i in range(4):
		var offset = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)
		var p_type = 0 if (i % 2 == 0) else 1 # 0: Health, 1: Ammo
		var pickup = PICKUP_SCENE.instantiate()
		pickup.global_position = global_position + offset
		pickup.pickup_type = p_type
		level.call_deferred("add_child", pickup)

# -------------------------------------------------------------------------
# Facing & Sprite Orientation
# -------------------------------------------------------------------------
func update_sprite_facing(face_dir: Vector2) -> void:
	if sprite == null:
		return
	var angle = face_dir.angle()
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	sprite.frame = dir_idx % 8
