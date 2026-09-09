class_name ScrapDrop
extends Area2D

## Tactical Scrap Pickup Entity
## Drops from eliminated zombies as a glowing brass mechanical gear.
## Features physical spawn scatter, an idle bobbing animation, and a 100px magnetic pull toward the player.

@export var scrap_value: int = 1
@export var magnet_radius: float = 100.0
@export var max_magnet_speed: float = 520.0
@export var lifetime: float = 60.0

var scatter_velocity: Vector2 = Vector2.ZERO
var magnet_velocity: Vector2 = Vector2.ZERO
var is_being_pulled: bool = false
var time_alive: float = 0.0
var random_phase: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = get_node_or_null("PointLight2D")
@onready var shadow: Sprite2D = get_node_or_null("GroundShadow")

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("scrap")
	collision_layer = 0
	collision_mask = 1 # Player layer
	
	body_entered.connect(_on_body_entered)
	
	random_phase = randf() * TAU
	# Initial physical scatter burst
	var angle = randf() * TAU
	var speed = randf_range(40.0, 95.0)
	scatter_velocity = Vector2.RIGHT.rotated(angle) * speed
	
	if shadow:
		shadow.scale = Vector2(0.45, 0.22)
		shadow.modulate.a = 0.45

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		fade_and_free()
		return
	
	# 1. Handle initial scatter friction
	if scatter_velocity.length_squared() > 4.0:
		global_position += scatter_velocity * delta
		scatter_velocity = scatter_velocity.move_toward(Vector2.ZERO, delta * 320.0)
	
	# 2. Idle visual bobbing
	if sprite:
		var bob = sin(Time.get_ticks_msec() * 0.007 + random_phase) * 2.2
		sprite.position.y = bob
		sprite.rotation += delta * 1.5
	
	if light:
		light.energy = 1.2 + sin(Time.get_ticks_msec() * 0.009 + random_phase) * 0.35
	
	# 3. Magnetic pull to player within 100px
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and not Global.is_game_over:
		var diff = player.global_position - global_position
		var dist = diff.length()
		
		if dist <= magnet_radius:
			is_being_pulled = true
			var pull_dir = diff.normalized()
			# Accelerate toward player
			var pull_accel = lerpf(800.0, 2200.0, 1.0 - (dist / magnet_radius))
			magnet_velocity = magnet_velocity.move_toward(pull_dir * max_magnet_speed, pull_accel * delta)
			global_position += magnet_velocity * delta
			
			# Auto-collect on close contact
			if dist < 18.0:
				collect()
				return
		else:
			if is_being_pulled:
				magnet_velocity = magnet_velocity.move_toward(Vector2.ZERO, delta * 600.0)
				global_position += magnet_velocity * delta
				if magnet_velocity.length_squared() < 10.0:
					is_being_pulled = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	# Add scrap to economy
	EconomyManager.add_scrap(scrap_value)
	Global.play_sound("scrap_pickup", global_position)
	
	# Visual spark starburst
	var level = get_tree().current_scene
	if level:
		var sparks = CPUParticles2D.new()
		sparks.emitting = true
		sparks.one_shot = true
		sparks.explosiveness = 0.95
		sparks.amount = 10
		sparks.lifetime = 0.35
		sparks.spread = 180.0
		sparks.initial_velocity_min = 60.0
		sparks.initial_velocity_max = 140.0
		sparks.scale_amount_min = 2.0
		sparks.scale_amount_max = 4.0
		sparks.color = Color(1.0, 0.85, 0.3, 1.0)
		sparks.global_position = global_position
		sparks.finished.connect(sparks.queue_free)
		level.add_child(sparks)
	
	queue_free()

func fade_and_free() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
