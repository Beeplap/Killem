extends Node2D

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const INITIAL_POOL_SIZE: int = 120

var pool: Array[Node2D] = []

func _ready() -> void:
	for i in range(INITIAL_POOL_SIZE):
		var bullet = BULLET_SCENE.instantiate()
		add_child(bullet)
		pool.append(bullet)

func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, spd: float, life: float) -> Node2D:
	for bullet in pool:
		if not bullet.is_active:
			bullet.activate(pos, dir, dmg, spd, life)
			return bullet
	
	# If pool is exhausted, dynamically expand by 1
	var new_bullet = BULLET_SCENE.instantiate()
	add_child(new_bullet)
	pool.append(new_bullet)
	new_bullet.activate(pos, dir, dmg, spd, life)
	return new_bullet
