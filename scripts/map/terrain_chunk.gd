class_name TerrainChunk
extends Node2D

## Procedural Terrain Chunk for Infinite Chunk-Based Streaming
## Handles continuous world-space noise texturing, procedural POIs, local NavMesh, and pooling.

var coord: Vector2i = Vector2i.ZERO
var chunk_size_px: float = 768.0
var biome: String = "highway"

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
	
	# Road lines layer (z_index = -2)
	road_lines_node = Node2D.new()
	road_lines_node.name = "RoadLines"
	road_lines_node.z_index = -2
	add_child(road_lines_node)
	
	# Tracks layer (z_index = -2)
	tracks_node = Node2D.new()
	tracks_node.name = "RailwayTracks"
	tracks_node.z_index = -2
	add_child(tracks_node)
	
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
	
	# Continuous World-Space Noise Sample
	# (chunk_coord * CHUNK_SIZE + local_coord) ensures zero visual seams across chunk borders
	var world_center_x = (float(coord.x) + 0.5) * manager.CHUNK_SIZE
	var world_center_y = (float(coord.y) + 0.5) * manager.CHUNK_SIZE
	
	var biome_val = manager.biome_noise.get_noise_2d(world_center_x * 0.35, world_center_y * 0.35)
	
	# Assign Biome based on smooth continuous noise
	if biome_val < -0.10:
		biome = "marsh"
	elif biome_val > 0.14:
		biome = "railyard"
	else:
		biome = "highway"
	
	# Build Biome Visuals and Obstacles
	var solid_obstacle_rects: Array[Rect2] = []
	match biome:
		"highway":
			_build_highway_zone(manager, solid_obstacle_rects)
		"marsh":
			_build_marsh_zone(manager, solid_obstacle_rects)
		"railyard":
			_build_railyard_zone(manager, solid_obstacle_rects)
	
	# Build NavMesh Polygon with obstacle cutouts
	_build_navmesh(solid_obstacle_rects)

func _build_highway_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	ground_rect.texture = manager.tex_asphalt
	ground_rect.modulate = Color(0.92, 0.94, 0.96, 1.0)
	
	# Continuous Highway Direction: Horizontal or Vertical band based on road noise
	var road_val = manager.road_noise.get_noise_2d(coord.x * 2.0, coord.y * 2.0)
	var is_horizontal_road = abs(road_val) < 0.25
	
	# Draw Faded Double Yellow Road Lines across the chunk
	var line1 = Line2D.new()
	var line2 = Line2D.new()
	line1.width = 4.0
	line2.width = 4.0
	line1.default_color = Color(0.85, 0.72, 0.18, 0.65) # Faded yellow
	line2.default_color = Color(0.85, 0.72, 0.18, 0.65)
	
	if is_horizontal_road:
		var mid_y = chunk_size_px * 0.5
		line1.add_point(Vector2(0, mid_y - 4))
		line1.add_point(Vector2(chunk_size_px, mid_y - 4))
		line2.add_point(Vector2(0, mid_y + 4))
		line2.add_point(Vector2(chunk_size_px, mid_y + 4))
	else:
		var mid_x = chunk_size_px * 0.5
		line1.add_point(Vector2(mid_x - 4, 0))
		line1.add_point(Vector2(mid_x - 4, chunk_size_px))
		line2.add_point(Vector2(mid_x + 4, 0))
		line2.add_point(Vector2(mid_x + 4, chunk_size_px))
	
	road_lines_node.add_child(line1)
	road_lines_node.add_child(line2)
	
	# Road Props & POIs
	var prop_val = manager.prop_noise.get_noise_2d(coord.x * 5.0, coord.y * 5.0)
	
	# Concrete road divider
	if prop_val > 0.05:
		var div_pos = Vector2(chunk_size_px * 0.35, chunk_size_px * 0.65)
		if _can_spawn_at(div_pos, manager):
			var wall = _create_concrete_wall(div_pos, not is_horizontal_road, manager)
			props_node.add_child(wall)
			obstacles.append(Rect2(div_pos - Vector2(100, 20), Vector2(200, 40)))
	
	# Burned-out vehicle wreck
	if prop_val > 0.18:
		var truck_pos = Vector2(chunk_size_px * 0.68, chunk_size_px * 0.32)
		if _can_spawn_at(truck_pos, manager):
			var truck = _create_vehicle_wreck(truck_pos, manager)
			props_node.add_child(truck)
			obstacles.append(Rect2(truck_pos - Vector2(75, 35), Vector2(150, 70)))
	
	# Rusted oil drums
	if prop_val < -0.12:
		var drum_pos = Vector2(chunk_size_px * 0.22, chunk_size_px * 0.25)
		if _can_spawn_at(drum_pos, manager):
			_spawn_barrel(drum_pos, manager)
	
	# Flickering orange hazard light near road junctions
	if abs(road_val) < 0.12:
		var light_pos = Vector2(chunk_size_px * 0.5, chunk_size_px * 0.5)
		_spawn_hazard_light(light_pos, manager)

