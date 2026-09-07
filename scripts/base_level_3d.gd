extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var camera: Camera3D = $IsometricCamera
@onready var player: CharacterBody3D = $Player3D
@onready var enemies_container: Node3D = $Enemies
@onready var terrain: Terrain3D = get_node_or_null("NavigationRegion3D/Terrain3D")

const SHAMBLER_SCENE = preload("res://scenes/enemies/ShamblerZombie3D.tscn")
const HOUND_SCENE = preload("res://scenes/enemies/PlagueHound3D.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/ToxicSpitter3D.tscn")
const MUTANT_SCENE = preload("res://scenes/enemies/SuperMutant3D.tscn")

func _ready() -> void:
	print("[BASE LEVEL 3D] Initializing True 3D Isometric Level with Terrain3D PBR Shading & Volumetric Atmosphere...")
	if terrain and camera:
		terrain.set_camera(camera)
		_setup_terrain_and_foliage()
	setup_mission_infrastructure()
	if nav_region:
		call_deferred("_bake_navmesh")

func setup_mission_infrastructure() -> void:
	# 1. MissionManager
	var mm_script = load("res://scripts/mission_manager.gd")
	var mission_manager = Node.new()
	mission_manager.name = "MissionManager"
	if mm_script:
		mission_manager.set_script(mm_script)
	mission_manager.add_to_group("mission_manager")
	add_child(mission_manager)
	
	# 2. ObjectiveTrackerHUD (Programmatic CanvasLayer)
	var hud_script = load("res://scripts/objective_tracker_hud.gd")
	var hud = CanvasLayer.new()
	hud.name = "ObjectiveTrackerHUD"
	if hud_script:
		hud.set_script(hud_script)
	add_child(hud)
	
	# 3. Register campaign objectives
	if mission_manager.has_method("add_objective"):
		mission_manager.add_objective(
			"find_keycard",
			"Locate Yellow Security Keycard",
			"Search the railway yard depot to find the perimeter security keycard.",
			"keycard_hunt"
		)
		mission_manager.add_objective(
			"open_blast_door",
			"Override Perimeter Blast Door",
			"Insert the yellow keycard into the blast gate control terminal.",
			"keycard_hunt"
		)
		mission_manager.add_objective(
			"defend_generator",
			"Restore Auxiliary Power",
			"Insert fuel cell and defend generator during 45s horde siege.",
			"generator_defense"
		)
		mission_manager.add_objective(
			"extract_data",
			"Survivor Data Extraction",
			"Hack the military terminal and clear room-by-room breaches.",
			"data_extraction"
		)
	
	if mission_manager.has_signal("all_objectives_complete"):
		mission_manager.all_objectives_complete.connect(_on_all_objectives_complete)
	
	# Objective A: Keycard Pickup
	var keycard_scene = preload("res://scenes/interactables/KeycardPickup3D.tscn")
	if keycard_scene:
		var keycard = keycard_scene.instantiate()
		keycard.name = "YellowKeycard"
		add_child(keycard)
		keycard.global_position = Vector3(14, 0.4, -8)
	
	Global.keycard_collected.connect(_on_keycard_collected)
	
	# Objective A Gate: Perimeter Blast Door
	var door_scene = preload("res://scenes/interactables/BlastDoor3D.tscn")
	if door_scene:
		var door = door_scene.instantiate()
		door.name = "BlastDoor"
		add_child(door)
		door.global_position = Vector3(0, 0, -14)
		if door.has_signal("door_opened"):
			door.door_opened.connect(_on_blast_door_opened)
	
	# Objective B: Power Generator Defense
	var gen_scene = preload("res://scenes/interactables/GeneratorDefense3D.tscn")
	if gen_scene:
		var gen = gen_scene.instantiate()
		gen.name = "Generator"
		add_child(gen)
		gen.global_position = Vector3(-12, 0, 8)
		if gen.has_signal("defense_progress"):
			gen.defense_progress.connect(func(prog: float):
				var mm = _get_mission_manager()
				if mm: mm.update_progress("defend_generator", prog)
			)
		if gen.has_signal("generator_defense_wave"):
			gen.generator_defense_wave.connect(_on_generator_siege_wave)
		if gen.has_signal("defense_completed"):
			gen.defense_completed.connect(_on_generator_defended)
	
	# Objective C: Survivor Data Extraction Terminal
	var term_scene = preload("res://scenes/interactables/DataTerminal3D.tscn")
	if term_scene:
		var terminal = term_scene.instantiate()
		terminal.name = "DataTerminal"
		add_child(terminal)
		terminal.global_position = Vector3(12, 0, 10)
		if terminal.has_signal("hack_progress"):
			terminal.hack_progress.connect(func(prog: float):
				var mm = _get_mission_manager()
				if mm: mm.update_progress("extract_data", prog)
			)
		if terminal.has_signal("room_breach_triggered"):
			terminal.room_breach_triggered.connect(_on_terminal_room_breach)
		if terminal.has_signal("terminal_hacked"):
			terminal.terminal_hacked.connect(_on_terminal_data_extracted)

