extends Area2D
class_name BoulderProjectile2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 420.0
var damage: float = 25.0
var lifetime: float = 3.5
var timer: float = 0.0
var rotation_speed: float = 8.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	rotation_speed = randf_range(-10.0, 10.0)

func launch(start_pos: Vector2, target_dir: Vector2, spd: float = 420.0, dmg: float = 25.0) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	speed = spd
	damage = dmg
	rotation = randf() * TAU

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		explode_boulder()
		return
	
	global_position += direction * speed * delta
	rotate(rotation_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boss") or body.is_in_group("enemies"):
		return
	
	if body.is_in_group("player") or body.has_method("take_damage"):
		body.take_damage(damage, direction)
		explode_boulder()
	elif body is TileMap or body is StaticBody2D or body.is_in_group("obstacles") or body.is_in_group("barbwire"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		explode_boulder()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("boss") or area.is_in_group("enemies"):
		return
	if area.is_in_group("player"):
		var target = area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage, direction)
			explode_boulder()
	elif area.is_in_group("barbwire") or area.is_in_group("deployables"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		explode_boulder()

func explode_boulder() -> void:
	var level = get_tree().current_scene
	if level:
		var burst = CPUParticles2D.new()
		burst.global_position = global_position
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 0.95
		burst.amount = 12
		burst.lifetime = 0.4
		burst.spread = 180.0
		burst.initial_velocity_min = 80.0
		burst.initial_velocity_max = 200.0
		burst.scale_amount_min = 2.0
		burst.scale_amount_max = 5.0
		burst.color = Color(0.65, 0.6, 0.55)
		burst.finished.connect(burst.queue_free)
		level.add_child(burst)
	
	Global.play_sound("rock_impact", global_position)
	queue_free()
