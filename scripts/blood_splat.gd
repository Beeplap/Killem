class_name BloodSplat
extends Node2D

const BLOOD_TEXTURES = [
	preload("res://assets/textures/decals/blood_splat_1.png"),
	preload("res://assets/textures/decals/blood_splat_2.png"),
	preload("res://assets/textures/decals/blood_splat_3.png")
]

static var _pool: Array[Sprite2D] = []
static var _pool_index: int = 0
static var _pool_parent: Node2D = null
const MAX_DECALS: int = 80

static func spawn_splat(tree_root: Node, pos: Vector2, hit_dir: Vector2) -> void:
	if Engine.has_singleton("DecalManager") or tree_root.get_node_or_null("/root/DecalManager"):
		tree_root.get_node("/root/DecalManager").spawn_blood_splat(pos, hit_dir)
		return
	
	if not is_instance_valid(_pool_parent) or _pool_parent.get_parent() == null:
		_pool.clear()
		_pool_index = 0
		_pool_parent = Node2D.new()
		_pool_parent.name = "DecalLayer"
		_pool_parent.z_index = -2 # Floor decal layer below entities
		tree_root.add_child(_pool_parent)
	
	var spr: Sprite2D = null
	if _pool.size() < MAX_DECALS:
		spr = Sprite2D.new()
		_pool_parent.add_child(spr)
		_pool.append(spr)
	else:
		spr = _pool[_pool_index]
		_pool_index = (_pool_index + 1) % MAX_DECALS
	
	spr.texture = BLOOD_TEXTURES[randi() % BLOOD_TEXTURES.size()]
	spr.global_position = pos
	spr.rotation = hit_dir.angle() + randf_range(-0.4, 0.4)
	var s: float = randf_range(0.75, 1.25)
	spr.scale = Vector2(s, s)
	spr.modulate = Color(randf_range(0.75, 1.0), randf_range(0.75, 0.95), randf_range(0.75, 0.95), randf_range(0.85, 1.0))
	spr.visible = true

func _ready() -> void:
	var level = get_tree().current_scene
	if level:
		spawn_splat(level, global_position, Vector2.from_angle(rotation))
	queue_free()
