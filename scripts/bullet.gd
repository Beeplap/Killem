extends Area2D

var damage: float = 35.0
var speed: float = 800.0
var lifetime: float = 2.0
var timer: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var is_active: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_process(false)
	visible = false

func activate(spawn_pos: Vector2, shoot_direction: Vector2, bullet_damage: float, bullet_speed: float, bullet_lifetime: float) -> void:
	global_position = spawn_pos
	direction = shoot_direction.normalized()
	rotation = direction.angle()
	damage = bullet_damage
	speed = bullet_speed
	lifetime = bullet_lifetime
	timer = 0.0
	is_active = true
	visible = true
	set_process(true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	queue_redraw()

func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	set_process(false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	global_position += direction * speed * delta
	timer += delta
	if timer >= lifetime:
		deactivate()

func _draw() -> void:
	# Draw luminous yellow laser tracer
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(1.0, 0.9, 0.2, 1.0), 3.0)
	draw_circle(Vector2(12, 0), 2.5, Color(1.0, 1.0, 0.8, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	
	if body.is_in_group("enemies") or body.has_method("take_damage"):
		body.take_damage(damage, direction)
		deactivate()
	elif body.is_in_group("obstacles") or body is TileMap or body is StaticBody2D:
		deactivate()

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	if area.has_method("take_damage") or area.get_parent().has_method("take_damage"):
		var target = area if area.has_method("take_damage") else area.get_parent()
		target.take_damage(damage, direction)
		deactivate()
