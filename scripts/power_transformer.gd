extends StaticBody2D

@export var max_health: float = 35.0
@export var discharge_duration: float = 3.0
@export var zap_radius: float = 240.0
@export var zap_damage_per_second: float = 35.0

var current_health: float = 35.0
var is_active_discharging: bool = false
var discharge_timer: float = 0.0
var zap_tick_timer: float = 0.0
var is_burned_out: bool = false
var is_broken: bool:
	get: return is_burned_out

@onready var sprite: Sprite2D = $Sprite2D
@onready var zap_light: PointLight2D = $PointLight2D
@onready var spark_particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("transformers")
	current_health = max_health
	if zap_light:
		zap_light.enabled = false
	if spark_particles:
		spark_particles.emitting = false
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 16), Vector2(0.8, 0.35))

func take_damage(amount: float, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_active_discharging or is_burned_out:
		return
	
	current_health -= amount
	if sprite:
		sprite.modulate = Color(1.8, 1.8, 2.0, 1.0)
		get_tree().create_timer(0.06).timeout.connect(func(): if sprite and not is_active_discharging: sprite.modulate = Color.WHITE)
	
	if current_health <= 0.0:
		trigger_electrical_discharge()

func trigger_electrical_discharge() -> void:
	is_active_discharging = true
	discharge_timer = discharge_duration
	zap_tick_timer = 0.0
	Global.play_sound("electric_zap")
	
	if zap_light:
		zap_light.enabled = true
		zap_light.energy = 2.5
	if spark_particles:
		spark_particles.emitting = true

func _process(delta: float) -> void:
	if not is_active_discharging:
		return
	
	discharge_timer -= delta
	zap_tick_timer -= delta
	
	# Violent high-voltage electrical strobe flicker
	if zap_light:
		zap_light.energy = randf_range(1.5, 3.2)
		zap_light.color = Color(0.3, 0.8, 1.0, 1.0) if randf() < 0.7 else Color(0.9, 0.95, 1.0, 1.0)
	
	if zap_tick_timer <= 0.0:
		zap_tick_timer = 0.20
		Global.play_sound("electric_zap")
		shock_nearby_targets()
	
	if discharge_timer <= 0.0:
		finish_discharge()

func shock_nearby_targets() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= zap_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(zap_damage_per_second * 0.20, (enemy.global_position - global_position).normalized())
				if enemy.has_method("stagger"):
					enemy.stagger(0.30)
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.25, 0.40)
	
	# Screen shake
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= zap_radius:
		if player.has_method("trigger_shake"):
			player.trigger_shake(4.0, 0.15)

func finish_discharge() -> void:
	is_active_discharging = false
	is_burned_out = true
	if zap_light:
		zap_light.enabled = false
	if spark_particles:
		spark_particles.emitting = false
	if sprite:
		sprite.modulate = Color(0.35, 0.35, 0.38, 1.0) # Burned-out charred casing
