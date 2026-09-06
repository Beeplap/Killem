class_name CasingPool
extends Node2D

class CasingInstance:
	var sprite: Sprite2D
	var velocity: Vector2 = Vector2.ZERO
	var angular_velocity: float = 0.0
	var settled: bool = true

var _casings: Array[CasingInstance] = []
var _pool_index: int = 0
const POOL_SIZE: int = 40

func _ready() -> void:
	z_index = -2 # Floor layer below characters
	var casing_tex = ProceduralTextures.get_casing_texture()
	
	for i in range(POOL_SIZE):
		var c = CasingInstance.new()
		c.sprite = Sprite2D.new()
		c.sprite.texture = casing_tex
		c.sprite.visible = false
		add_child(c.sprite)
		_casings.append(c)

func spawn_casing(spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	if _casings.is_empty():
		return
	
	var c = _casings[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	
	c.sprite.global_position = spawn_pos
	c.sprite.rotation = randf() * TAU
	c.sprite.visible = true
	
	# Eject sideways with random angular velocity
	var eject_side: float = 1.0 if randf() < 0.85 else -1.0
	var eject_angle: float = deg_to_rad(randf_range(78.0, 108.0) * eject_side)
	var speed: float = randf_range(160.0, 270.0)
	c.velocity = shoot_dir.rotated(eject_angle) * speed
	c.angular_velocity = randf_range(-35.0, 35.0)
	c.settled = false

func _physics_process(delta: float) -> void:
	for c in _casings:
		if not c.settled:
			c.sprite.global_position += c.velocity * delta
			c.sprite.rotation += c.angular_velocity * delta
			c.velocity = c.velocity.move_toward(Vector2.ZERO, 1300.0 * delta)
			c.angular_velocity = move_toward(c.angular_velocity, 0.0, 55.0 * delta)
			if c.velocity.length_squared() < 16.0:
				c.settled = true
