class_name HitmarkerManager
extends RefCounted

## HitmarkerManager: Global bridge for showing tactical screen-space hitmarkers
## Dispatches normal, critical (headshot), and fatal hit confirmation ticks.

static var _cached_hitmarker: TacticalHitmarker = null

static func get_hitmarker() -> TacticalHitmarker:
	if _cached_hitmarker != null and is_instance_valid(_cached_hitmarker):
		return _cached_hitmarker
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	
	var existing = tree.get_first_node_in_group("hitmarker") as TacticalHitmarker
	if existing and is_instance_valid(existing):
		_cached_hitmarker = existing
		return _cached_hitmarker
	
	# Dynamically instantiate a CanvasLayer with TacticalHitmarker if none exists
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "DynamicHitmarkerCanvas"
	
	var hitmarker_scene = load("res://scenes/ui/Hitmarker.tscn")
	var hitmarker: TacticalHitmarker = null
	if hitmarker_scene:
		hitmarker = hitmarker_scene.instantiate() as TacticalHitmarker
	else:
		hitmarker = TacticalHitmarker.new()
		hitmarker.add_to_group("hitmarker")
	
	canvas.add_child(hitmarker)
	tree.root.add_child.call_deferred(canvas)
	_cached_hitmarker = hitmarker
	return _cached_hitmarker

static func show_normal_hitmarker() -> void:
	var hm = get_hitmarker()
	if hm:
		hm.flash_hit(TacticalHitmarker.HitType.NORMAL)

static func show_crit_hitmarker() -> void:
	var hm = get_hitmarker()
	if hm:
		hm.flash_hit(TacticalHitmarker.HitType.CRITICAL)

static func show_fatal_hitmarker() -> void:
	var hm = get_hitmarker()
	if hm:
		hm.flash_hit(TacticalHitmarker.HitType.FATAL)
