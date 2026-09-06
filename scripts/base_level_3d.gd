extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var camera: Camera3D = $IsometricCamera
@onready var player: CharacterBody3D = $Player3D
@onready var enemies_container: Node3D = $Enemies

const SHAMBLER_SCENE = preload("res://scenes/enemies/ShamblerZombie3D.tscn")
const HOUND_SCENE = preload("res://scenes/enemies/PlagueHound3D.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/ToxicSpitter3D.tscn")
const MUTANT_SCENE = preload("res://scenes/enemies/SuperMutant3D.tscn")

func _ready() -> void:
	print("[BASE LEVEL 3D] Initializing True 3D Isometric Level with PBR Shading & Volumetric Atmosphere...")
	if nav_region:
		call_deferred("_bake_navmesh")

func _bake_navmesh() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(false)
		print("[BASE LEVEL 3D] 3D NavigationMesh baked for AI horde traversal.")
	
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
		enemy.global_position = v["pos"]
		print("[BASE LEVEL 3D] Spawned Tiered 3D Zombie: ", v["name"], " at ", v["pos"])
