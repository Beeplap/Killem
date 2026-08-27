extends Node2D

const REGULAR_ZOMBIE: PackedScene = preload("res://scenes/Zombie.tscn")
const INFECTED_DOG: PackedScene = preload("res://scenes/InfectedDog.tscn")
const HEAVY_ZOMBIE: PackedScene = preload("res://scenes/HeavyZombie.tscn")

@export var spawn_interval: float = 1.1
@export var base_zombies_per_wave: int = 8

var current_wave: int = 1
var zombies_to_spawn: int = 0
var active_zombies: int = 0
var spawn_timer: float = 0.0
var wave_in_progress: bool = false

var player: Node2D = null

func _ready() -> void:
	start_wave(1)

func _process(delta: float) -> void:
	if Global.is_game_over:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	if wave_in_progress:
		if zombies_to_spawn > 0:
			spawn_timer += delta
			if spawn_timer >= spawn_interval:
				spawn_timer = 0.0
				spawn_single_zombie()
		else:
			# Check how many zombies remain alive
			var count = get_tree().get_nodes_in_group("enemies").size()
			if count == 0:
				wave_in_progress = false
				# Brief respite between waves
				await get_tree().create_timer(4.5).timeout
				start_wave(current_wave + 1)

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	Global.current_wave = current_wave
	Global.wave_changed.emit(current_wave)
	
	zombies_to_spawn = base_zombies_per_wave + (current_wave - 1) * 6
	spawn_interval = max(0.35, 1.2 - (current_wave - 1) * 0.08)
	spawn_timer = 0.0
	wave_in_progress = true

func spawn_single_zombie() -> void:
	if player == null:
		return
	
	# Pick a perimeter spawn position 650 to 900 pixels away from player
	var spawn_angle = randf() * TAU
	var spawn_dist = randf_range(680.0, 950.0)
	var spawn_pos = player.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_dist
	
	# Clamp to level boundaries
	spawn_pos.x = clamp(spawn_pos.x, -1250.0, 1250.0)
	spawn_pos.y = clamp(spawn_pos.y, -1250.0, 1250.0)
	
	# Pick zombie variant based on wave
	var zombie_scene: PackedScene = REGULAR_ZOMBIE
	var roll = randf()
	
	if current_wave >= 3 and roll < 0.20:
		zombie_scene = HEAVY_ZOMBIE
	elif current_wave >= 2 and roll < 0.55:
		zombie_scene = INFECTED_DOG
	else:
		zombie_scene = REGULAR_ZOMBIE
	
	var zombie = zombie_scene.instantiate()
	zombie.global_position = spawn_pos
	get_parent().add_child(zombie)
	zombies_to_spawn -= 1
