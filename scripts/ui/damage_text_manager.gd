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

func _ready() -> void:
	z_index = 30
	top_level = true
	_initialize_pool()
	
	if Global.has_signal("enemy_hit"):
		Global.enemy_hit.connect(_on_enemy_hit)

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		var lbl = Label.new()
		lbl.visible = false
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.theme_override_constants/outline_size = 3
		lbl.theme_override_colors/font_outline_color = Color(0.04, 0.05, 0.08, 0.95)
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
		item.label.theme_override_font_sizes/font_size = 24
		item.label.theme_override_colors/font_color = Color(1.0, 0.28, 0.22, 1.0)
		item.label.scale = Vector2(1.2, 1.2)
	else:
		# Standard crisp white/light-yellow text (18pt)
		item.label.text = "%d" % int(amount)
		item.label.theme_override_font_sizes/font_size = 18
		item.label.theme_override_colors/font_color = Color(1.0, 0.96, 0.78, 1.0)
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
