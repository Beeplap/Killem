extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var camera: Camera3D = $IsometricCamera
@onready var player: CharacterBody3D = $Player3D

func _ready() -> void:
	print("[BASE LEVEL 3D] Initializing True 3D Isometric Level with PBR Shading & Volumetric Atmosphere...")
	if nav_region:
		call_deferred("_bake_navmesh")

func _bake_navmesh() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(false)
		print("[BASE LEVEL 3D] 3D NavigationMesh baked for AI horde traversal.")
