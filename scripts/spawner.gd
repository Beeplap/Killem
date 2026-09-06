extends Node2D

const REGULAR_ZOMBIE: PackedScene = preload("res://scenes/Zombie.tscn")
const INFECTED_DOG: PackedScene = preload("res://scenes/InfectedDog.tscn")
const HEAVY_ZOMBIE: PackedScene = preload("res://scenes/HeavyZombie.tscn")
const SPITTER_ZOMBIE: PackedScene = preload("res://scenes/SpitterZombie.tscn")
const ARMORED_ZOMBIE: PackedScene = preload("res://scenes/ArmoredZombie.tscn")
const COLOSSUS_ZOMBIE: PackedScene = preload("res://scenes/ColossusZombie.tscn")

var zombie_scenes: Dictionary = {
	"walker": REGULAR_ZOMBIE,
	"regular": REGULAR_ZOMBIE,
	"dog": INFECTED_DOG,
	"heavy": HEAVY_ZOMBIE,
	"spitter": SPITTER_ZOMBIE,
	"armored": ARMORED_ZOMBIE,
	"colossus": COLOSSUS_ZOMBIE
}

# Wave Configuration Variables
@export var wave_number: int = 1
@export var enemies_per_wave: int = 18
@export var spawn_batch_size: int = 4
@export var spawn_interval: float = 0.8
@export var wave_cooldown: float = 5.0
@export var wave_scaling_increment: int = 8

enum State {
	SPAWNING,
	COMBAT_WAITING_FOR_CLEAR,
	WAVE_CLEARED_REST
}

var current_state: State = State.SPAWNING
var zombies_remaining_to_spawn: int = 0
var spawn_timer: float = 0.0
var cooldown_timer: float = 0.0
var last_announced_second: int = -1
var boss_spawned_for_wave: bool = false

var player: Node2D = null

func _ready() -> void:
	start_wave(1)

func _process(delta: float) -> void:
	if Global.is_game_over:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	match current_state:
		State.SPAWNING:
			# Check for boss spawn on Wave 5+
			if wave_number >= 5 and not boss_spawned_for_wave:
				boss_spawned_for_wave = true
				spawn_boss_zombie()
			
			spawn_timer += delta
			if spawn_timer >= spawn_interval:
				spawn_timer = 0.0
				# Rapid groups of 3-5 enemies every 0.8s
				var count = clampi(spawn_batch_size + randi_range(-1, 1), 3, 5)
				count = min(count, zombies_remaining_to_spawn)
				if count > 0:
					spawn_batch(count)
					print("[SPAWNER] Spawned batch of %d zombies. Remaining in wave quota: %d" % [count, zombies_remaining_to_spawn])
				
				if zombies_remaining_to_spawn <= 0:
					print("[SPAWNER] All wave zombies spawned. Waiting for elimination/stragglers...")
					current_state = State.COMBAT_WAITING_FOR_CLEAR
		
		State.COMBAT_WAITING_FOR_CLEAR:
			# Count active enemies in the level
			var active_enemies = get_tree().get_nodes_in_group("enemies").size()
			# Trigger cleared state when eliminated or reduced to 1-2 stragglers
			var straggler_threshold = 2 if enemies_per_wave >= 25 else 1
			if active_enemies <= straggler_threshold:
				current_state = State.WAVE_CLEARED_REST
				cooldown_timer = wave_cooldown
				last_announced_second = -1
				print("[SPAWNER] WAVE %d CLEARED! Rest interval: %.1fs (Remaining enemies: %d)" % [wave_number, wave_cooldown, active_enemies])
				Global.wave_cleared.emit(wave_number, wave_cooldown)
				Global.play_sound("wave_clear")
		
		State.WAVE_CLEARED_REST:
			cooldown_timer -= delta
			var seconds_left = int(ceil(max(0.0, cooldown_timer)))
			if seconds_left != last_announced_second and seconds_left > 0:
				last_announced_second = seconds_left
				print("[SPAWNER] Rest interval countdown: %ds" % seconds_left)
				Global.wave_countdown.emit(seconds_left)
			
			if cooldown_timer <= 0.0:
				start_wave(wave_number + 1)

