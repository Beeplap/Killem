class_name TerrainChunk
extends Node2D

## Procedural Terrain Chunk for Infinite Chunk-Based Streaming
## Handles continuous world-space noise texturing, procedural POIs, local NavMesh, and pooling.

var coord: Vector2i = Vector2i.ZERO
var chunk_size_px: float = 768.0
var biome: String = "wasteland"

var nav_region: NavigationRegion2D
var ground_rect: TextureRect
var mist_rect: ColorRect
var props_node: Node2D
var tracks_node: Node2D
var road_lines_node: Node2D
var hazard_lights: Array[PointLight2D] = []

var _flicker_phase: float = 0.0
var _active_dynamic_props: Array[Node] = []

func _init() -> void:
	# Ground Base layer (z_index = -3)
	ground_rect = TextureRect.new()
	ground_rect.name = "GroundTexture"
	ground_rect.z_index = -3
	ground_rect.stretch_mode = TextureRect.STRETCH_TILE
	add_child(ground_rect)
	
	# Tracks layer (z_index = -2)
	tracks_node = Node2D.new()
	tracks_node.name = "RailwayTracks"
	tracks_node.z_index = -2
	add_child(tracks_node)
	
	# Road lines layer (z_index = -2)
	road_lines_node = Node2D.new()
	road_lines_node.name = "RoadLines"
	road_lines_node.z_index = -2
	add_child(road_lines_node)
	
	# Navigation Region
	nav_region = NavigationRegion2D.new()
	nav_region.name = "ChunkNavRegion"
	add_child(nav_region)
	
	# Y-Sorted Props Node
	props_node = Node2D.new()
	props_node.name = "ChunkProps"
	props_node.y_sort_enabled = true
	add_child(props_node)
	
	# Ground Mist Layer (z_index = 1)
	mist_rect = ColorRect.new()
	mist_rect.name = "GroundMist"
	mist_rect.z_index = 1
	mist_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mist_shader = load("res://shaders/ground_mist.gdshader")
	if mist_shader:
		var mat = ShaderMaterial.new()
		mat.shader = mist_shader
		mist_rect.material = mat
	add_child(mist_rect)

func _process(delta: float) -> void:
	if hazard_lights.is_empty():
		return
	
	_flicker_phase += delta * 12.0
	for light in hazard_lights:
		if is_instance_valid(light):
			var flicker = sin(_flicker_phase + light.position.x * 0.05) * 0.15 + sin(_flicker_phase * 2.3) * 0.08
			if randf() < 0.015:
				light.energy = 0.45
			else:
				light.energy = clampf(1.05 + flicker, 0.7, 1.4)

## Initialize chunk with deterministic world-space coordinates
func setup_chunk(c: Vector2i, manager: Node) -> void:
	coord = c
	chunk_size_px = manager.CHUNK_PIXELS
	position = Vector2(coord.x * chunk_size_px, coord.y * chunk_size_px)
	
	ground_rect.size = Vector2(chunk_size_px, chunk_size_px)
	mist_rect.size = Vector2(chunk_size_px, chunk_size_px)
	
	# Reset pooled data
	recycle()
	
	# Classify Biome deterministically:
	# - Rail Corridors: dedicated continuous North-South tracks cutting through world
	# - Highway Corridors: continuous East-West major arterial highway with yellow lines & fences
	# - Wasteland: vast open cracked asphalt arena for horde combat
	if manager.is_rail_corridor(coord):
		biome = "railyard"
	elif manager.is_highway_corridor(coord):
		biome = "highway"
	else:
		biome = "wasteland"
	
	var solid_obstacle_rects: Array[Rect2] = []
	match biome:
		"highway":
			_build_highway_zone(manager, solid_obstacle_rects)
		"railyard":
			_build_railyard_zone(manager, solid_obstacle_rects)
		_:
			_build_wasteland_zone(manager, solid_obstacle_rects)
	
	# Build NavMesh Polygon with obstacle cutouts
	_build_navmesh(solid_obstacle_rects)

