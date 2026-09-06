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

func spawn_impact_fx(is_flesh: bool) -> void:
	var level = get_tree().current_scene
	if not level:
		return
	
	# Sparks / Spray
	var sparks = CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 8
	sparks.lifetime = 0.22
	sparks.direction = -direction
	sparks.spread = 55.0
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 220.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	if is_flesh:
		sparks.color = Color(0.85, 0.08, 0.08, 1.0) # Flesh / Blood spray
	else:
		sparks.color = Color(1.0, 0.85, 0.35, 1.0) # Metal / concrete ricochet sparks
	sparks.global_position = global_position
	sparks.finished.connect(sparks.queue_free)
	level.add_child(sparks)
	
	# Impact smoke puff
	var smoke = CPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.amount = 5
	smoke.lifetime = 0.35
	smoke.direction = -direction
	smoke.spread = 45.0
	smoke.initial_velocity_min = 25.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 7.0
	smoke.color = Color(0.35, 0.38, 0.4, 0.55)
	smoke.global_position = global_position
	smoke.finished.connect(smoke.queue_free)
	level.add_child(smoke)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("player"):
		return
	
	if body.is_in_group("enemies"):
		body.take_damage(damage, direction)
		spawn_impact_fx(true)
		# Shotgun pellets trigger micro-hitstop for heavy blast feedback
		if lifetime <= 0.85:
			Global.trigger_hitstop(0.04, 0.05)
		deactivate()
	elif body.has_method("take_damage"):
		body.take_damage(damage, direction)
		spawn_impact_fx(false)
		deactivate()
	elif body.is_in_group("obstacles") or body is TileMap or body is StaticBody2D:
		spawn_impact_fx(false)
		deactivate()

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	if area.is_in_group("player") or area.get_parent().is_in_group("player"):
		return
	if area.has_method("take_damage") or area.get_parent().has_method("take_damage"):
		var target = area if area.has_method("take_damage") else area.get_parent()
		target.take_damage(damage, direction)
		spawn_impact_fx(false)
		deactivate()
