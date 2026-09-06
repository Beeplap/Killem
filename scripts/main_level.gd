extends Node2D

@onready var bunker_light: PointLight2D = get_node_or_null("EnvironmentObjects/BunkerBuilding/BunkerLamp")
@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $ZombieSpawner

var flicker_time: float = 0.0

func _ready() -> void:
	# Ensure Y-sort is active for 2.5D visual depth
	y_sort_enabled = true
	apply_procedural_textures()

func apply_procedural_textures() -> void:
	# 1. Ground / Ballast repeating noise texture (512x512 Simplex freq 0.05 + gravel grain)
	var dirt_bg: TextureRect = get_node_or_null("GroundLayers/DirtBackground")
	if dirt_bg:
		dirt_bg.texture = ProceduralTextures.get_ground_texture()
		dirt_bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# 2. Concrete wall vertical streaks & edge grunge
	var wall_tex = ProceduralTextures.get_concrete_wall_texture()
	var wall1 = get_node_or_null("EnvironmentObjects/ConcreteWall1/Sprite2D")
	if wall1:
		wall1.texture = wall_tex
	var wall2 = get_node_or_null("EnvironmentObjects/ConcreteWall2/Sprite2D")
	if wall2:
		wall2.texture = wall_tex
	
	# 3. Metal rail edge highlights and rust mottling (#8b4513 specs)
	var rail_tex = ProceduralTextures.get_metal_rail_texture()
	var tracks = get_node_or_null("GroundLayers/RailwayTracks")
	if tracks:
		for child in tracks.get_children():
			if child is Sprite2D and child.name.begins_with("Track"):
				child.texture = rail_tex

func _process(delta: float) -> void:
	if bunker_light:
		flicker_time += delta * 14.0
		# Atmospheric sodium floodlight humming flicker
		var flicker = sin(flicker_time) * 0.06 + sin(flicker_time * 2.7) * 0.04
		if randf() < 0.008:
			bunker_light.energy = 0.45 # Voltage drop flicker
		else:
			bunker_light.energy = lerp(bunker_light.energy, 1.55 + flicker, delta * 10.0)