func _build_highway_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	ground_rect.texture = manager.tex_asphalt
	ground_rect.modulate = Color(0.85, 0.88, 0.92, 1.0)
	
	var mid_y = chunk_size_px * 0.5
	
	# 1. Continuous Double Yellow Road Lines across chunk (connects seamlessly X=0 to X=chunk_size_px)
	var line1 = Line2D.new()
	var line2 = Line2D.new()
	line1.width = 3.5
	line2.width = 3.5
	line1.default_color = Color(0.96, 0.82, 0.18, 0.85)
	line2.default_color = Color(0.96, 0.82, 0.18, 0.85)
	line1.add_point(Vector2(0, mid_y - 4))
	line1.add_point(Vector2(chunk_size_px, mid_y - 4))
	line2.add_point(Vector2(0, mid_y + 4))
	line2.add_point(Vector2(chunk_size_px, mid_y + 4))
	road_lines_node.add_child(line1)
	road_lines_node.add_child(line2)
	
	# 2. Roadside Chainlink Fence along northern shoulder (with occasional gaps every 3 chunks)
	if posmod(coord.x, 3) != 1:
		var fence_pos = Vector2(chunk_size_px * 0.5, mid_y - 125.0)
		if _can_spawn_at(fence_pos, manager):
			var fence = _create_fence(fence_pos, manager)
			props_node.add_child(fence)
			obstacles.append(Rect2(fence_pos - Vector2(110, 15), Vector2(220, 30)))
	
	# 3. Occasional burned military truck parked on shoulder
	if posmod(coord.x, 5) == 2:
		var truck_pos = Vector2(chunk_size_px * 0.68, mid_y + 115.0)
		if _can_spawn_at(truck_pos, manager):
			var truck = _create_vehicle_wreck(truck_pos, manager)
			props_node.add_child(truck)
			obstacles.append(Rect2(truck_pos - Vector2(75, 35), Vector2(150, 70)))
	
	# 4. Occasional roadside fuel drums or barricades
	if posmod(coord.x, 4) == 1:
		var drum_pos = Vector2(chunk_size_px * 0.25, mid_y + 105.0)
		if _can_spawn_at(drum_pos, manager):
			_spawn_barrel(drum_pos, manager)
	
	# 5. Warning hazard beacon near intersections
	if posmod(coord.x, 6) == 3:
		_spawn_hazard_light(Vector2(chunk_size_px * 0.5, mid_y - 60.0), manager)

func _build_railyard_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	ground_rect.texture = manager.tex_asphalt
	ground_rect.modulate = Color(0.82, 0.85, 0.88, 1.0)
	
	var mid_x = chunk_size_px * 0.5
	
	# 1. Dark Gravel Ballast Trackbed Strip running vertically through the chunk
	var ballast = TextureRect.new()
	ballast.texture = manager.tex_dirt
	ballast.stretch_mode = TextureRect.STRETCH_TILE
	ballast.size = Vector2(210.0, chunk_size_px)
	ballast.position = Vector2(mid_x - 105.0, 0.0)
	ballast.modulate = Color(0.68, 0.70, 0.74, 0.95)
	tracks_node.add_child(ballast)
	
	# 2. Single Continuous Vertical Steel Railway Track (connecting seamlessly Y=0 to Y=chunk_size_px)
	for i in range(3):
		var track = Sprite2D.new()
		track.texture = manager.tex_railway
		track.position = Vector2(mid_x, 128.0 + i * 256.0)
		track.scale = Vector2(0.82, 1.0)
		tracks_node.add_child(track)
	
	# 3. Horizontal Hazard Platform Crossing (placed periodically at depot stops or highway crossings)
	if posmod(coord.y, 3) == 0 or manager.is_highway_corridor(coord):
		var platform = Sprite2D.new()
		platform.texture = manager.tex_hazard
		platform.position = Vector2(mid_x, chunk_size_px * 0.5)
		platform.scale = Vector2(1.5, 0.75) # Width ~ 384, Height ~ 72
		tracks_node.add_child(platform)
		
		# Crate on the right of the platform (as shown in reference image)
		var crate_pos = Vector2(mid_x + 160.0, chunk_size_px * 0.55)
		if _can_spawn_at(crate_pos, manager):
			_spawn_crate(crate_pos, manager)
			obstacles.append(Rect2(crate_pos - Vector2(25, 25), Vector2(50, 50)))
		
		# Chainlink fence along bottom border (as shown in reference image)
		var fence_pos = Vector2(mid_x - 110.0, chunk_size_px - 35.0)
		if _can_spawn_at(fence_pos, manager):
			var fence = _create_fence(fence_pos, manager)
			props_node.add_child(fence)
			obstacles.append(Rect2(fence_pos - Vector2(110, 15), Vector2(220, 30)))
		
		# Amber warning beacon at depot station
		_spawn_hazard_light(Vector2(mid_x - 140.0, chunk_size_px * 0.5), manager)
	else:
		# Along open rail lines: occasional trackside crate or drum
		if posmod(coord.y, 4) == 1:
			var side_crate = Vector2(mid_x + 145.0, chunk_size_px * 0.4)
			if _can_spawn_at(side_crate, manager):
				_spawn_crate(side_crate, manager)
				obstacles.append(Rect2(side_crate - Vector2(25, 25), Vector2(50, 50)))

