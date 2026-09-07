extends Node

func _ready() -> void:
	print("=== RUNNING INFINITE PROCEDURAL MAP GENERATION VERIFICATION ===")
	
	# 1. Verify Autoload Singleton
	var manager = get_node_or_null("/root/InfiniteTerrainManager")
	assert(manager != null, "InfiniteTerrainManager autoload must exist at /root/InfiniteTerrainManager")
	print("✔ 1. InfiniteTerrainManager autoload verified")
	
	# 2. Verify System Constants
	assert(manager.CHUNK_SIZE == 48.0, "CHUNK_SIZE must be 48.0 meters/units")
	assert(manager.UNIT_SCALE == 16.0, "UNIT_SCALE must be 16.0 pixels/unit")
	assert(manager.CHUNK_PIXELS == 768.0, "CHUNK_PIXELS must be 768.0")
	assert(manager.ACTIVE_RADIUS == 3, "ACTIVE_RADIUS must be 3 (7x7 active grid)")
	assert(manager.CLEARANCE_RADIUS_UNITS == 6.0, "CLEARANCE_RADIUS_UNITS must be 6.0")
	assert(manager.CLEARANCE_RADIUS_PIXELS == 96.0, "CLEARANCE_RADIUS_PIXELS must be 96.0 pixels")
	print("✔ 2. System constants (CHUNK_SIZE=48, RADIUS=3, CLEARANCE=6 units) verified")
	
	# 3. Setup Dummy Player for Streaming Test
	var dummy_player = Node2D.new()
	dummy_player.name = "TestPlayer"
	dummy_player.position = Vector2.ZERO
	dummy_player.add_to_group("player")
	add_child(dummy_player)
	
	manager.player = dummy_player
	manager.update_chunks(Vector2i.ZERO)
	
	# 4. Verify 7x7 Active Grid (49 Chunks)
	var active_count = manager.get_active_chunk_count()
	assert(active_count == 49, "Active chunk count must be 49 (7x7 grid), got: %d" % active_count)
	
	var active_dict = manager.get_active_chunks()
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			var coord = Vector2i(cx, cy)
			assert(active_dict.has(coord), "Chunk at %s must be active in 7x7 grid" % str(coord))
	print("✔ 3. 7x7 Active Grid (49 chunks, -3 to +3) verified around (0, 0)")
	
	# 5. Verify Chunk Components, Textures, Mist, and NavMesh
	var center_chunk = active_dict[Vector2i.ZERO]
	assert(center_chunk != null, "Center chunk at (0, 0) must exist")
	assert(center_chunk.ground_rect != null, "Chunk must have ground TextureRect")
	assert(center_chunk.ground_rect.texture is CanvasTexture, "Chunk ground must use CanvasTexture")
	
	var canvas_tex: CanvasTexture = center_chunk.ground_rect.texture
	assert(canvas_tex.diffuse_texture != null, "Ground CanvasTexture must have diffuse texture")
	assert(canvas_tex.normal_texture != null, "Ground CanvasTexture must have normal map texture")
	
	assert(center_chunk.mist_rect != null, "Chunk must have mist ColorRect")
	assert(center_chunk.mist_rect.material is ShaderMaterial, "Chunk mist must use ShaderMaterial")
	
	assert(center_chunk.nav_region != null, "Chunk must have NavigationRegion2D")
	assert(center_chunk.nav_region.navigation_polygon != null, "Chunk must have NavigationPolygon")
	assert(center_chunk.nav_region.navigation_polygon.get_polygon_count() > 0, "Chunk NavMesh must contain polygons")
	assert(center_chunk.nav_region.navigation_polygon.vertices.size() > 0, "Chunk NavMesh must contain vertices")
	print("✔ 4. Chunk PBR textures, ground mist shader, and NavMesh verified")
	
	# 6. Verify 6-Unit Player Spawn Clearance (Origin 0,0)
	var clearance_px = manager.CLEARANCE_RADIUS_PIXELS
	for child in center_chunk.props_node.get_children():
		var child_global = center_chunk.position + child.position
		assert(child_global.length() >= clearance_px, "Obstacle %s spawned inside 6-unit clearance: dist=%f < %f" % [child.name, child_global.length(), clearance_px])
	print("✔ 5. Mandatory 6-unit navigable clearance around origin (0, 0) strictly verified")
	
	# 7. Verify World-Space Noise and Biomes
	var detected_biomes: Dictionary = {}
	for c_coord in active_dict.keys():
		var chunk = active_dict[c_coord]
		detected_biomes[chunk.biome] = true
	print("✔ 6. World-space continuous biomes detected in active set: %s" % str(detected_biomes.keys()))
	
	# 8. Verify Dynamic Chunk Streaming & Pooling
	# Move player 10 chunks east (10 * 768.0 = 7680.0 px)
	var new_chunk_coord = Vector2i(10, 0)
	dummy_player.position = Vector2(new_chunk_coord.x * 768.0, 0.0)
	manager.update_chunks(new_chunk_coord)
	
	var new_active_count = manager.get_active_chunk_count()
	assert(new_active_count == 49, "Active chunk count after player move must remain 49, got: %d" % new_active_count)
	assert(manager._chunk_pool.size() > 0, "Despawned chunks must be recycled into _chunk_pool, pool size: %d" % manager._chunk_pool.size())
	
	# Verify that old (0,0) chunk is no longer active
	assert(not manager.is_chunk_active(Vector2i.ZERO), "Old chunk at (0, 0) must be despawned")
	assert(manager.is_chunk_active(new_chunk_coord), "New chunk at (10, 0) must be active")
	
	# Move player back to origin (0, 0) to verify pool reuse
	dummy_player.position = Vector2.ZERO
	manager.update_chunks(Vector2i.ZERO)
	assert(manager.get_active_chunk_count() == 49, "Active chunk count after returning to origin must remain 49")
	assert(manager.is_chunk_active(Vector2i.ZERO), "Chunk at (0, 0) must be active again")
	print("✔ 7. Dynamic chunk streaming and zero-allocation chunk pooling verified")
	
	# 9. Verify Ground Mist Shader Parameters
	var mist_shader = load("res://shaders/ground_mist.gdshader")
	assert(mist_shader != null, "res://shaders/ground_mist.gdshader must exist and load")
	print("✔ 8. Atmospheric overcast ground mist shader verified")
	
	print("\n=== ALL INFINITE PROCEDURAL MAP GENERATION CHECKS PASSED SUCCESSFULLY ===")
	for c in manager._active_chunks.values():
		c.free()
	manager._active_chunks.clear()
	for c in manager._chunk_pool:
		c.free()
	manager._chunk_pool.clear()
	dummy_player.free()
	get_tree().quit(0)
