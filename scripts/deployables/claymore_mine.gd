extends Area2D

@export var trigger_radius: float = 120.0
@export var blast_angle_deg: float = 60.0
@export var blast_damage: float = 160.0

var is_armed: bool = false
var is_triggered: bool = false
var facing_dir: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D
@onready var led_light: PointLight2D = get_node_or_null("LedLight")

func _ready() -> void:
	add_to_group("deployables")
	rotation = facing_dir.angle()
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 4), Vector2(0.6, 0.3))
	
	# Arming delay of 0.5s after placement so player can step back
	get_tree().create_timer(0.5).timeout.connect(func(): is_armed = true)

func set_facing(dir: Vector2) -> void:
	facing_dir = dir.normalized()
	rotation = facing_dir.angle()

func _physics_process(_delta: float) -> void:
	if not is_armed or is_triggered:
		return
	
	# Check for zombies entering 120px perimeter and within 60° forward arc
	var enemies = get_tree().get_nodes_in_group("enemies")
	var half_angle_rad = deg_to_rad(blast_angle_deg * 0.5)
	var min_dot = cos(half_angle_rad)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var diff = enemy.global_position - global_position
		var dist = diff.length()
		if dist <= trigger_radius:
			var dir_to_enemy = diff.normalized()
			if facing_dir.dot(dir_to_enemy) >= min_dot:
				trigger_detonation()
				break

func trigger_detonation() -> void:
	is_triggered = true
	Global.play_sound("hit") # Click sound
	
	# Brief 0.12s fuse before blast
	await get_tree().create_timer(0.12).timeout
	detonate()

func detonate() -> void:
	Global.play_sound("explode")
	Global.explosion_occurred.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_shake"):
		player.trigger_shake(12.0, 0.35)
	
	Global.trigger_hitstop(0.045, 0.05)
	
	var level = get_tree().current_scene
	if level:
		# Directional muzzle blast flash
		var flash = PointLight2D.new()
		flash.texture = preload("res://assets/textures/lighting/point_light_cookie.png")
		flash.texture_scale = 2.8
		flash.color = Color(1.0, 0.7, 0.2)
		flash.energy = 4.0
		flash.global_position = global_position + facing_dir * 25.0
		level.add_child(flash)
		
		var tween = level.create_tween()
		tween.tween_property(flash, "energy", 0.0, 0.22).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(flash.queue_free)
		
		# Directional shrapnel burst
		var shrapnel = CPUParticles2D.new()
		shrapnel.emitting = true
		shrapnel.one_shot = true
		shrapnel.explosiveness = 0.98
		shrapnel.amount = 35
		shrapnel.lifetime = 0.45
		shrapnel.direction = facing_dir
		shrapnel.spread = blast_angle_deg * 0.7
		shrapnel.initial_velocity_min = 280.0
		shrapnel.initial_velocity_max = 520.0
		shrapnel.scale_amount_min = 2.5
		shrapnel.scale_amount_max = 5.0
		shrapnel.color = Color(1.0, 0.85, 0.3)
		shrapnel.global_position = global_position
		shrapnel.finished.connect(shrapnel.queue_free)
		level.add_child(shrapnel)
		
		# Smoke cone
		var smoke = CPUParticles2D.new()
		smoke.emitting = true
		smoke.one_shot = true
		smoke.explosiveness = 0.9
		smoke.amount = 18
		smoke.lifetime = 0.75
		smoke.direction = facing_dir
		smoke.spread = blast_angle_deg * 0.8
		smoke.initial_velocity_min = 80.0
		smoke.initial_velocity_max = 240.0
		smoke.scale_amount_min = 6.0
		smoke.scale_amount_max = 14.0
		smoke.color = Color(0.2, 0.2, 0.22, 0.75)
		smoke.global_position = global_position
		smoke.finished.connect(smoke.queue_free)
		level.add_child(smoke)
	
	# Damage all enemies in cone
	var half_angle_rad = deg_to_rad(blast_angle_deg * 0.5)
	var min_dot = cos(half_angle_rad)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var diff = enemy.global_position - global_position
			var dist = diff.length()
			if dist <= (trigger_radius * 1.25):
				var dir_to_enemy = diff.normalized()
				if facing_dir.dot(dir_to_enemy) >= (min_dot - 0.15):
					var falloff = 1.0 - (dist / (trigger_radius * 1.25))
					var dmg = blast_damage * max(0.4, falloff)
					enemy.take_damage(dmg, dir_to_enemy * 2.5)
	
	queue_free()
