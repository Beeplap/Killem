class_name Barbwire
extends Area2D

## Tactical Defensive Barbwire Obstacle
## Renders strictly on ground plane (z_index = -1), covers choke points with +35% footprint,
## slows zombies by 70%, deals 8 damage every 0.4s, and has 250 HP structural durability.

@export var max_durability: float = 250.0
@export var slow_multiplier: float = 0.30 # 70% speed reduction
@export var tick_damage: float = 8.0
@export var tick_interval: float = 0.40

var current_durability: float = 250.0
var tick_timer: float = 0.0
var overlapping_zombies: Array[Node2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D

var needs_repair: bool:
	get: return needs_service()

func _ready() -> void:
	add_to_group("deployables")
	add_to_group("serviceable")
	add_to_group("barbwire")
	
	# Fix Z-sorting/layering: strictly on ground plane below characters
	z_index = -1
	z_as_relative = false
	
	current_durability = max_durability
	tick_timer = tick_interval
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 6), Vector2(1.2, 0.45))

func _process(delta: float) -> void:
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		process_zombie_damage()
	
	# Update visual wear based on structural HP
	if sprite:
		var health_pct = clampf(current_durability / max_durability, 0.0, 1.0)
		if health_pct < 0.4:
			sprite.modulate = Color(1.3, 0.7, 0.7, 0.9)
		elif health_pct < 0.75:
			sprite.modulate = Color(1.1, 0.9, 0.8, 0.95)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not overlapping_zombies.has(body):
		overlapping_zombies.append(body)

func _on_body_exited(body: Node2D) -> void:
	if overlapping_zombies.has(body):
		overlapping_zombies.erase(body)

func process_zombie_damage() -> void:
	var to_remove: Array[Node2D] = []
	for zombie in overlapping_zombies:
		if not is_instance_valid(zombie) or (zombie.has_method("is_dead") and zombie.is_dead()):
			to_remove.append(zombie)
			continue
		
		# Apply 70% movement reduction
		if zombie.has_method("apply_slow"):
			zombie.apply_slow(slow_multiplier, tick_interval + 0.15)
		
		# Deal 8 damage every 0.4s
		if zombie.has_method("take_damage"):
			var dir = (zombie.global_position - global_position).normalized()
			zombie.take_damage(tick_damage, dir)
		
		# Structural wear from zombies forcing through
		current_durability -= 6.0
		
		# Visual wire jitter / twitch
		if sprite:
			sprite.position = Vector2(randf_range(-1.8, 1.8), randf_range(-1.8, 1.8))
		
		if current_durability <= 0.0:
			break_wire()
			return
	
	for z in to_remove:
		overlapping_zombies.erase(z)
	
	if sprite:
		sprite.position = Vector2.ZERO

# Service Protocol
func needs_service() -> bool:
	return current_durability < (max_durability - 5.0)

func get_service_prompt() -> String:
	return "Repair Barbwire"

func get_service_duration() -> float:
	return 3.0

func perform_service() -> void:
	current_durability = max_durability
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.position = Vector2.ZERO
	Global.play_sound("hit")

func repair_wire() -> void:
	perform_service()

func break_wire() -> void:
	Global.play_sound("hit")
	var level = get_tree().current_scene
	if level:
		var parts = CPUParticles2D.new()
		parts.global_position = global_position
		parts.emitting = true
		parts.one_shot = true
		parts.explosiveness = 0.9
		parts.amount = 14
		parts.lifetime = 0.5
		parts.spread = 180.0
		parts.initial_velocity_min = 50.0
		parts.initial_velocity_max = 140.0
		parts.scale_amount_min = 2.0
		parts.scale_amount_max = 4.5
		parts.color = Color(0.6, 0.65, 0.7, 0.85)
		parts.finished.connect(parts.queue_free)
		level.add_child(parts)
	queue_free()
