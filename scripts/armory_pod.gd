class_name ArmoryPod
extends Area2D

## Field Armory Drop Pod Station
## Automatically deploys every 3 waves or when clearing major waves.
## Features an amber flashing beacon light, pneumatic steam exhaust vents,
## and hold [E] interaction that releases a mechanical hiss to open the Armory Vendor Menu.

enum PodState { DESCENDING, LANDED, OPENED }

@export var descent_duration: float = 2.4
@export var initial_height: float = 400.0
@export var interaction_radius: float = 75.0
@export var hold_duration_required: float = 0.45

var current_state: PodState = PodState.DESCENDING
var descent_timer: float = 0.0
var player_in_range: bool = false
var hold_timer: float = 0.0
var beacon_timer: float = 0.0

@onready var visual_node: Node2D = $Visual
@onready var pod_sprite: Sprite2D = $Visual/PodSprite
@onready var beacon_light: PointLight2D = $Visual/BeaconLight
@onready var steam_particles: CPUParticles2D = $Visual/SteamVent
@onready var ground_shadow: Sprite2D = $GroundShadow
@onready var prompt_container: Control = $PromptContainer
@onready var prompt_label: Label = $PromptContainer/VBox/PromptLabel
@onready var progress_bar: ProgressBar = $PromptContainer/VBox/ProgressBar

func _ready() -> void:
	add_to_group("armory_pods")
	add_to_group("interactables")
	collision_layer = 0
	collision_mask = 1 # Player layer
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_container:
		prompt_container.visible = false
	if progress_bar:
		progress_bar.max_value = hold_duration_required
		progress_bar.value = 0.0
	
	current_state = PodState.DESCENDING
	descent_timer = 0.0
	
	# Initial drop thruster sound
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("aircraft_flyby", global_position)
	else:
		Global.play_sound("wave_start", global_position)

func _process(delta: float) -> void:
	match current_state:
		PodState.DESCENDING:
			descent_timer += delta
			var progress = clampf(descent_timer / descent_duration, 0.0, 1.0)
			var h = lerpf(initial_height, 0.0, ease(progress, 0.4))
			
			if visual_node:
				visual_node.position.y = -h
			
			if ground_shadow:
				var s = lerpf(0.3, 1.0, progress)
				ground_shadow.scale = Vector2(s, s * 0.45)
				ground_shadow.modulate.a = lerpf(0.15, 0.75, progress)
			
			if progress >= 1.0:
				_on_pod_landed()
		
		PodState.LANDED, PodState.OPENED:
			# Flashing amber beacon cycle
			beacon_timer += delta * 3.5
			if beacon_light:
				var flash = (sin(beacon_timer) + 1.0) * 0.5
				beacon_light.energy = 0.8 + pow(flash, 3.0) * 2.4
			
			# Prompt visual pulse
			if prompt_container and prompt_container.visible:
				var pulse = 0.94 + sin(Time.get_ticks_msec() * 0.008) * 0.06
				prompt_container.scale = Vector2(pulse, pulse)
			
			# Hold [E] interaction check
			if player_in_range and not Global.is_game_over:
				if Input.is_key_pressed(KEY_E):
					hold_timer += delta
					if progress_bar:
						progress_bar.value = hold_timer
					
					if hold_timer >= hold_duration_required:
						hold_timer = 0.0
						if progress_bar:
							progress_bar.value = 0.0
						open_armory()
				else:
					if hold_timer > 0.0:
						hold_timer = max(0.0, hold_timer - delta * 2.0)
						if progress_bar:
							progress_bar.value = hold_timer

func _on_pod_landed() -> void:
	current_state = PodState.LANDED
	if visual_node:
		visual_node.position = Vector2.ZERO
	
	# Heavy mechanical impact audio
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("stomp_crash", global_position)
	else:
		Global.play_sound("explode", global_position)
	
	# Ground dust shockwave
	var level = get_tree().current_scene
	if level:
		var dust = CPUParticles2D.new()
		dust.emitting = true
		dust.one_shot = true
		dust.explosiveness = 0.95
		dust.amount = 30
		dust.lifetime = 0.6
		dust.spread = 180.0
		dust.initial_velocity_min = 90.0
		dust.initial_velocity_max = 220.0
		dust.scale_amount_min = 4.0
		dust.scale_amount_max = 8.0
		dust.color = Color(0.45, 0.42, 0.38, 0.75)
		dust.global_position = global_position
		dust.finished.connect(dust.queue_free)
		level.add_child(dust)
	
	# Initial steam release
	trigger_mechanical_hiss()
	
	# Check if player was already on LZ
	var overlapping = get_overlapping_bodies()
	for b in overlapping:
		if b.is_in_group("player"):
			player_in_range = true
			if prompt_container:
				prompt_container.visible = true
			break

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if current_state != PodState.DESCENDING and prompt_container:
			prompt_container.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		hold_timer = 0.0
		if progress_bar:
			progress_bar.value = 0.0
		if prompt_container:
			prompt_container.visible = false

func trigger_mechanical_hiss() -> void:
	# Steam vent particle blast
	if steam_particles:
		steam_particles.restart()
		steam_particles.emitting = true
	
	# Mechanical hiss sound
	Global.play_sound("flame_start", global_position)

func open_armory() -> void:
	current_state = PodState.OPENED
	trigger_mechanical_hiss()
	Global.play_sound("perk", global_position)
	
	# Open tactical vendor UI via EconomyManager
	if EconomyManager:
		EconomyManager.open_armory_ui()
