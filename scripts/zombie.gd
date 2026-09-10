extends CharacterBody2D
class_name Zombie

const BLOOD_SPLAT_SCRIPT = preload("res://scripts/blood_splat.gd")

enum ZombieType { REGULAR, INFECTED_DOG, HEAVY, SPITTER, ARMORED, COLOSSUS, SCREAMER }
enum MutationAffix { NONE, VOLATILE, ARMORED, FRENZIED }

@export var zombie_type: ZombieType = ZombieType.REGULAR
@export var mutation_affix: MutationAffix = MutationAffix.NONE
@export var wave_number: int = 1
@export var max_health: float = 70.0
@export var speed: float = 125.0
@export var attack_damage: float = 6.0
@export var attack_range: float = 38.0
@export var attack_cooldown: float = 0.9
@export var score_value: int = 100

var current_health: float = 70.0
var attack_timer: float = 0.0
var hit_flash_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var current_facing_dir: Vector2 = Vector2.DOWN
var is_alpha_target: bool = false
var has_exploded: bool = false
var base_modulate: Color = Color.WHITE

var volatile_aura: PointLight2D = null
var frenzied_trail: CPUParticles2D = null
var alpha_marker: Node2D = null

# Status Effects
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var burning_timer: float = 0.0
var burning_dps: float = 0.0
var burning_tick_timer: float = 0.0
var enrage_timer: float = 0.0
var stagger_timer: float = 0.0
var screamer_cooldown_timer: float = 4.0
var bleeding_timer: float = 0.0
var bleeding_dps: float = 0.0
var bleeding_tick_timer: float = 0.0

var nav_refresh_timer: float = 0.0
var is_hibernating: bool = false
const HIBERNATION_DISTANCE: float = 1400.0

var player: Node2D = null

# Procedural Walk Animation State
var walk_cycle_time: float = 0.0
var sprite_base_offset: Vector2 = Vector2.ZERO
var is_moving: bool = false
var anim_bob_height: float = 3.5        # Vertical bounce amplitude (px)
var anim_bob_frequency: float = 8.0     # Steps per second
var anim_lean_max: float = 0.06         # Max rotation lean (radians)
var anim_squash_intensity: float = 0.04 # Squash-stretch scale variation
var anim_idle_breathe: float = 0.015    # Idle breathing scale pulse
var anim_gallop_asymmetry: float = 0.0  # >0 for dog gallop (asymmetric bob)
var death_anim_progress: float = -1.0   # -1 = not dying, 0..1 = death anim

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemies")
	configure_type()
	
	# Elite Zombie Mutation Affixes (Wave 4+): 18% chance for regular walkers and dogs
	if wave_number >= 4 and mutation_affix == MutationAffix.NONE and not is_alpha_target:
		if zombie_type == ZombieType.REGULAR or zombie_type == ZombieType.INFECTED_DOG:
			if randf() < 0.18:
				var rolled = [MutationAffix.VOLATILE, MutationAffix.ARMORED, MutationAffix.FRENZIED].pick_random()
				apply_mutation_affix(rolled)
	elif mutation_affix != MutationAffix.NONE:
		apply_mutation_affix(mutation_affix)
	
	current_health = max_health
	nav_refresh_timer = randf_range(0.0, 0.2)
	
	# Hit-Flash shader material
	if sprite:
		var flash_mat = ShaderMaterial.new()
		flash_mat.shader = preload("res://shaders/hit_flash.gdshader")
		sprite.material = flash_mat
	
	# Bottom-offset black elliptical drop shadow quad (modulate.a = 0.45)
	var shadow_scale = Vector2(0.85, 0.42)
	if zombie_type == ZombieType.HEAVY:
		shadow_scale = Vector2(1.2, 0.58)
	elif zombie_type == ZombieType.ARMORED:
		shadow_scale = Vector2(1.05, 0.5)
	elif zombie_type == ZombieType.COLOSSUS:
		shadow_scale = Vector2(1.8, 0.85)
	elif zombie_type == ZombieType.INFECTED_DOG:
		shadow_scale = Vector2(0.75, 0.35)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 14), shadow_scale)
	
	# Cache sprite resting offset and randomize walk cycle phase so zombies don't bob in sync
	if sprite:
		sprite_base_offset = sprite.offset
	walk_cycle_time = randf() * TAU
	
	_setup_network_synchronizer()
	call_deferred("_find_player")