func _get_mission_manager() -> Node:
	var managers = get_tree().get_nodes_in_group("mission_manager")
	return managers[0] if managers.size() > 0 else null

func _on_keycard_collected(color: String) -> void:
	var mm = _get_mission_manager()
	if mm and mm.has_method("complete_objective"):
		mm.complete_objective("find_keycard")
	print("[MISSION] Objective Complete: find_keycard (", color, " keycard collected)")

func _on_blast_door_opened() -> void:
	var mm = _get_mission_manager()
	if mm and mm.has_method("complete_objective"):
		mm.complete_objective("open_blast_door")
	print("[MISSION] Objective Complete: open_blast_door")

func _on_generator_defended() -> void:
	var mm = _get_mission_manager()
	if mm and mm.has_method("complete_objective"):
		mm.complete_objective("defend_generator")
	print("[MISSION] Objective Complete: defend_generator (Power Restored)")

func _on_generator_siege_wave(wave_index: int) -> void:
	print("[MISSION] Generator Siege Wave ", wave_index, " attacking!")
	var spawn_points = [
		Vector3(-18.0, 0.1, 12.0),
		Vector3(-6.0, 0.1, 14.0),
		Vector3(-14.0, 0.1, 2.0)
	]
	for p in spawn_points:
		var scene = HOUND_SCENE if randf() < 0.4 else SHAMBLER_SCENE
		var enemy = scene.instantiate()
		if enemies_container:
			enemies_container.add_child(enemy)
		else:
			add_child(enemy)
		enemy.global_position = p

func _on_terminal_room_breach() -> void:
	print("[MISSION] Data Terminal Room Breach triggered!")
	var breach_points = [
		Vector3(16.0, 0.1, 6.0),
		Vector3(8.0, 0.1, 14.0),
		Vector3(18.0, 0.1, 12.0)
	]
	for p in breach_points:
		var enemy = (SPITTER_SCENE if randf() < 0.35 else SHAMBLER_SCENE).instantiate()
		if enemies_container:
			enemies_container.add_child(enemy)
		else:
			add_child(enemy)
		enemy.global_position = p

func _on_terminal_data_extracted() -> void:
	var mm = _get_mission_manager()
	if mm and mm.has_method("complete_objective"):
		mm.complete_objective("extract_data")
	print("[MISSION] Objective Complete: extract_data (Blackbox extracted)")

func _on_all_objectives_complete() -> void:
	print("[MISSION] ★★★ ALL CAMPAIGN OBJECTIVES COMPLETED! ★★★")
	Global.play_sound("wave_clear")
	Global.score += 2500
	Global.score_changed.emit(Global.score, Global.kills)