func _build_marsh_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	ground_rect.texture = manager.tex_dirt
	ground_rect.modulate = Color(0.72, 0.76, 0.68, 1.0) # Muddy dark peat
	
	var seed_x = coord.x * 17
	var seed_y = coord.y * 31
	
	# Dead tall grass tufts
	for i in range(5):
		var gx = fposmod(seed_x * (i + 1) * 73, int(chunk_size_px - 80)) + 40
		var gy = fposmod(seed_y * (i + 1) * 97, int(chunk_size_px - 80)) + 40
		var gpos = Vector2(gx, gy)
		if _can_spawn_at(gpos, manager):
			var grass = Sprite2D.new()
			grass.texture = manager.tex_grass
			grass.position = gpos
			grass.scale = Vector2(randf_range(0.9, 1.3), randf_range(0.9, 1.3))
			props_node.add_child(grass)
	
	# Glossy Puddle Decal
	var puddle_pos = Vector2(chunk_size_px * 0.45, chunk_size_px * 0.55)
	if manager.tex_oil_slick:
		var puddle = Sprite2D.new()
		puddle.texture = manager.tex_oil_slick
		puddle.position = puddle_pos
		puddle.modulate = Color(0.25, 0.35, 0.3, 0.85) # Glossy peat reflection
		puddle.scale = Vector2(1.2, 0.9)
		puddle.z_index = -1
		add_child(puddle)
		_active_dynamic_props.append(puddle)
	
	# Broken wooden walkways
	var walkway_pos = Vector2(chunk_size_px * 0.65, chunk_size_px * 0.7)
	if _can_spawn_at(walkway_pos, manager):
		var crate = _spawn_crate(walkway_pos, manager)
		obstacles.append(Rect2(walkway_pos - Vector2(25, 25), Vector2(50, 50)))

func _build_railyard_zone(manager: Node, obstacles: Array[Rect2]) -> void:
	ground_rect.texture = manager.tex_dirt
	ground_rect.modulate = Color(0.58, 0.60, 0.64, 1.0) # Gravel ballast corridor
	
	# Interlocking rusted steel tracks across the chunk
	var num_tracks = 3
	var spacing = chunk_size_px / float(num_tracks + 1)
	for i in range(num_tracks):
		var ty = spacing * (i + 1)
		var track = Sprite2D.new()
		track.texture = manager.tex_railway
		track.position = Vector2(chunk_size_px * 0.5, ty)
		track.scale = Vector2(chunk_size_px / 256.0, 1.0)
		tracks_node.add_child(track)
	
	# Hazard Platform Border
	var platform = Sprite2D.new()
	platform.texture = manager.tex_hazard
	platform.position = Vector2(chunk_size_px * 0.5, spacing)
	platform.scale = Vector2(chunk_size_px / 256.0, 0.7)
	tracks_node.add_child(platform)
	
	# Military barricades & chainlink fences
	var fence_pos = Vector2(chunk_size_px * 0.3, chunk_size_px * 0.65)
	if _can_spawn_at(fence_pos, manager):
		var fence = _create_fence(fence_pos, manager)
		props_node.add_child(fence)
		obstacles.append(Rect2(fence_pos - Vector2(110, 15), Vector2(220, 30)))
	
	# Derailed freight train crates
	var crate_pos = Vector2(chunk_size_px * 0.75, chunk_size_px * 0.4)
	if _can_spawn_at(crate_pos, manager):
		_spawn_crate(crate_pos, manager)
		obstacles.append(Rect2(crate_pos - Vector2(25, 25), Vector2(50, 50)))
	
	# Flickering railyard warning beacon
	var beacon_pos = Vector2(chunk_size_px * 0.75, spacing)
	_spawn_hazard_light(beacon_pos, manager)

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
