extends Node2D

@onready var bunker_light: PointLight2D = get_node_or_null("EnvironmentObjects/BunkerBuilding/BunkerLamp")
@onready var yard_light_1: PointLight2D = get_node_or_null("Lighting/YardFloodlight1")
@onready var yard_light_2: PointLight2D = get_node_or_null("Lighting/YardFloodlight2")
@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $ZombieSpawner
@onready var post_process_rect: ColorRect = get_node_or_null("PostProcessLayer/PostProcessRect")

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