func _build_wasteland_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	# Vast, open apocalyptic asphalt arena for horde maneuvering
	ground_rect.texture = manager.tex_asphalt
	ground_rect.modulate = Color(0.86, 0.88, 0.92, 1.0)
	
	# Deterministic chunk hash for tactical prop placement
	var h = posmod(coord.x * 374761393 + coord.y * 668265263, 1000) / 1000.0
	
	# Concrete blast wall tactical cover (18% chance)
	if h > 0.82:
		var wall_pos = Vector2(chunk_size_px * 0.38, chunk_size_px * 0.62)
		if _can_spawn_at(wall_pos, manager):
			var is_vert = (posmod(coord.x, 2) == 1)
			var wall = _create_concrete_wall(wall_pos, is_vert, manager)
			props_node.add_child(wall)
			obstacles.append(Rect2(wall_pos - Vector2(110, 20), Vector2(220, 40)))
	
	# Supply Crates (22% chance)
	if h < 0.22:
		var crate_pos = Vector2(chunk_size_px * 0.72, chunk_size_px * 0.38)
		if _can_spawn_at(crate_pos, manager):
			_spawn_crate(crate_pos, manager)
			obstacles.append(Rect2(crate_pos - Vector2(25, 25), Vector2(50, 50)))
	
	# Fuel Barrels (16% chance)
	if h > 0.44 and h < 0.60:
		var barrel_pos = Vector2(chunk_size_px * 0.28, chunk_size_px * 0.32)
		if _can_spawn_at(barrel_pos, manager):
			_spawn_barrel(barrel_pos, manager)
	
	# Dead grass tufts (natural scattering)
	for i in range(4):
		var gx = posmod((coord.x * 19 + i * 137), int(chunk_size_px - 80)) + 40
		var gy = posmod((coord.y * 29 + i * 179), int(chunk_size_px - 80)) + 40
		var gpos = Vector2(gx, gy)
		if _can_spawn_at(gpos, manager) and manager.tex_grass:
			var grass = Sprite2D.new()
			grass.texture = manager.tex_grass
			grass.position = gpos
			grass.scale = Vector2(randf_range(0.9, 1.25), randf_range(0.9, 1.25))
			props_node.add_child(grass)
	
	# Oil slick puddle decal (15% chance)
	if h > 0.28 and h < 0.43 and manager.tex_oil_slick:
		var puddle_pos = Vector2(chunk_size_px * 0.52, chunk_size_px * 0.58)
		var puddle = Sprite2D.new()
		puddle.texture = manager.tex_oil_slick
		puddle.position = puddle_pos
		puddle.modulate = Color(0.22, 0.24, 0.28, 0.75)
		puddle.scale = Vector2(1.1, 0.85)
		puddle.z_index = -1
		add_child(puddle)
		_active_dynamic_props.append(puddle)