func _setup_network_synchronizer() -> void:
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync == null:
		sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		add_child(sync)
	
	sync.replication_interval = 0.033 # 30 Hz tick rate
	sync.delta_interval = 0.033
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:velocity"))
	config.property_set_replication_mode(NodePath(".:velocity"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath("Sprite2D:frame"))
	config.property_set_replication_mode(NodePath("Sprite2D:frame"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(".:current_health"))
	config.property_set_replication_mode(NodePath(".:current_health"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config

var target_recheck_timer: float = 0.0

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var closest: Node2D = null
	var min_dist: float = INF
	for p in players:
		if is_instance_valid(p) and p is Node2D:
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	player = closest
func configure_type() -> void:
	var base_scale: float = 1.0
	
	match zombie_type:
		ZombieType.REGULAR:
			max_health = 70.0
			speed = 125.0
			attack_damage = 6.0
			attack_range = 38.0
			attack_cooldown = 0.95
			score_value = 100
			base_scale = 1.0
			if sprite:
				# 4 Distinct 3D Model Clothing Variations (Garwalfs Release 14 & Variants)
				var walker_skins = [
					{"tex": "res://assets/textures/characters/zombie_regular_8dir.png", "norm": "res://assets/textures/characters/zombie_regular_8dir_n.png"},
					{"tex": "res://assets/textures/characters/zombie_regular_green_8dir.png", "norm": "res://assets/textures/characters/zombie_regular_green_8dir_n.png"},
					{"tex": "res://assets/textures/characters/zombie_regular_blue_8dir.png", "norm": "res://assets/textures/characters/zombie_regular_blue_8dir_n.png"},
					{"tex": "res://assets/textures/characters/zombie_regular_brown_8dir.png", "norm": "res://assets/textures/characters/zombie_regular_brown_8dir_n.png"},
				]
				var skin = walker_skins.pick_random()
				var c_tex = CanvasTexture.new()
				c_tex.diffuse_texture = load(skin["tex"])
				c_tex.normal_texture = load(skin["norm"])
				sprite.texture = c_tex
				sprite.hframes = 8
		
		ZombieType.INFECTED_DOG:
			max_health = 40.0
			speed = 235.0
			attack_damage = 4.0
			attack_range = 40.0
			attack_cooldown = 0.65
			score_value = 140
			base_scale = 0.95
			if sprite:
				# Resident Evil Cerberus 3D Model Render
				var c_tex = CanvasTexture.new()
				c_tex.diffuse_texture = load("res://assets/textures/characters/zombie_dog_8dir.png")
				c_tex.normal_texture = load("res://assets/textures/characters/zombie_dog_8dir_n.png")
				sprite.texture = c_tex
				sprite.hframes = 8
		
		ZombieType.HEAVY:
			max_health = 250.0
			speed = 70.0
			attack_damage = 14.0
			attack_range = 50.0
			attack_cooldown = 1.3
			score_value = 280
			base_scale = 1.35
			if sprite:
				# Garwalfs Fur-Collar Brute 3D Model Render
				var c_tex = CanvasTexture.new()
				c_tex.diffuse_texture = load("res://assets/textures/characters/zombie_heavy_8dir.png")
				c_tex.normal_texture = load("res://assets/textures/characters/zombie_heavy_8dir_n.png")
				sprite.texture = c_tex
				sprite.hframes = 8
		
		ZombieType.SPITTER:
			max_health = 90.0
			speed = 145.0
			attack_damage = 6.0
			attack_range = 44.0
			attack_cooldown = 0.85
			score_value = 180
			base_scale = 1.05
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_spitter_8dir.png")
				sprite.hframes = 8
		
		ZombieType.ARMORED:
			max_health = 180.0
			speed = 105.0
			attack_damage = 8.5
			attack_range = 40.0
			attack_cooldown = 1.0
			score_value = 250
			base_scale = 1.12
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_armored_8dir.png")
				sprite.hframes = 8
		
		ZombieType.COLOSSUS:
			max_health = 750.0
			speed = 52.0
			attack_damage = 22.0
			attack_range = 65.0
			attack_cooldown = 1.6
			score_value = 850
			base_scale = 1.75
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_colossus_8dir.png")
				sprite.hframes = 8
		
		ZombieType.SCREAMER:
			max_health = 110.0
			speed = 135.0
			attack_damage = 5.0
			attack_range = 36.0
			attack_cooldown = 1.0
			score_value = 220
			base_scale = 1.05
			if sprite:
				sprite.texture = load("res://assets/textures/characters/zombie_screamer_8dir.png")
				sprite.hframes = 8
	
	# Progressive growth in size as waves and time pass
	var wave_growth = 1.0 + min((wave_number - 1) * 0.045, 0.40)
	var final_scale = base_scale * wave_growth
	scale = Vector2(final_scale, final_scale)
	
	# Per-type procedural walk animation parameters
	match zombie_type:
		ZombieType.REGULAR:
			# Shambling, uneven zombie walk
			anim_bob_height = 3.2
			anim_bob_frequency = 7.5
			anim_lean_max = 0.07
			anim_squash_intensity = 0.04
			anim_gallop_asymmetry = 0.0
		ZombieType.INFECTED_DOG:
			# Fast quadruped gallop with pronounced vertical bounce
			anim_bob_height = 4.5
			anim_bob_frequency = 14.0
			anim_lean_max = 0.10
			anim_squash_intensity = 0.08
			anim_gallop_asymmetry = 0.35  # Asymmetric gallop cycle
		ZombieType.HEAVY:
			# Slow, heavy lumbering steps with ground-shaking weight
			anim_bob_height = 2.5
			anim_bob_frequency = 4.5
			anim_lean_max = 0.04
			anim_squash_intensity = 0.06
			anim_gallop_asymmetry = 0.0
		ZombieType.SPITTER:
			# Twitchy, hunched movement
			anim_bob_height = 2.8
			anim_bob_frequency = 9.0
			anim_lean_max = 0.08
			anim_squash_intensity = 0.035
			anim_gallop_asymmetry = 0.0
		ZombieType.ARMORED:
			# Stiff, mechanical march
			anim_bob_height = 2.0
			anim_bob_frequency = 6.0
			anim_lean_max = 0.03
			anim_squash_intensity = 0.025
			anim_gallop_asymmetry = 0.0
		ZombieType.COLOSSUS:
			# Massive, earth-shaking strides
			anim_bob_height = 4.0
			anim_bob_frequency = 3.0
			anim_lean_max = 0.035
			anim_squash_intensity = 0.07
			anim_gallop_asymmetry = 0.0
		ZombieType.SCREAMER:
			# Nervous, jittery movement
			anim_bob_height = 3.0
			anim_bob_frequency = 10.0
			anim_lean_max = 0.09
			anim_squash_intensity = 0.05
			anim_gallop_asymmetry = 0.0

func ignite(duration: float, dps: float) -> void:
	burning_timer = max(burning_timer, duration)
	burning_dps = max(burning_dps, dps)

func apply_bleed(duration: float = 2.0, dps: float = 22.0) -> void:
	bleeding_timer = max(bleeding_timer, duration)
	bleeding_dps = max(bleeding_dps, dps)

func enrage(duration: float) -> void:
	enrage_timer = max(enrage_timer, duration)

func stagger(duration: float) -> void:
	stagger_timer = max(stagger_timer, duration)

func _physics_process(delta: float) -> void:
	if current_health <= 0.0:
		# Still run death fall animation if active
		if death_anim_progress >= 0.0:
			_animate_walk_cycle(delta)
		return
	
	# Host CPU Ownership: All pathfinding, state machines, and damage evaluations run strictly on the host
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		if hit_flash_timer > 0.0:
			hit_flash_timer -= delta
			if hit_flash_timer <= 0.0 and sprite:
				sprite.modulate = base_modulate
		if knockback_velocity.length_squared() > 1.0:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_animate_walk_cycle(delta)  # Clients still need visual walk animation
		return
	
	target_recheck_timer -= delta
	if target_recheck_timer <= 0.0:
		target_recheck_timer = 0.6
		_find_player()
	
	if player == null or not is_instance_valid(player):
		_find_player()
		return
	
	# Handle Stagger (e.g. from shotgun blast, explosive, or screaming)
	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return
	
	# Handle Slow status
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	
	# Handle Burning DOT
	if burning_timer > 0.0:
		burning_timer -= delta
		burning_tick_timer -= delta
		if burning_tick_timer <= 0.0:
			burning_tick_timer = 0.25
			take_damage(burning_dps * 0.25, Vector2.ZERO)
		
		# Visual flame flicker
		if sprite and hit_flash_timer <= 0.0:
			sprite.modulate = Color(1.8, 0.7 + sin(burning_timer * 25.0) * 0.25, 0.25, 1.0)
	
	# Handle Bleeding DOT (Hollow-Point Rounds)
	if bleeding_timer > 0.0:
		bleeding_timer -= delta
		bleeding_tick_timer -= delta
		if bleeding_tick_timer <= 0.0:
			bleeding_tick_timer = 0.40
			take_damage(bleeding_dps * 0.40, Vector2.ZERO)
		
		if sprite and hit_flash_timer <= 0.0 and burning_timer <= 0.0 and enrage_timer <= 0.0:
			sprite.modulate = Color(1.35, 0.4, 0.4, 1.0)
	
	# Handle Enrage status
	if enrage_timer > 0.0:
		enrage_timer -= delta
		if sprite and hit_flash_timer <= 0.0 and burning_timer <= 0.0:
			sprite.modulate = Color(1.35, 0.45, 0.45, 1.0) # Crimson enraged tint
	
	if attack_timer > 0.0:
		attack_timer -= delta
	
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("flash_amount", 0.0)
			if sprite and burning_timer <= 0.0 and enrage_timer <= 0.0 and bleeding_timer <= 0.0:
				sprite.modulate = base_modulate
	elif burning_timer <= 0.0 and enrage_timer <= 0.0 and bleeding_timer <= 0.0:
		if sprite:
			sprite.modulate = base_modulate
	
	# Apply knockback decay
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	
	var target_pos = player.global_position
	var dist_to_player = global_position.distance_to(target_pos)
	
	# Volatile Mutator proximity detonation (within 40px of player)
	if mutation_affix == MutationAffix.VOLATILE and not has_exploded and current_health > 0.0:
		if dist_to_player <= 40.0:
			explode_volatile()
			return
	
	# Alpha Target floating marker animation
	if is_alpha_target and alpha_marker:
		alpha_marker.position.y = -44.0 + sin(Time.get_ticks_msec() * 0.008) * 4.0
	
	# Distance-Based Hibernation (Off-Screen Culling)
	if dist_to_player > HIBERNATION_DISTANCE:
		if not is_hibernating:
			is_hibernating = true
			if collision_shape:
				collision_shape.disabled = true
			if sprite:
				sprite.visible = false
		# Lightweight linear vector update, skipping expensive nav/animation
		velocity = (target_pos - global_position).normalized() * (speed * 0.75)
		global_position += velocity * delta
		return
	elif is_hibernating:
		is_hibernating = false
		if collision_shape:
			collision_shape.disabled = false
		if sprite:
			sprite.visible = true
	
	# 8-Directional 2.5D Isometric orientation
	var face_dir = (target_pos - global_position).normalized()
	update_facing(face_dir)
	
	# Screamer special behavior: Maintain 280-350px distance and emit shockwave every 8s
	if zombie_type == ZombieType.SCREAMER:
		screamer_cooldown_timer -= delta
		if screamer_cooldown_timer <= 0.0:
			screamer_cooldown_timer = 8.0
			screech_and_buff()
	
	# Staggered navigation path updates (every ~0.2s instead of every frame)
	nav_refresh_timer -= delta
	if nav_refresh_timer <= 0.0:
		nav_refresh_timer = 0.2 + randf_range(-0.05, 0.05)
		if nav_agent and is_instance_valid(player):
			nav_agent.target_position = target_pos
	
	var move_dir: Vector2 = Vector2.ZERO
	if zombie_type == ZombieType.SCREAMER:
		if dist_to_player < 260.0:
			# Retreat from player
			move_dir = -(target_pos - global_position).normalized()
		elif dist_to_player > 360.0:
			move_dir = (target_pos - global_position).normalized()
		else:
			# Circle / hover at range
			move_dir = Vector2(-face_dir.y, face_dir.x) * 0.4
	else:
		# Pathfinding using NavigationAgent2D with direct fallback
		if nav_agent and not nav_agent.is_navigation_finished():
			var next_path_pos = nav_agent.get_next_path_position()
			move_dir = (next_path_pos - global_position).normalized()
		
		# Fallback if navigation path is not ready or blocked
		if move_dir == Vector2.ZERO or nav_agent.is_target_reached():
			move_dir = (target_pos - global_position).normalized()
	
	var current_speed = speed * slow_factor * (1.30 if enrage_timer > 0.0 else 1.0)
	
	if dist_to_player > (attack_range * 0.75):
		velocity = (move_dir * current_speed) + knockback_velocity
	else:
		velocity = knockback_velocity
		if attack_timer <= 0.0 and dist_to_player <= attack_range:
			perform_attack()
	
	move_and_slide()
	
	# Procedural walk / idle animation
	_animate_walk_cycle(delta)

func screech_and_buff() -> void:
	stagger(0.65)
	Global.play_sound("screamer")
	
	var level = get_tree().current_scene
	if level:
		# Shockwave ring
		var wave = CPUParticles2D.new()
		wave.emitting = true
		wave.one_shot = true
		wave.explosiveness = 0.95
		wave.amount = 30
		wave.lifetime = 0.55
		wave.spread = 180.0
		wave.initial_velocity_min = 180.0
		wave.initial_velocity_max = 360.0
		wave.scale_amount_min = 3.0
		wave.scale_amount_max = 6.0
		wave.color = Color(1.0, 0.2, 0.2, 0.85)
		wave.global_position = global_position
		wave.finished.connect(wave.queue_free)
		level.add_child(wave)
	
	# Buff nearby allies within 360px with +30% speed and red rage
	var allies = get_tree().get_nodes_in_group("enemies")
	for ally in allies:
		if is_instance_valid(ally) and ally != self:
			if global_position.distance_to(ally.global_position) <= 360.0:
				if ally.has_method("enrage"):
					ally.enrage(6.0)

func update_facing(face_dir: Vector2) -> void:
	current_facing_dir = face_dir
	var angle = face_dir.angle()
	var dir_idx = int(round(angle / (PI / 4.0)))
	if dir_idx < 0:
		dir_idx += 8
	if sprite:
		sprite.frame = dir_idx % 8

func _animate_walk_cycle(delta: float) -> void:
	if not sprite:
		return
	
	# Death fall animation
	if death_anim_progress >= 0.0:
		death_anim_progress = min(death_anim_progress + delta * 3.5, 1.0)
		var t = death_anim_progress
		var ease_t = 1.0 - pow(1.0 - t, 3.0)  # Ease-out cubic
		sprite.rotation = lerp(0.0, PI * 0.45, ease_t) * sign(current_facing_dir.x + 0.001)
		sprite.offset = sprite_base_offset + Vector2(0, ease_t * 8.0)
		sprite.scale = Vector2(
			lerp(1.0, 0.92, ease_t),
			lerp(1.0, 0.85, ease_t)
		)
		modulate.a = lerp(1.0, 0.6, ease_t)
		return
	
	var spd = velocity.length()
	is_moving = spd > 15.0
	
	if is_moving:
		# Advance walk cycle based on actual movement speed
		var speed_ratio = clamp(spd / max(speed, 1.0), 0.3, 1.8)
		walk_cycle_time += delta * anim_bob_frequency * speed_ratio
		
		# --- Vertical Bob (footstep simulation) ---
		var bob_wave: float
		if anim_gallop_asymmetry > 0.0:
			# Quadruped gallop: front legs hit, brief air, back legs hit
			var phase = fmod(walk_cycle_time, TAU)
			bob_wave = abs(sin(phase)) + anim_gallop_asymmetry * sin(phase * 2.0)
			bob_wave = bob_wave * 0.7  # Normalize
		else:
			# Bipedal walk: simple sinusoidal step cycle
			bob_wave = abs(sin(walk_cycle_time))
		
		var bob_offset = -bob_wave * anim_bob_height * speed_ratio
		sprite.offset = sprite_base_offset + Vector2(0, bob_offset)
		
		# --- Lean (rotation toward movement direction) ---
		var lean_target = current_facing_dir.x * anim_lean_max * speed_ratio
		sprite.rotation = lerp(sprite.rotation, lean_target, delta * 12.0)
		
		# --- Squash & Stretch ---
		# On "landing" (bob at peak), squash horizontally and stretch vertically
		# On "lift" (bob at trough), stretch horizontally and compress vertically
		var squash_phase = cos(walk_cycle_time * 2.0)  # Double frequency for step
		var sx = 1.0 + squash_phase * anim_squash_intensity * speed_ratio
		var sy = 1.0 - squash_phase * anim_squash_intensity * speed_ratio * 0.7
		sprite.scale = Vector2(sx, sy)
		
	else:
		# --- Idle Breathing ---
		walk_cycle_time += delta * 2.0  # Slow idle pulse
		var breathe = sin(walk_cycle_time) * anim_idle_breathe
		sprite.scale = Vector2(1.0 + breathe, 1.0 - breathe * 0.5)
		
		# Smoothly return to neutral
		sprite.offset = sprite.offset.lerp(sprite_base_offset, delta * 8.0)
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 6.0)

func perform_attack() -> void:
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var push_dir = (player.global_position - global_position).normalized()
		if NetworkManager.is_network_active() and player.has_method("net_take_damage"):
			player.net_take_damage.rpc(attack_damage, push_dir)
		else:
			player.take_damage(attack_damage, push_dir)
		attack_timer = attack_cooldown
		Global.play_sound("zombie_groan")
		
		# Boss screen shake on impact
		if zombie_type == ZombieType.COLOSSUS and player.has_method("trigger_shake"):
			player.trigger_shake(8.0, 0.25)

@rpc("any_peer", "call_remote", "reliable")
func request_damage(amount: float, hit_direction: Vector2) -> void:
	if multiplayer.is_server():
		take_damage(amount, hit_direction)

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0.0:
		return
	
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		request_damage.rpc_id(1, amount, hit_direction)
		return
	
	var effective_damage = amount
	var remaining_before = current_health
	var is_shield_deflected: bool = false
	
	# Armored Riot Zombie frontal riot shield deflecting 80% direct bullet damage
	if zombie_type == ZombieType.ARMORED:
		if hit_direction != Vector2.ZERO:
			# hit_direction points along bullet trajectory.
			# If bullet is hitting frontal shield, it travels opposite to zombie's facing direction.
			if hit_direction.normalized().dot(current_facing_dir) < -0.2:
				effective_damage = amount * 0.20 # 80% deflected!
				spawn_shield_ricochet(hit_direction)
				is_shield_deflected = true
				# Stagger if hit by heavy blast (e.g. shotgun or explosive)
				if amount >= 35.0:
					stagger(0.45)
		else:
			effective_damage = amount * 0.50
	
	# Armored Plating Elite Mutator: immune to light-caliber, takes 70% reduced damage from front
	if mutation_affix == MutationAffix.ARMORED:
		if hit_direction != Vector2.ZERO:
			if hit_direction.normalized().dot(current_facing_dir) < -0.15:
				effective_damage = amount * 0.30 # 70% deflected from front!
				spawn_shield_ricochet(hit_direction)
				is_shield_deflected = true
				if amount >= 40.0:
					stagger(0.40)
		else:
			effective_damage = amount * 0.60
	
	current_health -= effective_damage
	
	# Active white flash shader across sprite for 0.06s
	hit_flash_timer = 0.06
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("flash_amount", 1.0)
	elif sprite:
		sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	
	# Physical directional knockback scaled inversely to enemy max HP
	var weapon_stagger_force = 2400.0
	var knockback_scale = clampf(weapon_stagger_force / max_health, 15.0, 190.0)
	if hit_direction != Vector2.ZERO:
		knockback_velocity += hit_direction.normalized() * knockback_scale
	
	var is_crit = (hit_direction != Vector2.ZERO and (randf() < 0.18 or amount >= 45.0))
	var is_fatal = (current_health <= 0.0)
	
	# Ballistic flesh impact or armor deflection sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_bullet_impact"):
		audio_mgr.play_bullet_impact(is_shield_deflected, global_position, is_crit)
	else:
		Global.play_sound("hit")
	
	# Hollow-Point Rounds: apply 2-second bleeding damage-over-time status
	if Global.mod_hollow_point and not is_fatal and hit_direction != Vector2.ZERO:
		apply_bleed(2.0, 20.0)
	
	if Global.has_signal("enemy_hit"):
		Global.enemy_hit.emit(self, effective_damage, is_crit, is_fatal, hit_direction)
	
	if current_health <= 0.0:
		var overkill_amount = effective_damage - remaining_before
		var is_overkill = (overkill_amount >= 25.0 or amount >= 55.0)
		die(hit_direction, is_overkill)

func spawn_shield_ricochet(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if level:
		var sparks = CPUParticles2D.new()
		sparks.emitting = true
		sparks.one_shot = true
		sparks.explosiveness = 0.95
		sparks.amount = 8
		sparks.lifetime = 0.2
		sparks.direction = -hit_dir
		sparks.spread = 50.0
		sparks.initial_velocity_min = 100.0
		sparks.initial_velocity_max = 220.0
		sparks.scale_amount_min = 1.5
		sparks.scale_amount_max = 3.0
		sparks.color = Color(1.0, 0.9, 0.35)
		sparks.global_position = global_position
		sparks.finished.connect(sparks.queue_free)
		level.add_child(sparks)

func die(hit_direction: Vector2, is_overkill: bool = false) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		net_die.rpc(hit_direction, is_overkill)
	else:
		_execute_die(hit_direction, is_overkill)

@rpc("call_local", "reliable")
func net_die(hit_direction: Vector2, is_overkill: bool = false) -> void:
	_execute_die(hit_direction, is_overkill)

func _execute_die(hit_direction: Vector2, is_overkill: bool = false) -> void:
	Global.add_kill(score_value)
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_zombie_death"):
		audio_mgr.play_zombie_death(global_position)
	else:
		Global.play_sound("zombie_death")
	
	if is_alpha_target:
		var horde_dir = get_tree().get_first_node_in_group("horde_director")
		if horde_dir and horde_dir.has_method("on_alpha_target_killed"):
			horde_dir.on_alpha_target_killed(self)
	
	if mutation_affix == MutationAffix.VOLATILE and not has_exploded:
		explode_volatile()
		return
	
	if is_overkill:
		spawn_overkill_gibs(hit_direction)
	else:
		spawn_blood_splat(hit_direction)
	
	# Toxic Bloater / Acid Spitter leaves a 6-second glowing green acid pool
	if zombie_type == ZombieType.SPITTER:
		var acid_scene = preload("res://scenes/AcidPool.tscn")
		var pool = acid_scene.instantiate()
		pool.global_position = global_position
		var level = get_tree().current_scene
		if level:
			level.call_deferred("add_child", pool)
		elif get_parent():
			get_parent().call_deferred("add_child", pool)
	
	# Micro-Hitstop freeze frame when killing a heavy zombie or boss
	if zombie_type in [ZombieType.HEAVY, ZombieType.ARMORED, ZombieType.COLOSSUS] or is_alpha_target:
		Global.trigger_hitstop(0.04, 0.05)
	
	if zombie_type == ZombieType.COLOSSUS:
		Global.boss_defeated.emit(self)
		Global.explosion_occurred.emit()
		if player and player.has_method("trigger_shake"):
			player.trigger_shake(14.0, 0.4)
		spawn_pickup(0)
		spawn_pickup(1)
	else:
		roll_loot()
	
	spawn_scrap_drop()
	
	# Start death fall animation and delay queue_free
	death_anim_progress = 0.0
	current_health = 0.0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if not NetworkManager.is_network_active() or multiplayer.is_server():
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(self):
				queue_free()
		)

func apply_slow(factor: float, duration: float) -> void:
	# Frenzied bloodhounds are immune to barbwire slow effects
	if mutation_affix == MutationAffix.FRENZIED:
		return
	slow_factor = min(slow_factor, factor)
	slow_timer = max(slow_timer, duration)

func apply_mutation_affix(affix: MutationAffix) -> void:
	mutation_affix = affix
	if affix == MutationAffix.NONE:
		return
	
	add_to_group("elite_mutator")
	add_to_group("elites")
	
	# +100% HP
	max_health *= 2.0
	current_health = max_health
	scale *= 1.15
	
	match affix:
		MutationAffix.VOLATILE:
			scale *= 1.10 # Swollen
			base_modulate = Color(0.45, 1.85, 0.5, 1.0)
			if sprite:
				sprite.modulate = base_modulate
			
			if volatile_aura == null:
				volatile_aura = PointLight2D.new()
				volatile_aura.name = "VolatileAura"
				volatile_aura.color = Color(0.2, 1.0, 0.35, 1.0)
				volatile_aura.energy = 0.95
				volatile_aura.texture = preload("res://assets/textures/lighting/point_light_cookie.png")
				volatile_aura.texture_scale = 0.85
				add_child(volatile_aura)
			
			var spores = CPUParticles2D.new()
			spores.name = "ToxicSpores"
			spores.amount = 10
			spores.lifetime = 0.75
			spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			spores.emission_sphere_radius = 20.0
			spores.gravity = Vector2(0, -22)
			spores.scale_amount_min = 2.0
			spores.scale_amount_max = 4.5
			spores.color = Color(0.25, 0.95, 0.35, 0.65)
			add_child(spores)
		
		MutationAffix.ARMORED:
			base_modulate = Color(0.85, 0.92, 1.12, 1.0)
			if sprite:
				sprite.modulate = base_modulate
			
			var plate = Sprite2D.new()
			plate.name = "ScrapPlate"
			plate.texture = preload("res://assets/textures/props/scrap_cog.png")
			plate.scale = Vector2(0.55, 0.55)
			plate.position = Vector2(0, 4)
			plate.modulate = Color(0.9, 0.92, 0.98, 0.9)
			add_child(plate)
		
		MutationAffix.FRENZIED:
			speed *= 1.40
			base_modulate = Color(1.85, 0.4, 0.4, 1.0)
			if sprite:
				sprite.modulate = base_modulate
			
			if frenzied_trail == null:
				frenzied_trail = CPUParticles2D.new()
				frenzied_trail.name = "FrenziedTrail"
				frenzied_trail.amount = 14
				frenzied_trail.lifetime = 0.45
				frenzied_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				frenzied_trail.emission_sphere_radius = 12.0
				frenzied_trail.gravity = Vector2.ZERO
				frenzied_trail.initial_velocity_min = 20.0
				frenzied_trail.initial_velocity_max = 50.0
				frenzied_trail.scale_amount_min = 2.5
				frenzied_trail.scale_amount_max = 5.0
				frenzied_trail.color = Color(1.0, 0.15, 0.15, 0.75)
				add_child(frenzied_trail)

func set_as_alpha_target() -> void:
	is_alpha_target = true
	add_to_group("alpha_targets")
	add_to_group("elites")
	
	max_health *= 2.5
	current_health = max_health
	speed *= 1.15
	scale *= 1.25
	
	base_modulate = Color(1.9, 0.75, 0.2, 1.0)
	if sprite:
		sprite.modulate = base_modulate
	
	if alpha_marker == null:
		alpha_marker = Node2D.new()
		alpha_marker.name = "AlphaMarker"
		alpha_marker.position = Vector2(0, -44)
		
		var icon = Sprite2D.new()
		icon.texture = ProceduralTextures.get_orange_skull_icon()
		icon.modulate = Color(1.0, 0.55, 0.12, 1.0)
		icon.scale = Vector2(0.9, 0.9)
		alpha_marker.add_child(icon)
		
		var light = PointLight2D.new()
		light.color = Color(1.0, 0.55, 0.15, 1.0)
		light.energy = 1.1
		light.texture = preload("res://assets/textures/lighting/point_light_cookie.png")
		light.texture_scale = 0.6
		alpha_marker.add_child(light)
		
		add_child(alpha_marker)

func explode_volatile() -> void:
	if has_exploded:
		return
	has_exploded = true
	current_health = 0.0
	
	Global.play_sound("explode")
	Global.explosion_occurred.emit()
	
	if player == null or not is_instance_valid(player):
		_find_player()
	
	if player and is_instance_valid(player) and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.25)
	
	var aoe_radius = 90.0
	var aoe_damage = 45.0
	
	# Damage player within blast radius
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var dist = global_position.distance_to(player.global_position)
		if dist <= aoe_radius:
			var dir = (player.global_position - global_position).normalized()
			player.take_damage(aoe_damage, dir)
	
	# Damage nearby zombies in blast
	var allies = get_tree().get_nodes_in_group("enemies")
	for ally in allies:
		if is_instance_valid(ally) and ally != self and ally.has_method("take_damage"):
			var d = global_position.distance_to(ally.global_position)
			if d <= aoe_radius:
				ally.take_damage(60.0, (ally.global_position - global_position).normalized())
	
	# Spawn caustic puddle that damages anyone standing in it for 5s
	var level = get_tree().current_scene
	if level:
		var acid_scene = preload("res://scenes/AcidPool.tscn")
		var puddle = acid_scene.instantiate()
		puddle.global_position = global_position
		puddle.duration = 5.0
		puddle.damage_per_second = 18.0
		level.call_deferred("add_child", puddle)
		
		# Toxic green explosion particle burst
		var burst = CPUParticles2D.new()
		burst.global_position = global_position
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 22
		burst.lifetime = 0.55
		burst.spread = 180.0
		burst.initial_velocity_min = 90.0
		burst.initial_velocity_max = 240.0
		burst.scale_amount_min = 4.0
		burst.scale_amount_max = 8.0
		burst.color = Color(0.3, 1.0, 0.35, 0.9)
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)
	
	spawn_blood_splat(Vector2.ZERO)
	queue_free()

func spawn_overkill_gibs(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if level:
		var gibs = CPUParticles2D.new()
		gibs.emitting = true
		gibs.one_shot = true
		gibs.explosiveness = 0.95
		gibs.amount = 20
		gibs.lifetime = 0.55
		gibs.direction = hit_dir if hit_dir != Vector2.ZERO else Vector2.UP
		gibs.spread = 140.0
		gibs.initial_velocity_min = 90.0
		gibs.initial_velocity_max = 240.0
		gibs.scale_amount_min = 2.5
		gibs.scale_amount_max = 6.0
		gibs.color = Color(0.65, 0.08, 0.08, 1.0) # Visceral flesh & arterial blood
		gibs.global_position = global_position
		gibs.finished.connect(gibs.queue_free)
		level.add_child(gibs)
	
	# Convert into permanent flat decals via DecalManager
	if DecalManager and DecalManager.has_method("spawn_blood_splat"):
		DecalManager.spawn_blood_splat(global_position, hit_dir, 1.6)
		DecalManager.spawn_blood_splat(global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16)), hit_dir, 1.2)

