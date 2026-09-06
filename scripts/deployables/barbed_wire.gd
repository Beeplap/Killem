extends Area2D

@export var max_durability: int = 30
@export var slow_multiplier: float = 0.30 # 70% speed reduction
@export var tick_damage: float = 6.0
@export var tick_interval: float = 0.35

var current_durability: int = 30
var tick_timer: float = 0.0
var overlapping_zombies: Array[Node2D] = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("deployables")
	current_durability = max_durability
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ProceduralTextures.add_drop_shadow(self, Vector2(0, 6), Vector2(0.9, 0.4))

func _process(delta: float) -> void:
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		process_zombie_damage()

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
		
		# Apply 70% slow down
		if zombie.has_method("apply_slow"):
			zombie.apply_slow(slow_multiplier, tick_interval + 0.15)
		
		# Deal damage
		if zombie.has_method("take_damage"):
			zombie.take_damage(tick_damage, (zombie.global_position - global_position).normalized())
		
		current_durability -= 1
		
		# Visual wire jitter / twitch
		if sprite:
			sprite.position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		
		if current_durability <= 0:
			break_wire()
			return
	
	for z in to_remove:
		overlapping_zombies.erase(z)
	
	if sprite:
		sprite.position = Vector2.ZERO

func break_wire() -> void:
	Global.play_sound("hit")
	var level = get_tree().current_scene
	if level:
		var parts = CPUParticles2D.new()
		parts.emitting = true
		parts.one_shot = true
		parts.explosiveness = 0.9
		parts.amount = 12
		parts.lifetime = 0.5
		parts.spread = 180.0
		parts.initial_velocity_min = 40.0
		parts.initial_velocity_max = 120.0
		parts.scale_amount_min = 2.0
		parts.scale_amount_max = 4.0
		parts.color = Color(0.45, 0.45, 0.5, 0.8)
		parts.global_position = global_position
		parts.finished.connect(parts.queue_free)
		level.add_child(parts)
	
	queue_free()
