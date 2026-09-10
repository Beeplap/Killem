extends Node2D

## Infinite Chunk-Based Procedural Map Manager
## Handles seamless chunk streaming around the player, deterministic FastNoiseLite world coordinates,
## balanced overcast lighting palette, NavMesh stitching, and zero-allocation chunk pooling.

const CHUNK_SIZE: float = 48.0 # In meters/units
const UNIT_SCALE: float = 16.0 # 16 pixels per unit (48 * 16 = 768.0 pixels per chunk)
const CHUNK_PIXELS: float = CHUNK_SIZE * UNIT_SCALE
const ACTIVE_RADIUS: int = 3 # 7x7 active grid (-3 to +3 chunks)
const CLEARANCE_RADIUS_UNITS: float = 6.0
const CLEARANCE_RADIUS_PIXELS: float = CLEARANCE_RADIUS_UNITS * UNIT_SCALE # 96.0 pixels

# Noise Generators for Continuous World Space
var biome_noise: FastNoiseLite
var road_noise: FastNoiseLite
var prop_noise: FastNoiseLite

# Chunk Management
var _active_chunks: Dictionary = {} # Vector2i -> TerrainChunk
var _chunk_pool: Array[TerrainChunk] = []
var _last_player_chunk: Vector2i = Vector2i(-999999, -999999)

var player: Node = null
var chunk_container: Node2D = null

# Cached PBR Normal-Mapped CanvasTextures
var tex_asphalt: CanvasTexture
var tex_dirt: CanvasTexture
var tex_railway: CanvasTexture
var tex_hazard: CanvasTexture
var tex_wall_h: CanvasTexture
var tex_wall_v: CanvasTexture
var tex_truck: CanvasTexture
var tex_fence_h: Texture2D
var tex_grass: Texture2D
var tex_oil_slick: Texture2D
var tex_pointlight: Texture2D

var barrel_scene: PackedScene
var crate_scene: PackedScene

func _init() -> void:
	name = "InfiniteTerrainManager"
	_init_noise()
	_load_resources()

func _ready() -> void:
	_setup_container()
	_find_player()
	if player:
		var start_chunk = get_chunk_coord(player.global_position)
		update_chunks(start_chunk)
		_last_player_chunk = start_chunk

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		return
	
	if not is_instance_valid(chunk_container) or chunk_container.get_parent() == null:
		_setup_container()
	
	var current_chunk = get_chunk_coord(player.global_position)
	if current_chunk != _last_player_chunk:
		update_chunks(current_chunk)
		_last_player_chunk = current_chunk

func _init_noise() -> void:
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = 1337
	biome_noise.frequency = 0.0008
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	
	road_noise = FastNoiseLite.new()
	road_noise.seed = 4242
	road_noise.frequency = 0.0015
	road_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	
	prop_noise = FastNoiseLite.new()
	prop_noise.seed = 8080
	prop_noise.frequency = 0.006
	prop_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func _load_resources() -> void:
	# Asphalt PBR
	tex_asphalt = CanvasTexture.new()
	tex_asphalt.diffuse_texture = load("res://assets/textures/ground/cracked_asphalt.png")
	tex_asphalt.normal_texture = load("res://assets/textures/ground/cracked_asphalt_n.png")
	tex_asphalt.specular_color = Color(0.38, 0.40, 0.46, 1.0)
	tex_asphalt.specular_shininess = 16.0
	
	# Dirt / Peat PBR
	tex_dirt = CanvasTexture.new()
	tex_dirt.diffuse_texture = load("res://assets/textures/ground/dirt_terrain.png")
	tex_dirt.normal_texture = load("res://assets/textures/ground/dirt_terrain_n.png")
	tex_dirt.specular_color = Color(0.20, 0.22, 0.25, 1.0)
	tex_dirt.specular_shininess = 6.0
	
	# Railway Track PBR
	tex_railway = CanvasTexture.new()
	tex_railway.diffuse_texture = load("res://assets/textures/railway/railway_track.png")
	tex_railway.normal_texture = load("res://assets/textures/railway/railway_track_n.png")
	tex_railway.specular_color = Color(0.65, 0.68, 0.75, 1.0)
	tex_railway.specular_shininess = 28.0
	
	# Hazard Platform PBR
	tex_hazard = CanvasTexture.new()
	tex_hazard.diffuse_texture = load("res://assets/textures/railway/hazard_platform.png")
	tex_hazard.normal_texture = load("res://assets/textures/railway/hazard_platform_n.png")
	tex_hazard.specular_color = Color(0.48, 0.50, 0.55, 1.0)
	tex_hazard.specular_shininess = 20.0
	
	# Concrete Walls PBR
	tex_wall_h = CanvasTexture.new()
	tex_wall_h.diffuse_texture = load("res://assets/textures/environment/concrete_wall_h.png")
	tex_wall_h.normal_texture = load("res://assets/textures/environment/concrete_wall_h_n.png")
	
	tex_wall_v = CanvasTexture.new()
	tex_wall_v.diffuse_texture = load("res://assets/textures/environment/concrete_wall_v.png")
	tex_wall_v.normal_texture = load("res://assets/textures/environment/concrete_wall_v_n.png")
	
	# Military Truck PBR
	tex_truck = CanvasTexture.new()
	tex_truck.diffuse_texture = load("res://assets/textures/environment/military_truck_wreck.png")
	tex_truck.normal_texture = load("res://assets/textures/environment/military_truck_wreck_n.png")
	
	tex_fence_h = load("res://assets/textures/environment/chainlink_fence_h.png")
	tex_grass = load("res://assets/textures/ground/dead_grass.png")
	tex_oil_slick = load("res://assets/textures/decals/oil_slick.png")
	tex_pointlight = load("res://assets/textures/lighting/point_light_cookie.png")
	
	barrel_scene = load("res://scenes/OilBarrel.tscn")
	crate_scene = load("res://scenes/DestructibleCrate.tscn")

