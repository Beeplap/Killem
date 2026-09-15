class_name DamageTextManager
extends Node2D

## High-Performance Pooled Floating Combat Damage Text Engine
## Pre-allocates a pool of 30 Label instances to eliminate runtime allocation overhead during automatic fire.
## Animates upward drift with exponential alpha fade-out over 0.6s.

const POOL_SIZE: int = 30
const DURATION: float = 0.6

class TextItem:
	var label: Label
	var pos: Vector2
	var timer: float = 0.0
	var is_active: bool = false

var _pool: Array[TextItem] = []

static var instance: DamageTextManager = null

static func get_instance() -> DamageTextManager:
	if instance != null and is_instance_valid(instance):
		return instance
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	
	var existing = tree.root.find_child("DamageTextManager", true, false) as DamageTextManager
	if existing and is_instance_valid(existing):
		instance = existing
		return instance
	
	var canvas = CanvasLayer.new()
	canvas.layer = 95
	canvas.name = "DynamicDamageTextCanvas"
	
	var mgr = DamageTextManager.new()
	mgr.name = "DamageTextManager"
	canvas.add_child(mgr)
	tree.root.add_child.call_deferred(canvas)
	instance = mgr
	return instance

static func spawn_text(hit_pos, text: String, color: Color = Color.WHITE) -> void:
	var mgr = get_instance()
	if not mgr:
		return
	
	var screen_pos: Vector2 = Vector2.ZERO
	if hit_pos is Vector3:
		var cam: Camera3D = null
		if mgr.is_inside_tree() and mgr.get_viewport():
			cam = mgr.get_viewport().get_camera_3d()
		elif Engine.get_main_loop() and Engine.get_main_loop().root:
			cam = Engine.get_main_loop().root.get_camera_3d()
		
		if cam and is_instance_valid(cam):
			if cam.is_position_behind(hit_pos):
				return
			screen_pos = cam.unproject_position(hit_pos)
		else:
			screen_pos = Vector2(hit_pos.x * 20.0 + 300.0, hit_pos.z * 20.0 + 300.0)
	elif hit_pos is Vector2:
		screen_pos = hit_pos
	else:
		return
	
	mgr.spawn_custom_text(screen_pos, text, color)

func _ready() -> void:
	instance = self
	z_index = 30
	top_level = true
	_initialize_pool()
	
	if Global.has_signal("enemy_hit"):
		Global.enemy_hit.connect(_on_enemy_hit)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		var lbl = Label.new()
		lbl.visible = false
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
		add_child(lbl)
		
		var item = TextItem.new()
		item.label = lbl
		item.is_active = false
		_pool.append(item)

func _on_enemy_hit(enemy: Node2D, amount: float, is_crit: bool, _is_fatal: bool, _hit_dir: Vector2) -> void:
	if not is_instance_valid(enemy):
		return
	var impact_pos = enemy.global_position + Vector2(0, -28) # Top impact position
	spawn_damage_text(impact_pos, amount, is_crit)

func spawn_damage_text(world_pos: Vector2, amount: float, is_crit: bool = false) -> void:
	# Find available pooled item
	var item: TextItem = null
	for pooled in _pool:
		if not pooled.is_active:
			item = pooled
			break
	
	# If all 30 are active, steal the oldest one
	if item == null:
		var max_t: float = -1.0
		for pooled in _pool:
			if pooled.timer > max_t:
				max_t = pooled.timer
				item = pooled
	
	if item == null:
		return
	
	item.is_active = true
	item.timer = 0.0
	
	# Randomized horizontal scatter (+-15px)
	var scatter_x = randf_range(-15.0, 15.0)
	item.pos = world_pos + Vector2(scatter_x, 0)
	item.label.global_position = item.pos
	
	if is_crit:
		# Bold yellow/red critical text (24pt)
		item.label.text = "CRIT! %d" % int(amount)
		item.label.add_theme_font_size_override("font_size", 24)
		item.label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.22, 1.0))
		item.label.scale = Vector2(1.2, 1.2)
	else:
		# Standard crisp white/light-yellow text (18pt)
		item.label.text = "%d" % int(amount)
		item.label.add_theme_font_size_override("font_size", 18)
		item.label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
		item.label.scale = Vector2(1.0, 1.0)
	
	item.label.reset_size()
	item.label.global_position = item.pos - item.label.size * 0.5
	item.label.modulate = Color(1, 1, 1, 1)
	item.label.visible = true

func spawn_custom_text(pos_2d: Vector2, text: String, color: Color) -> void:
	var item: TextItem = null
	for pooled in _pool:
		if not pooled.is_active:
			item = pooled
			break
	
	if item == null:
		var max_t: float = -1.0
		for pooled in _pool:
			if pooled.timer > max_t:
				max_t = pooled.timer
				item = pooled
	
	if item == null:
		return
	
	item.is_active = true
	item.timer = 0.0
	
	var scatter_x = randf_range(-16.0, 16.0)
	item.pos = pos_2d + Vector2(scatter_x, -10.0)
	item.label.global_position = item.pos
	item.label.text = text
	
	var is_crit = (color == Color.YELLOW or color == Color(1.0, 0.28, 0.22, 1.0) or text.begins_with("CRIT") or (color.r > 0.9 and color.g > 0.7 and color.b < 0.3))
	if is_crit:
		item.label.add_theme_font_size_override("font_size", 24)
		item.label.add_theme_color_override("font_color", color)
		item.label.scale = Vector2(1.25, 1.25)
	else:
		item.label.add_theme_font_size_override("font_size", 18)
		item.label.add_theme_color_override("font_color", color)
		item.label.scale = Vector2(1.0, 1.0)
	
	item.label.reset_size()
	item.label.global_position = item.pos - item.label.size * 0.5
	item.label.modulate = Color(1, 1, 1, 1)
	item.label.visible = true

func _process(delta: float) -> void:
	for item in _pool:
		if not item.is_active:
			continue
		
		item.timer += delta
		var progress = item.timer / DURATION
		
		if progress >= 1.0:
			item.is_active = false
			item.label.visible = false
			continue
		
		# Animate upward drift (-55px/s) with ease out
		item.pos.y -= 55.0 * delta * (1.0 - progress * 0.4)
		item.label.global_position = item.pos - item.label.size * 0.5
		
		# Exponential alpha fade-out over 0.6s
		var alpha = clampf(1.0 - pow(progress, 1.8), 0.0, 1.0)
		item.label.modulate.a = alpha
