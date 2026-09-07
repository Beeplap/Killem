class_name SupplyDrop
extends Area2D

## 30-Second Tactical Supply Drop
## Handles military aircraft flyby audio, LZ red smoke flare, parachute descent animation,
## and player [E] interaction granting trauma kit (+50 HP), bulk ammo, and tactical deployables.

enum DropState { DESCENDING, LANDED, OPENED }

@export var descent_duration: float = 3.2
@export var initial_height: float = 380.0

var current_state: DropState = DropState.DESCENDING
var descent_timer: float = 0.0
var player_in_range: bool = false
var sway_phase: float = 0.0

@onready var crate_node: Node2D = $CrateVisual
@onready var parachute_node: Node2D = $CrateVisual/ParachuteVisual
@onready var ground_shadow: Sprite2D = $GroundShadow
@onready var flare_smoke: CPUParticles2D = $GroundFlare/FlareSmoke
@onready var flare_light: PointLight2D = $GroundFlare/FlareLight
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	add_to_group("supply_drops")
	collision_layer = 0
	collision_mask = 1 # Player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
	
	descent_timer = 0.0
	current_state = DropState.DESCENDING
	sway_phase = randf() * TAU
	
	# Aircraft flyby audio cue
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("aircraft_flyby", global_position)
	else:
		Global.play_sound("wave_start", global_position)

func _process(delta: float) -> void:
	match current_state:
		DropState.DESCENDING:
			descent_timer += delta
			var progress = clampf(descent_timer / descent_duration, 0.0, 1.0)
			
			# Smooth descent with air drag
			var height = lerpf(initial_height, 0.0, ease(progress, 0.6))
			var sway = sin(Time.get_ticks_msec() * 0.003 + sway_phase) * (18.0 * (1.0 - progress * 0.5))
			
			if crate_node:
				crate_node.position = Vector2(sway, -height)
				crate_node.rotation = (sway / 18.0) * 0.12
			
			if ground_shadow:
				var shadow_scale = lerpf(0.25, 1.0, progress)
				ground_shadow.scale = Vector2(shadow_scale, shadow_scale * 0.45)
				ground_shadow.modulate.a = lerpf(0.15, 0.7, progress)
			
			if progress >= 1.0:
				_on_crate_landed()
		
		DropState.LANDED:
			# Pulse flare light
			if flare_light:
				flare_light.energy = 1.8 + sin(Time.get_ticks_msec() * 0.008) * 0.6
			
			# Prompt visual pulse
			if prompt_label and prompt_label.visible:
				var pulse = 0.85 + sin(Time.get_ticks_msec() * 0.01) * 0.15
				prompt_label.scale = Vector2(pulse, pulse)

func _unhandled_input(event: InputEvent) -> void:
	if current_state != DropState.LANDED or not player_in_range:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		open_crate()
		get_viewport().set_input_as_handled()

func _on_crate_landed() -> void:
	current_state = DropState.LANDED
	if crate_node:
		crate_node.position = Vector2.ZERO
		crate_node.rotation = 0.0
	
	# Ground impact audio
	var audio_mgr = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("stomp_crash", global_position)
	else:
		Global.play_sound("explode", global_position)
	
	# Detach parachute with fade out
	if parachute_node:
		var tween = create_tween()
		tween.tween_property(parachute_node, "position:y", -18.0, 0.4).as_relative()
		tween.parallel().tween_property(parachute_node, "modulate:a", 0.0, 0.6)
		tween.tween_callback(parachute_node.queue_free)
	
	# Check if player was already waiting on LZ
	var overlapping = get_overlapping_bodies()
	for b in overlapping:
		if b.is_in_group("player"):
			player_in_range = true
			if prompt_label:
				prompt_label.visible = true
			break

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if current_state == DropState.LANDED and prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func open_crate() -> void:
	if current_state != DropState.LANDED:
		return
	current_state = DropState.OPENED
	if prompt_label:
		prompt_label.visible = false
	
	# Grant trauma kit + bulk ammo + deployables
	Global.grant_supply_drop()
	
	# Green flare change
	if flare_light:
		flare_light.color = Color(0.2, 1.0, 0.4)
		flare_light.energy = 2.8
	if flare_smoke:
		flare_smoke.emitting = false
	
	# Spawn pickup explosion effects
	var level = get_tree().current_scene
	if level:
		var burst = CPUParticles2D.new()
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 32
		burst.lifetime = 0.8
		burst.spread = 180.0
		burst.initial_velocity_min = 100.0
		burst.initial_velocity_max = 240.0
		burst.scale_amount_min = 3.0
		burst.scale_amount_max = 6.0
		burst.color = Color(0.25, 0.95, 0.55, 1.0)
		burst.global_position = global_position
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)
	
	# Fade crate out smoothly
	var tween = create_tween()
	tween.tween_property(crate_node, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(ground_shadow, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(flare_light, "energy", 0.0, 0.8)
	tween.tween_callback(queue_free)
