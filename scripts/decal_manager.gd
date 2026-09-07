extends Node

# DecalManager: Centralized high-performance MultiMesh decal pooling & particle optimization
# Pre-allocates buffers of 1,000 instances for blood splats and bullet casings.
# Zero node instantiation overhead at runtime, single draw-call rendering.

const MAX_BLOOD_INSTANCES: int = 1000
const MAX_CASING_INSTANCES: int = 40
const CASING_LIFETIME: float = 4.0

var blood_multimesh_instance: MultiMeshInstance2D = null
var blood_multimesh: MultiMesh = null
var blood_index: int = 0

var casing_multimesh_instance: MultiMeshInstance2D = null
var casing_multimesh: MultiMesh = null
var casing_index: int = 0

# Dynamic casing physics tracking
class ActiveCasing:
	var index: int
	var pos: Vector2
	var rot: float
	var vel: Vector2
	var ang_vel: float
	var settled: bool = false
	var age: float = 0.0

var active_casings: Array[ActiveCasing] = []

const BLOOD_TEXTURE = preload("res://assets/textures/decals/blood_splat_1.png")

func _ready() -> void:
	process_priority = -10
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_setup_pools_for_current_scene")

func _on_scene_changed() -> void:
	call_deferred("_setup_pools_for_current_scene")

func _setup_pools_for_current_scene() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene or not (current_scene is Node2D):
		return
	
	# Check if existing pool parent exists or create one on the floor layer
	var decal_root = current_scene.get_node_or_null("DecalPoolLayer")
	if not decal_root:
		decal_root = Node2D.new()
		decal_root.name = "DecalPoolLayer"
		decal_root.z_index = -3 # Floor level under characters
		current_scene.add_child(decal_root)
	
	# 1. Setup Blood Splat MultiMesh
	blood_multimesh = MultiMesh.new()
	blood_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	blood_multimesh.use_colors = true
	
	var quad_blood = QuadMesh.new()
	quad_blood.size = Vector2(44.0, 44.0)
	blood_multimesh.mesh = quad_blood
	blood_multimesh.instance_count = MAX_BLOOD_INSTANCES
	
	# Initialize all instances as invisible (scaled to zero offscreen)
	var zero_xform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2(-9999, -9999))
	for i in range(MAX_BLOOD_INSTANCES):
		blood_multimesh.set_instance_transform_2d(i, zero_xform)
		blood_multimesh.set_instance_color(i, Color(1, 1, 1, 0))
	
	blood_multimesh_instance = MultiMeshInstance2D.new()
	blood_multimesh_instance.name = "BloodMultiMesh"
	blood_multimesh_instance.texture = BLOOD_TEXTURE
	blood_multimesh_instance.multimesh = blood_multimesh
	decal_root.add_child(blood_multimesh_instance)
	blood_index = 0
	
	# 2. Setup Bullet Casing MultiMesh
	casing_multimesh = MultiMesh.new()
	casing_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	casing_multimesh.use_colors = true
	
	var quad_casing = QuadMesh.new()
	quad_casing.size = Vector2(6.0, 14.0)
	casing_multimesh.mesh = quad_casing
	casing_multimesh.instance_count = MAX_CASING_INSTANCES
	
	for i in range(MAX_CASING_INSTANCES):
		casing_multimesh.set_instance_transform_2d(i, zero_xform)
		casing_multimesh.set_instance_color(i, Color(1, 1, 1, 0))
	
	casing_multimesh_instance = MultiMeshInstance2D.new()
	casing_multimesh_instance.name = "CasingMultiMesh"
	if Engine.has_singleton("ProceduralTextures") or get_node_or_null("/root/ProceduralTextures"):
		casing_multimesh_instance.texture = ProceduralTextures.get_casing_texture()
	casing_multimesh_instance.multimesh = casing_multimesh
	decal_root.add_child(casing_multimesh_instance)
	casing_index = 0
	active_casings.clear()

func spawn_blood_splat(pos: Vector2, hit_dir: Vector2, scale_multiplier: float = 1.0) -> void:
	if not blood_multimesh:
		_setup_pools_for_current_scene()
		if not blood_multimesh:
			return
	
	var idx = blood_index
	blood_index = (blood_index + 1) % MAX_BLOOD_INSTANCES
	
	var rot = hit_dir.angle() + randf_range(-0.5, 0.5)
	var s = randf_range(0.8, 1.35) * scale_multiplier
	var xform = Transform2D(rot, Vector2(s, s), 0.0, pos)
	
	var tint = Color(
		randf_range(0.7, 1.0),
		randf_range(0.75, 0.95),
		randf_range(0.75, 0.95),
		randf_range(0.85, 1.0)
	)
	
	blood_multimesh.set_instance_transform_2d(idx, xform)
	blood_multimesh.set_instance_color(idx, tint)