func _setup_terrain_and_foliage() -> void:
	if not terrain:
		return
	
	if terrain.material:
		terrain.material.world_background = Terrain3DMaterial.NONE
		terrain.material.auto_shader = true
		terrain.material.dual_scaling = true
	
	# Populate procedural heightmap if not already imported
	if terrain.data and terrain.data.get_region_count() == 0:
		var noise = FastNoiseLite.new()
		noise.seed = 2026
		noise.frequency = 0.012
		var img: Image = Image.create_empty(512, 512, false, Image.FORMAT_RF)
		for x in range(512):
			for y in range(512):
				var n = noise.get_noise_2d(x, y)
				var dx = float(x - 256)
				var dy = float(y - 256)
				var dist = sqrt(dx * dx + dy * dy)
				# Smooth flat combat clearing in center (radius 36m), undulating terrain beyond
				var factor = clampf((dist - 36.0) / 85.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(n * factor, 0.0, 0.0, 1.0))
		terrain.region_size = 256
		terrain.data.import_images([img, null, null], Vector3(-256, 0, -256), 0.0, 4.5)
		print("[BASE LEVEL 3D] Imported Terrain3D heightmap with tactical central combat clearing and undulating trenches.")
	
	# Configure Foliage & Debris Instancing across playable area with zero draw-call overhead
	if terrain.instancer and terrain.data:
		var grass_xforms: Array[Transform3D] = []
		var rock_xforms: Array[Transform3D] = []
		var debris_xforms: Array[Transform3D] = []
		
		# 1. Dead grass clumps (Slot 0)
		for i in range(45):
			var rx = randf_range(-28.0, 28.0)
			var rz = randf_range(-28.0, 28.0)
			var pos = Vector3(rx, 0.0, rz)
			pos.y = terrain.data.get_height(pos)
			if not is_nan(pos.y):
				var s = randf_range(0.7, 1.3)
				var rot_y = randf_range(0.0, TAU)
				var basis = Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
				grass_xforms.append(Transform3D(basis, pos))
		
		# 2. Small rocks (Slot 1) along perimeter slopes
		for i in range(20):
			var angle = randf() * TAU
			var dist = randf_range(18.0, 34.0)
			var pos = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			pos.y = terrain.data.get_height(pos)
			if not is_nan(pos.y):
				var s = randf_range(0.4, 0.85)
				var rot_y = randf_range(0.0, TAU)
				var basis = Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s))
				rock_xforms.append(Transform3D(basis, pos))
		
		# 3. Debris tufts / wooden pallets (Slot 2)
		for i in range(10):
			var pos = Vector3(randf_range(3.0, 18.0), 0.0, randf_range(-16.0, 14.0))
			pos.y = terrain.data.get_height(pos)
			if not is_nan(pos.y):
				var rot_y = randf_range(-0.6, 0.6)
				debris_xforms.append(Transform3D(Basis(Vector3.UP, rot_y), pos))
		
		terrain.instancer.add_transforms(0, grass_xforms)
		terrain.instancer.add_transforms(1, rock_xforms)
		terrain.instancer.add_transforms(2, debris_xforms)
		print("[BASE LEVEL 3D] Instanced Foliage & Debris: ", grass_xforms.size(), " grass clumps, ", rock_xforms.size(), " rocks, ", debris_xforms.size(), " debris tufts.")

func _bake_navmesh() -> void:
	if nav_region and nav_region.navigation_mesh:
		var nav_mesh = nav_region.navigation_mesh
		var source_geom = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geom, self)
		
		if terrain:
			var aabb = AABB(Vector3(-70, -10, -70), Vector3(140, 20, 140))
			var faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(aabb, false)
			if not faces.is_empty():
				source_geom.add_faces(faces, Transform3D.IDENTITY)
		
		NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geom)
		nav_region.navigation_mesh = nav_mesh
		print("[BASE LEVEL 3D] 3D NavigationMesh baked with Terrain3D slopes and obstacle cutouts. Polygons: ", nav_mesh.get_polygon_count())
	
	spawn_tier_hierarchy()

func spawn_tier_hierarchy() -> void:
	var variants = [
		{"scene": SHAMBLER_SCENE, "name": "ShamblerZombie3D", "pos": Vector3(-6.0, 0.1, -8.0)},
		{"scene": HOUND_SCENE, "name": "PlagueHound3D", "pos": Vector3(7.0, 0.1, -9.0)},
		{"scene": SPITTER_SCENE, "name": "ToxicSpitter3D", "pos": Vector3(-10.0, 0.1, 5.0)},
		{"scene": MUTANT_SCENE, "name": "SuperMutant3D", "pos": Vector3(8.0, 0.1, 8.0)}
	]
	
	for v in variants:
		var enemy = v["scene"].instantiate()
		enemy.name = v["name"]
		if enemies_container:
			enemies_container.add_child(enemy)
		else:
			add_child(enemy)
		var spawn_pos: Vector3 = v["pos"]
		if terrain and terrain.data:
			var h = terrain.data.get_height(spawn_pos)
			if not is_nan(h):
				spawn_pos.y = h + 0.05
		enemy.global_position = spawn_pos
		print("[BASE LEVEL 3D] Spawned Tiered 3D Zombie: ", v["name"], " at ", enemy.global_position)