func start_wave(target_wave: int) -> void:
	wave_number = target_wave
	Global.current_wave = wave_number
	Global.wave_changed.emit(wave_number)
	
	# Wave 1 starts with 18 zombies (15-20 range), scaling up by 8 (5-10 range) each wave
	enemies_per_wave = 18 + (wave_number - 1) * wave_scaling_increment
	zombies_remaining_to_spawn = enemies_per_wave
	spawn_timer = 0.0
	boss_spawned_for_wave = false
	current_state = State.SPAWNING
	
	var weights = get_wave_weights(wave_number)
	var desc_parts: Array[String] = []
	for k in weights:
		if weights[k] > 0.0:
			desc_parts.append("%s: %d%%" % [k.capitalize(), int(round(weights[k] * 100))])
	var dist_str = ", ".join(desc_parts)
	print("[SPAWNER] STARTING WAVE %d: %d zombies in batches of 3-5 every %.1fs [%s]" % [wave_number, enemies_per_wave, spawn_interval, dist_str])
	
	Global.wave_started.emit(wave_number)
	Global.play_sound("wave_start")

func spawn_batch(count: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# Horde pack coordination: spawn cluster along an incoming vector
	var cluster_center_angle = randf() * TAU
	
	for _i in range(count):
		if zombies_remaining_to_spawn <= 0:
			break
		
		# Jitter position slightly along arc for a realistic pack entrance
		var angle = cluster_center_angle + randf_range(-0.45, 0.45)
		var spawn_dist = randf_range(700.0, 900.0)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_dist
		
		# Map bounds constraint (-1350 to 1350)
		spawn_pos.x = clamp(spawn_pos.x, -1350.0, 1350.0)
		spawn_pos.y = clamp(spawn_pos.y, -1350.0, 1350.0)
		
		# Safety guard: ensure enemies never materialize too close to player even after clamp
		if spawn_pos.distance_to(player.global_position) < 680.0:
			var inward_dir = (Vector2.ZERO - player.global_position).normalized()
			if inward_dir == Vector2.ZERO:
				inward_dir = Vector2.UP
			spawn_pos = player.global_position + inward_dir * randf_range(720.0, 880.0)
			spawn_pos.x = clamp(spawn_pos.x, -1350.0, 1350.0)
			spawn_pos.y = clamp(spawn_pos.y, -1350.0, 1350.0)
		
		var zombie_scene = select_zombie_scene()
		var zombie = zombie_scene.instantiate()
		zombie.global_position = spawn_pos
		zombie.wave_number = wave_number
		get_parent().add_child(zombie)
		zombies_remaining_to_spawn -= 1

func spawn_boss_zombie() -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var spawn_angle = randf() * TAU
	var spawn_dist = randf_range(750.0, 900.0)
	var spawn_pos = player.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_dist
	spawn_pos.x = clamp(spawn_pos.x, -1300.0, 1300.0)
	spawn_pos.y = clamp(spawn_pos.y, -1300.0, 1300.0)
	
	var boss = zombie_scenes["colossus"].instantiate()
	boss.global_position = spawn_pos
	boss.wave_number = wave_number
	get_parent().add_child(boss)
	Global.play_sound("zombie_groan")

func get_wave_weights(wave: int) -> Dictionary:
	# Wave-gated progression rules:
	# Wave 1 & 2: 100% Regular Walkers
	# Wave 3 & 4: Introduce Infected Dogs (70% Walkers, 30% Dogs)
	# Wave 5+: Introduce Heavy Mutants (50% Walkers, 35% Dogs, 15% Heavy Mutants)
	match wave:
		1:
			return {"walker": 1.0, "dog": 0.0, "heavy": 0.0}
		2:
			return {"walker": 1.0, "dog": 0.0, "heavy": 0.0}
		3:
			return {"walker": 0.72, "dog": 0.28, "heavy": 0.0}
		4:
			return {"walker": 0.68, "dog": 0.32, "heavy": 0.0}
		5:
			return {"walker": 0.50, "dog": 0.35, "heavy": 0.15}
		6:
			return {"walker": 0.48, "dog": 0.35, "heavy": 0.17}
		7:
			return {"walker": 0.45, "dog": 0.35, "heavy": 0.20}
		_:
			# Wave 8+: Scaled distribution with progressive mutant pressure
			var heavy_w = min(0.28, 0.15 + (wave - 5) * 0.02)
			var dog_w = 0.35
			var walker_w = max(0.30, 1.0 - (heavy_w + dog_w))
			return {"walker": walker_w, "dog": dog_w, "heavy": heavy_w}

func select_zombie_scene() -> PackedScene:
	var weights = get_wave_weights(wave_number)
	var roll = randf()
	var cumulative: float = 0.0
	
	for enemy_key in weights.keys():
		cumulative += weights[enemy_key]
		if roll <= cumulative and weights[enemy_key] > 0.0:
			return zombie_scenes.get(enemy_key, REGULAR_ZOMBIE)
	
	return zombie_scenes.get("walker", REGULAR_ZOMBIE)