func spawn_bullet_casing(spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	if not casing_multimesh:
		_setup_pools_for_current_scene()
		if not casing_multimesh:
			return
	
	# Hard Cap Culling: enforce strict ceiling of 40 active casings
	if active_casings.size() >= MAX_CASING_INSTANCES:
		var oldest = active_casings.pop_front()
		var zero_xform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2(-9999, -9999))
		casing_multimesh.set_instance_transform_2d(oldest.index, zero_xform)
		casing_multimesh.set_instance_color(oldest.index, Color(1, 1, 1, 0))
	
	var idx = casing_index
	casing_index = (casing_index + 1) % MAX_CASING_INSTANCES
	
	var rot = randf() * TAU
	var xform = Transform2D(rot, Vector2.ONE, 0.0, spawn_pos)
	casing_multimesh.set_instance_transform_2d(idx, xform)
	casing_multimesh.set_instance_color(idx, Color(1, 0.9, 0.6, 1.0))
	
	# Eject trajectory
	var eject_side = 1.0 if randf() < 0.85 else -1.0
	var eject_angle = deg_to_rad(randf_range(78.0, 108.0) * eject_side)
	var speed = randf_range(160.0, 270.0)
	var vel = shoot_dir.rotated(eject_angle) * speed
	
	var ac = ActiveCasing.new()
	ac.index = idx
	ac.pos = spawn_pos
	ac.rot = rot
	ac.vel = vel
	ac.ang_vel = randf_range(-35.0, 35.0)
	ac.settled = false
	ac.age = 0.0
	active_casings.append(ac)

func _physics_process(delta: float) -> void:
	if not casing_multimesh or active_casings.is_empty():
		return
	
	var i = 0
	while i < active_casings.size():
		var ac = active_casings[i]
		ac.age += delta
		
		if not ac.settled:
			ac.pos += ac.vel * delta
			ac.rot += ac.ang_vel * delta
			ac.vel = ac.vel.move_toward(Vector2.ZERO, 1300.0 * delta)
			ac.ang_vel = move_toward(ac.ang_vel, 0.0, 55.0 * delta)
			
			var xform = Transform2D(ac.rot, Vector2.ONE, 0.0, ac.pos)
			casing_multimesh.set_instance_transform_2d(ac.index, xform)
			
			if ac.vel.length_squared() < 16.0:
				ac.settled = true
		
		# Auto-Despawn Lifetime (4.0s) with 0.8s fadeout
		if ac.age >= (CASING_LIFETIME - 0.8):
			var alpha = clampf((CASING_LIFETIME - ac.age) / 0.8, 0.0, 1.0)
			casing_multimesh.set_instance_color(ac.index, Color(1, 0.9, 0.6, alpha))
		
		if ac.age >= CASING_LIFETIME:
			var zero_xform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2(-9999, -9999))
			casing_multimesh.set_instance_transform_2d(ac.index, zero_xform)
			casing_multimesh.set_instance_color(ac.index, Color(1, 1, 1, 0))
			active_casings.remove_at(i)
			continue
		
		i += 1

func register_transient_debris(debris_node: Node, lifetime: float = 4.0) -> void:
	if not is_instance_valid(debris_node):
		return
	var tree = get_tree()
	if not tree:
		return
	var tween = tree.create_tween()
	var fade_start = max(0.1, lifetime - 0.8)
	tween.tween_interval(fade_start)
	if debris_node is CanvasItem:
		tween.tween_property(debris_node, "modulate:a", 0.0, 0.8)
	elif debris_node is Node3D and "transparency" in debris_node:
		tween.tween_property(debris_node, "transparency", 1.0, 0.8)
	tween.tween_callback(debris_node.queue_free)

# Particle Cleanup Policy Helper
# Ensures transient particle nodes auto-terminate with 100% explosiveness and zero leak
func optimize_particle_emitter(emitter: Node) -> void:
	if emitter is GPUParticles2D or emitter is CPUParticles2D:
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		if not emitter.finished.is_connected(emitter.queue_free):
			emitter.finished.connect(emitter.queue_free)
	elif emitter is GPUParticles3D or emitter is CPUParticles3D:
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		if not emitter.finished.is_connected(emitter.queue_free):
			emitter.finished.connect(emitter.queue_free)
