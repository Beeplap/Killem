extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")

@onready var bunker_light: PointLight2D = get_node_or_null("EnvironmentObjects/BunkerBuilding/BunkerLamp")
@onready var yard_light_1: PointLight2D = get_node_or_null("Lighting/YardFloodlight1")
@onready var yard_light_2: PointLight2D = get_node_or_null("Lighting/YardFloodlight2")
@onready var players_container: Node2D = get_node_or_null("Players")
@onready var enemies_container: Node2D = get_node_or_null("Enemies")
@onready var player_spawner: MultiplayerSpawner = get_node_or_null("PlayerSpawner")
@onready var enemy_spawner: MultiplayerSpawner = get_node_or_null("EnemySpawner")
@onready var spawner: Node2D = $ZombieSpawner
@onready var post_process_rect: ColorRect = get_node_or_null("PostProcessLayer/PostProcessRect")

var player: CharacterBody2D = null
var post_process_mat: ShaderMaterial = null
var firing_dirt_intensity: float = 0.0
var explosion_aberration_intensity: float = 0.0
var action_grain_boost: float = 0.0
var flicker_time: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	
	if post_process_rect and post_process_rect.material is ShaderMaterial:
		post_process_mat = post_process_rect.material
	
	Global.player_fired.connect(_on_player_fired)
	Global.explosion_occurred.connect(_on_explosion_occurred)
	
	# Spawn player(s) based on session type
	if not NetworkManager.is_network_active():
		# Singleplayer local session
		spawn_player(1)
	else:
		# Networked LAN Co-op session
		if multiplayer.is_server():
			# Spawn host player
			spawn_player(1)
			# Spawn any already connected peers
			for p_id in NetworkManager.connected_peers:
				spawn_player(p_id)
			
			if not NetworkManager.peer_connected.is_connected(_on_peer_connected):
				NetworkManager.peer_connected.connect(_on_peer_connected)
			if not NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
				NetworkManager.peer_disconnected.connect(_on_peer_disconnected)

func spawn_player(peer_id: int) -> CharacterBody2D:
	if not players_container:
		return null
	
	var existing = players_container.get_node_or_null(str(peer_id))
	if existing:
		return existing
	
	var new_player: CharacterBody2D = PLAYER_SCENE.instantiate()
	new_player.name = str(peer_id)
	new_player.set_multiplayer_authority(peer_id)
	
	# Stagger spawn positions slightly around origin
	var spawn_pos = Vector2.ZERO
	if peer_id > 1:
		var angle = (peer_id * 1.35) * TAU
		spawn_pos = Vector2(cos(angle), sin(angle)) * randf_range(35.0, 95.0)
	new_player.global_position = spawn_pos
	
	players_container.add_child(new_player, true) # force_readable_name = true
	
	if peer_id == NetworkManager.get_local_peer_id():
		player = new_player
		var cam_ctrl = get_tree().get_first_node_in_group("camera_controller")
		if cam_ctrl and cam_ctrl.has_method("set_player_target"):
			cam_ctrl.set_player_target(new_player)
	
	print("[MAIN LEVEL] Spawned Player node '%s' for Peer ID %d at %s" % [new_player.name, peer_id, new_player.global_position])
	return new_player

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_player(peer_id)
		sync_initial_state.rpc_id(peer_id, Global.current_wave, Global.score, GameManager.scrap)

func _on_peer_disconnected(peer_id: int) -> void:
	if players_container:
		var node = players_container.get_node_or_null(str(peer_id))
		if node:
			node.queue_free()
			print("[MAIN LEVEL] Removed disconnected player node %d" % peer_id)

@rpc("call_remote", "reliable")
func sync_initial_state(current_wave: int, score: int, scrap: int) -> void:
	GameManager.current_wave = current_wave
	GameManager.total_score = score
	GameManager.scrap = scrap
	print("[MAIN LEVEL] Synced initial match state: Wave %d | Score %d | Scrap %d" % [current_wave, score, scrap])

func _process(delta: float) -> void:
	# Bunker sodium worklight flicker
	if bunker_light:
		flicker_time += delta * 14.0
		var flicker = sin(flicker_time) * 0.06 + sin(flicker_time * 2.7) * 0.04
		if randf() < 0.008:
			bunker_light.energy = 0.45
		else:
			bunker_light.energy = lerp(bunker_light.energy, 1.55 + flicker, delta * 10.0)
	
	# Update cinematic post-processing dynamic action parameters
	if post_process_mat:
		if firing_dirt_intensity > 0.0:
			firing_dirt_intensity = move_toward(firing_dirt_intensity, 0.0, delta * 3.5)
			post_process_mat.set_shader_parameter("firing_lens_dirt", firing_dirt_intensity)
		
		if explosion_aberration_intensity > 0.0:
			explosion_aberration_intensity = move_toward(explosion_aberration_intensity, 0.0, delta * 0.12)
			post_process_mat.set_shader_parameter("action_burst_aberration", explosion_aberration_intensity)
		
		if action_grain_boost > 0.0:
			action_grain_boost = move_toward(action_grain_boost, 0.0, delta * 0.25)
			post_process_mat.set_shader_parameter("action_grain_boost", action_grain_boost)

func trigger_firing_effect() -> void:
	firing_dirt_intensity = 0.65
	if post_process_mat:
		post_process_mat.set_shader_parameter("firing_lens_dirt", firing_dirt_intensity)

func trigger_explosion_effect() -> void:
	explosion_aberration_intensity = 0.045
	action_grain_boost = 0.15
	if post_process_mat:
		post_process_mat.set_shader_parameter("action_burst_aberration", explosion_aberration_intensity)
		post_process_mat.set_shader_parameter("action_grain_boost", action_grain_boost)

func _on_player_fired() -> void:
	trigger_firing_effect()

func _on_explosion_occurred() -> void:
	trigger_explosion_effect()