func _build_navmesh(obstacles: Array[Rect2]) -> void:
	var nav_poly = NavigationPolygon.new()
	# Outer boundary covering chunk (slightly expanded for solid edge connections)
	var boundary = PackedVector2Array([
		Vector2(-2.0, -2.0),
		Vector2(chunk_size_px + 2.0, -2.0),
		Vector2(chunk_size_px + 2.0, chunk_size_px + 2.0),
		Vector2(-2.0, chunk_size_px + 2.0)
	])
	
	var walkable_polys: Array[PackedVector2Array] = [boundary]
	
	# Cut holes for static obstacles
	for r in obstacles:
		var hole = PackedVector2Array([
			Vector2(r.position.x, r.position.y),
			Vector2(r.position.x + r.size.x, r.position.y),
			Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
			Vector2(r.position.x, r.position.y + r.size.y)
		])
		var next_polys: Array[PackedVector2Array] = []
		for p in walkable_polys:
			var clipped = Geometry2D.clip_polygons(p, hole)
			for cp in clipped:
				if cp.size() >= 3:
					next_polys.append(cp)
		if not next_polys.is_empty():
			walkable_polys = next_polys
	
	var all_vertices = PackedVector2Array()
	var vert_offset = 0
	for poly in walkable_polys:
		var tri_indices = Geometry2D.triangulate_polygon(poly)
		if tri_indices.is_empty():
			continue
		for v in poly:
			all_vertices.append(v)
		for i in range(0, tri_indices.size(), 3):
			nav_poly.add_polygon(PackedInt32Array([
				vert_offset + tri_indices[i],
				vert_offset + tri_indices[i + 1],
				vert_offset + tri_indices[i + 2]
			]))
		vert_offset += poly.size()
	
	nav_poly.vertices = all_vertices
	nav_region.navigation_polygon = nav_poly

func _can_spawn_at(local_pos: Vector2, manager: Node) -> bool:
	var global_pos = position + local_pos
	# Guarantee clear 6-unit clearance around player spawn origin (0, 0)
	return global_pos.length() >= manager.CLEARANCE_RADIUS_PIXELS

func _create_concrete_wall(pos: Vector2, is_vertical: bool, manager: Node) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 7
	
	var spr = Sprite2D.new()
	spr.texture = manager.tex_wall_v if is_vertical else manager.tex_wall_h
	body.add_child(spr)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(36, 220) if is_vertical else Vector2(220, 36)
	col.shape = shape
	body.add_child(col)
	return body

func _create_vehicle_wreck(pos: Vector2, manager: Node) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 7
	
	var spr = Sprite2D.new()
	spr.texture = manager.tex_truck
	spr.rotation = randf_range(-0.3, 0.3)
	body.add_child(spr)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(150, 65)
	col.shape = shape
	body.add_child(col)
	return body

func _create_fence(pos: Vector2, manager: Node) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 7
	
	var spr = Sprite2D.new()
	spr.texture = manager.tex_fence_h
	body.add_child(spr)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(220, 20)
	col.shape = shape
	body.add_child(col)
	return body

func _spawn_barrel(pos: Vector2, manager: Node) -> void:
	if manager.barrel_scene:
		var b = manager.barrel_scene.instantiate()
		b.position = pos
		props_node.add_child(b)

func _spawn_crate(pos: Vector2, manager: Node) -> Node:
	if manager.crate_scene:
		var c = manager.crate_scene.instantiate()
		c.position = pos
		props_node.add_child(c)
		return c
	return null

func _spawn_hazard_light(pos: Vector2, manager: Node) -> void:
	var light = PointLight2D.new()
	light.position = pos
	light.color = Color(1.0, 0.55, 0.15, 1.0) # Amber hazard light
	light.energy = 1.05
	light.texture = manager.tex_pointlight
	light.texture_scale = 1.8
	light.shadow_enabled = false
	add_child(light)
	hazard_lights.append(light)

## Clean up dynamic elements when chunk is pooled
func recycle() -> void:
	for child in road_lines_node.get_children():
		child.queue_free()
	for child in tracks_node.get_children():
		child.queue_free()
	for child in props_node.get_children():
		child.queue_free()
	for light in hazard_lights:
		if is_instance_valid(light):
			light.queue_free()
	hazard_lights.clear()
	for prop in _active_dynamic_props:
		if is_instance_valid(prop):
			prop.queue_free()
	_active_dynamic_props.clear()
