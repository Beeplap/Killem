extends Node3D
class_name Shockwave3D

@export var max_radius: float = 9.5
@export var duration: float = 0.55
@export var damage: float = 35.0
@export var knockback_force: float = 16.0

var elapsed: float = 0.0
var current_radius: float = 1.0
var hit_entities: Array[Node3D] = []

@onready var ring_mesh: MeshInstance3D = $RingMesh
@onready var dust_particles: CPUParticles3D = $DustParticles
@onready var area: Area3D = $Area3D
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)
	if Engine.has_singleton("Global") or "Global" in get_tree().root:
		Global.play_sound("explode")

func _physics_process(delta: float) -> void:
	elapsed += delta
	var progress = clampf(elapsed / duration, 0.0, 1.0)
	
	current_radius = lerpf(1.0, max_radius, ease(progress, 0.35))
	
	# Scale ring mesh horizontally
	if ring_mesh:
		ring_mesh.scale = Vector3(current_radius, 1.0, current_radius)
		# Fade out opacity near end
		var mat = ring_mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color.a = clampf(1.0 - progress, 0.0, 1.0) * 0.85
	
	# Update area collision cylinder radius
	if collision_shape and collision_shape.shape is CylinderShape3D:
		(collision_shape.shape as CylinderShape3D).radius = current_radius
	
	if elapsed >= duration:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body in hit_entities or body.is_in_group("enemies"):
		return
	
	hit_entities.append(body)
	
	var radial_dir = (body.global_position - global_position)
	radial_dir.y = 0.0
	if radial_dir.length_squared() > 0.01:
		radial_dir = radial_dir.normalized()
	else:
		radial_dir = Vector3.FORWARD
	
	if body.is_in_group("player") or body.is_in_group("player3d"):
		if body.has_method("take_damage"):
			body.take_damage(damage, radial_dir * knockback_force)
		if "trauma" in body:
			body.trauma = clampf(body.trauma + 0.5, 0.0, 1.0)
	elif body.has_method("take_damage"):
		body.take_damage(damage, radial_dir)
	elif body.is_in_group("destructibles") or body.is_in_group("obstacles"):
		if body.has_method("destroy"):
			body.destroy()
		elif body.has_method("explode"):
			body.explode()