func spawn_blood_splat(hit_dir: Vector2) -> void:
	var level = get_tree().current_scene
	if level:
		BLOOD_SPLAT_SCRIPT.spawn_splat(level, global_position, hit_dir)

func roll_loot() -> void:
	var roll = randf()
	# Emergency scraps: nerfed to 8% total drop rate (4% health, 4% ammo)
	if roll < 0.04:
		spawn_pickup(0) # 0 = Health
	elif roll < 0.08:
		spawn_pickup(1) # 1 = Ammo

func spawn_pickup(pickup_type: int) -> void:
	var level = get_tree().current_scene
	if level:
		var pickup_scene = preload("res://scenes/Pickup.tscn")
		var pickup = pickup_scene.instantiate()
		pickup.global_position = global_position
		pickup.pickup_type = pickup_type
		level.call_deferred("add_child", pickup)

func spawn_scrap_drop() -> void:
	var amount = 1
	match zombie_type:
		ZombieType.REGULAR, ZombieType.SPITTER, ZombieType.SCREAMER:
			amount = randi_range(1, 2) # Walkers: 1-2
		ZombieType.INFECTED_DOG:
			amount = 3 # Dogs: 3
		ZombieType.HEAVY, ZombieType.ARMORED:
			amount = randi_range(10, 15) # Heavy/Elites: 10-15
		ZombieType.COLOSSUS:
			amount = randi_range(20, 30) # Boss: 20-30
	
	if EconomyManager and EconomyManager.has_method("spawn_scrap"):
		EconomyManager.spawn_scrap(global_position, amount)
