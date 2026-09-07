extends Node2D

const REGULAR_ZOMBIE: PackedScene = preload("res://scenes/Zombie.tscn")
const INFECTED_DOG: PackedScene = preload("res://scenes/InfectedDog.tscn")
const HEAVY_ZOMBIE: PackedScene = preload("res://scenes/HeavyZombie.tscn")
const SPITTER_ZOMBIE: PackedScene = preload("res://scenes/SpitterZombie.tscn")
const ARMORED_ZOMBIE: PackedScene = preload("res://scenes/ArmoredZombie.tscn")
const COLOSSUS_ZOMBIE: PackedScene = preload("res://scenes/ColossusZombie.tscn")
const SCREAMER_ZOMBIE: PackedScene = preload("res://scenes/ScreamerZombie.tscn")

var zombie_scenes: Dictionary = {
	"walker": REGULAR_ZOMBIE,
	"regular": REGULAR_ZOMBIE,
	"dog": INFECTED_DOG,
	"heavy": HEAVY_ZOMBIE,
	"spitter": SPITTER_ZOMBIE,
	"armored": ARMORED_ZOMBIE,
	"colossus": COLOSSUS_ZOMBIE,
	"screamer": SCREAMER_ZOMBIE
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

const SUPPLY_DROP_SCENE: PackedScene = preload("res://scenes/mechanics/SupplyDrop.tscn")
const SUPPLY_DROP_INTERVAL: float = 30.0

var current_state: State = State.SPAWNING
var zombies_remaining_to_spawn: int = 0
var spawn_timer: float = 0.0
var cooldown_timer: float = 0.0
var last_announced_second: int = -1
var boss_spawned_for_wave: bool = false
var supply_drop_timer: float = 0.0

var player: Node2D = null

func _ready() -> void:
	start_wave(1)

func _process(delta: float) -> void:
	if Global.is_game_over:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	# Repeating 30-Second Tactical Supply Drop
	supply_drop_timer += delta
	if supply_drop_timer >= SUPPLY_DROP_INTERVAL:
		supply_drop_timer = 0.0
		spawn_air_drop()
	
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

var current_wave_params: Dictionary = {}

func calculate_wave_parameters(wave: int) -> Dictionary:
	var total_enemies = int(20 + pow(wave, 1.35) * 4)
	var dog_ratio = clamp(0.15 + (wave * 0.03), 0.15, 0.45)
	var heavy_ratio = clamp((wave - 4) * 0.04, 0.05, 0.35) if wave >= 5 else 0.0
	var spawn_delay = max(0.15, 0.65 - (wave * 0.03))
	return {
		"count": total_enemies,
		"dog_ratio": dog_ratio,
		"heavy_ratio": heavy_ratio,
		"delay": spawn_delay
	}

func start_wave(target_wave: int) -> void:
	wave_number = target_wave
	Global.current_wave = wave_number
	Global.wave_changed.emit(wave_number)
	
	current_wave_params = calculate_wave_parameters(wave_number)
	enemies_per_wave = current_wave_params["count"]
	spawn_interval = current_wave_params["delay"]
	zombies_remaining_to_spawn = enemies_per_wave
	spawn_timer = 0.0
	boss_spawned_for_wave = false
	current_state = State.SPAWNING
	
	print("[SPAWNER] STARTING WAVE %d (Endless Survival): %d zombies in batches of 3-5 every %.2fs [Dogs: %d%%, Heavies: %d%%]" % [
		wave_number,
		enemies_per_wave,
		spawn_interval,
		int(current_wave_params["dog_ratio"] * 100),
		int(current_wave_params["heavy_ratio"] * 100)
	])
	
	Global.wave_started.emit(wave_number)
	Global.play_sound("wave_start")
	
	# Air drop every 4 waves (waves 4, 8, 12...)
	if wave_number % 4 == 0:
		spawn_air_drop()

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
		
		var zombie_scene = select_zombie_scene()
		var zombie = zombie_scene.instantiate()
		zombie.global_position = spawn_pos
		zombie.wave_number = wave_number
		get_parent().call_deferred("add_child", zombie)
		zombies_remaining_to_spawn -= 1

func spawn_boss_zombie() -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var spawn_angle = randf() * TAU
	var spawn_dist = randf_range(750.0, 900.0)
	var spawn_pos = player.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_dist
	
	var boss = COLOSSUS_ZOMBIE.instantiate()
	boss.global_position = spawn_pos
	boss.wave_number = wave_number
	get_parent().call_deferred("add_child", boss)
	Global.boss_spawned.emit(boss)
	Global.play_sound("zombie_groan")

func spawn_air_drop() -> void:
	spawn_supply_drop()

func spawn_supply_drop() -> void:
	if player == null or not is_instance_valid(player):
		return
	var drop = SUPPLY_DROP_SCENE.instantiate()
	var angle = randf() * TAU
	var dist = randf_range(180.0, 320.0)
	var pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	drop.global_position = pos
	get_parent().call_deferred("add_child", drop)
	print("[SPAWNER] 30s Tactical Supply Airdrop inbound at LZ: ", pos)

func select_zombie_scene() -> PackedScene:
	var roll = randf()
	var dog_ratio: float = current_wave_params.get("dog_ratio", 0.15)
	var heavy_ratio: float = current_wave_params.get("heavy_ratio", 0.0)
	
	var armored_ratio = clamp((wave_number - 3) * 0.03, 0.0, 0.22) if wave_number >= 4 else 0.0
	var spitter_ratio = clamp((wave_number - 1) * 0.025, 0.0, 0.18) if wave_number >= 2 else 0.0
	var screamer_ratio = clamp((wave_number - 2) * 0.025, 0.0, 0.15) if wave_number >= 3 else 0.0
	
	var t_dog = dog_ratio
	var t_heavy = t_dog + heavy_ratio
	var t_armored = t_heavy + armored_ratio
	var t_spitter = t_armored + spitter_ratio
	var t_screamer = t_spitter + screamer_ratio
	
	if roll < t_dog:
		return INFECTED_DOG
	elif roll < t_heavy:
		return HEAVY_ZOMBIE
	elif roll < t_armored:
		return ARMORED_ZOMBIE
	elif roll < t_spitter:
		return SPITTER_ZOMBIE
	elif roll < t_screamer:
		return SCREAMER_ZOMBIE
	else:
		return REGULAR_ZOMBIE
