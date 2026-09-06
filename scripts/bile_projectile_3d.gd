extends Area3D
class_name BileProjectile3D

@export var damage: float = 18.0
@export var speed: float = 24.0
@export var arc_gravity: float = 9.8
@export var lifetime: float = 3.5

var velocity: Vector3 = Vector3.ZERO
var timer: float = 0.0

const PUDDLE_SCENE = preload("res://scenes/entities/ToxicPuddle3D.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(start_pos: Vector3, target_pos: Vector3) -> void:
	global_position = start_pos
	
	var to_target = (target_pos - start_pos)
	var horiz_dist = Vector2(to_target.x, to_target.z).length()
	var flight_time = clampf(horiz_dist / speed, 0.35, 1.2)
	
	# Parabolic ballistic arc trajectory
	var vx = to_target.x / flight_time
	var vz = to_target.z / flight_time
	var vy = (to_target.y + 0.5 * arc_gravity * flight_time * flight_time) / flight_time
	
	velocity = Vector3(vx, vy, vz)

func _physics_process(delta: float) -> void:
	velocity.y -= arc_gravity * delta
	global_position += velocity * delta
	
	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity, Vector3.UP)
	
	# Floor detection fallback (if reaches ground elevation)
	if global_position.y <= 0.05:
		detonate(Vector3(global_position.x, 0.02, global_position.z))
		return
	
	timer += delta
	if timer >= lifetime:
		detonate(global_position)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return
	
	if body.is_in_group("player") or body.is_in_group("player3d"):
		if body.has_method("take_damage"):
			body.take_damage(damage, velocity.normalized())
		detonate(global_position)
	elif body is StaticBody3D or body.is_in_group("obstacles"):
		detonate(global_position)

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player") or area.get_parent().is_in_group("player"):
		var target = area if area.has_method("take_damage") else area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(damage, velocity.normalized())
		detonate(global_position)

func detonate(impact_pos: Vector3) -> void:
	var scene = get_tree().current_scene
	if scene:
		# Spawn toxic puddle at ground level
		var puddle = PUDDLE_SCENE.instantiate()
		var ground_pos = impact_pos
		ground_pos.y = 0.02
		puddle.global_position = ground_pos
		scene.add_child(puddle)
		
		# Spawn acid impact splash particles
		spawn_splash_effect(impact_pos)
	
	queue_free()

func spawn_splash_effect(pos: Vector3) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var p = CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 20
	p.lifetime = 0.35
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -9.8, 0)
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	p.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 1.0, 0.2)
	p.material_override = mat
	
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
