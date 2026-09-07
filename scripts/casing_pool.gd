class_name CasingPool
extends Node2D

## High-Performance Casing Pool & Memory Guard
## Enforces a strict hard cap of 40 active brass shell casings with 4.0-second auto-despawn lifetime,
## progressive alpha fadeout, and zero-allocation recycling.

class CasingInstance:
	var sprite: Sprite2D
	var velocity: Vector2 = Vector2.ZERO
	var angular_velocity: float = 0.0
	var settled: bool = true
	var age: float = 0.0
	var fade_tween: Tween = null

const MAX_ACTIVE_CASINGS: int = 40
const CASING_LIFETIME: float = 4.0
const FADE_DURATION: float = 0.8

var _pool: Array[CasingInstance] = []
var active_casings: Array[CasingInstance] = []

func _ready() -> void:
	z_index = -2 # Floor layer below characters
	var casing_tex = ProceduralTextures.get_casing_texture()
	
	for i in range(MAX_ACTIVE_CASINGS):
		var c = CasingInstance.new()
		c.sprite = Sprite2D.new()
		c.sprite.texture = casing_tex
		c.sprite.visible = false
		add_child(c.sprite)
		_pool.append(c)

func spawn_casing(spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	# Hard Cap Culling: Enforce strict ceiling of 40 active casings on screen
	if active_casings.size() >= MAX_ACTIVE_CASINGS:
		var oldest = active_casings.pop_front()
		_recycle_casing(oldest)
	
	# Fetch available instance from pool
	var c: CasingInstance = null
	for inst in _pool:
		if not inst.sprite.visible:
			c = inst
			break
	if c == null:
		c = active_casings.pop_front()
		_recycle_casing(c)
	
	if c.fade_tween and c.fade_tween.is_valid():
		c.fade_tween.kill()
	
	c.sprite.global_position = spawn_pos
	c.sprite.rotation = randf() * TAU
	c.sprite.modulate.a = 1.0
	c.sprite.visible = true
	c.age = 0.0
	
	# Eject trajectory with randomized angle and velocity
	var eject_side: float = 1.0 if randf() < 0.85 else -1.0
	var eject_angle: float = deg_to_rad(randf_range(78.0, 108.0) * eject_side)
	var speed: float = randf_range(160.0, 270.0)
	c.velocity = shoot_dir.rotated(eject_angle) * speed
	c.angular_velocity = randf_range(-35.0, 35.0)
	c.settled = false
	
	active_casings.append(c)

func _recycle_casing(c: CasingInstance) -> void:
	if c.fade_tween and c.fade_tween.is_valid():
		c.fade_tween.kill()
	c.sprite.visible = false
	c.settled = true
	c.velocity = Vector2.ZERO
	c.angular_velocity = 0.0
	c.age = 0.0

func _physics_process(delta: float) -> void:
	var idx = 0
	while idx < active_casings.size():
		var c = active_casings[idx]
		c.age += delta
		
		# Movement while airborne
		if not c.settled:
			c.sprite.global_position += c.velocity * delta
			c.sprite.rotation += c.angular_velocity * delta
			c.velocity = c.velocity.move_toward(Vector2.ZERO, 1300.0 * delta)
			c.angular_velocity = move_toward(c.angular_velocity, 0.0, 55.0 * delta)
			if c.velocity.length_squared() < 16.0:
				c.settled = true
		
		# Auto-Despawn Lifetime: Progressive alpha fade out over last 0.8s, despawn at 4.0s
		if c.age >= (CASING_LIFETIME - FADE_DURATION):
			var fade_progress = (c.age - (CASING_LIFETIME - FADE_DURATION)) / FADE_DURATION
			c.sprite.modulate.a = clampf(1.0 - fade_progress, 0.0, 1.0)
		
		if c.age >= CASING_LIFETIME:
			_recycle_casing(c)
			active_casings.remove_at(idx)
			continue
		
		idx += 1