func _cleanup_stale_chunks() -> void:
	_active_chunks.clear()
	_chunk_pool.clear()
	_last_player_chunk = Vector2i(-999999, -999999)

func _setup_container() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		var existing = current_scene.get_node_or_null("ChunkContainer")
		if existing:
			if chunk_container != existing:
				_cleanup_stale_chunks()
			chunk_container = existing
		else:
			_cleanup_stale_chunks()
			chunk_container = Node2D.new()
			chunk_container.name = "ChunkContainer"
			chunk_container.z_index = -3
			current_scene.add_child(chunk_container)
	else:
		if chunk_container == null:
			_cleanup_stale_chunks()
			chunk_container = Node2D.new()
			chunk_container.name = "ChunkContainer"
			add_child(chunk_container)

func _find_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and p is Node2D:
		player = p

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CHUNK_PIXELS)), int(floor(world_pos.y / CHUNK_PIXELS)))

func get_chunk_world_pos(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * CHUNK_PIXELS, coord.y * CHUNK_PIXELS)

func get_active_chunk_count() -> int:
	return _active_chunks.size()

func is_chunk_active(c: Vector2i) -> bool:
	return _active_chunks.has(c)

func get_active_chunks() -> Dictionary:
	return _active_chunks

func is_highway_corridor(c: Vector2i) -> bool:
	return posmod(c.y + 1, 4) == 0

func is_rail_corridor(c: Vector2i) -> bool:
	return posmod(c.x + 2, 6) == 0

func get_biome_at(world_pos: Vector2) -> String:
	var c = get_chunk_coord(world_pos)
	if _active_chunks.has(c):
		return _active_chunks[c].biome
	if is_rail_corridor(c): return "railyard"
	elif is_highway_corridor(c): return "highway"
	return "wasteland"

## Core Streaming Update: Instantiates chunks in 7x7 grid and pools chunks beyond active radius
func update_chunks(player_chunk: Vector2i) -> void:
	if chunk_container == null or not is_instance_valid(chunk_container):
		_setup_container()
	
	var needed_coords: Dictionary = {}
	
	# 7x7 Active Grid (-3 to +3 in both axes)
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var c = player_chunk + Vector2i(dx, dy)
			needed_coords[c] = true
			
			if not _active_chunks.has(c):
				_spawn_chunk(c)
	
	# Despawn and pool chunks outside active radius
	var to_despawn: Array[Vector2i] = []
	for c in _active_chunks.keys():
		if not needed_coords.has(c) or not is_instance_valid(_active_chunks[c]):
			to_despawn.append(c)
	
	for c in to_despawn:
		_despawn_chunk(c)

func _spawn_chunk(c: Vector2i) -> void:
	var chunk: TerrainChunk = null
	while _chunk_pool.size() > 0:
		var candidate = _chunk_pool.pop_back()
		if is_instance_valid(candidate):
			chunk = candidate
			break
	if chunk == null:
		chunk = TerrainChunk.new()
	
	chunk.setup_chunk(c, self)
	if is_instance_valid(chunk_container):
		if chunk.get_parent() == null:
			chunk_container.add_child(chunk)
		elif chunk.get_parent() != chunk_container:
			if chunk.get_parent():
				chunk.get_parent().remove_child(chunk)
			chunk_container.add_child(chunk)
	chunk.visible = true
	_active_chunks[c] = chunk

func _despawn_chunk(c: Vector2i) -> void:
	if not _active_chunks.has(c):
		return
	var chunk = _active_chunks[c]
	_active_chunks.erase(c)
	if not is_instance_valid(chunk):
		return
	
	chunk.recycle()
	chunk.visible = false
	if is_instance_valid(chunk_container) and chunk.get_parent() == chunk_container:
		chunk_container.remove_child(chunk)
	_chunk_pool.append(chunk)

func force_update_chunks() -> void:
	if player:
		var c = get_chunk_coord(player.global_position)
		update_chunks(c)
		_last_player_chunk = c

func clear_all_chunks() -> void:
	for c in _active_chunks.keys():
		var chunk = _active_chunks[c]
		if is_instance_valid(chunk):
			chunk.recycle()
			if chunk.get_parent():
				chunk.get_parent().remove_child(chunk)
			chunk.queue_free()
	_active_chunks.clear()
	
	for chunk in _chunk_pool:
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunk_pool.clear()
	_last_player_chunk = Vector2i(-999999, -999999)
