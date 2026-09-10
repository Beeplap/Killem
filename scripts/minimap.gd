extends Control
class_name TacticalMinimap

# Tactical Minimap / Arcade Radar HUD Component
# Uses mathematical 2D coordinate plotting for ultra-low render overhead (<0.1ms)
# Supports both 2D and 3D game coordinates seamlessly.

@export var radar_radius: float = 72.0
@export var world_detection_radius: float = 1200.0 # 2D pixel range or ~30m in 3D
@export var sweep_speed: float = 3.2

var sweep_angle: float = 0.0
var player_ref: Node = null
var is_3d: bool = false
var is_radar_jammed: bool = false
var radar_static_intensity: float = 0.0

func _ready() -> void:
	add_to_group("minimap")
	custom_minimum_size = Vector2(radar_radius * 2 + 16, radar_radius * 2 + 16)
	_find_player()

func set_jammed(jammed: bool) -> void:
	is_radar_jammed = jammed

func _find_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		player_ref = p
		is_3d = p is Node3D

func _process(delta: float) -> void:
	sweep_angle = fmod(sweep_angle + sweep_speed * delta, TAU)
	
	if is_radar_jammed:
		radar_static_intensity = move_toward(radar_static_intensity, 1.0, delta * 3.5)
	else:
		radar_static_intensity = move_toward(radar_static_intensity, 0.0, delta * 2.0)
	
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
	
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	
	# 1. Outer Frame & Background
	draw_circle(center, radar_radius + 4.0, Color(0.04, 0.07, 0.1, 0.88))
	draw_arc(center, radar_radius + 4.0, 0, TAU, 48, Color(0.12, 0.75, 0.9, 0.8), 2.0, true)
	draw_circle(center, radar_radius, Color(0.02, 0.04, 0.06, 0.92))
	
	# 2. Concentric Range Rings
	draw_arc(center, radar_radius * 0.33, 0, TAU, 32, Color(0.15, 0.45, 0.55, 0.35), 1.0, true)
	draw_arc(center, radar_radius * 0.66, 0, TAU, 36, Color(0.15, 0.45, 0.55, 0.35), 1.0, true)
	draw_arc(center, radar_radius, 0, TAU, 48, Color(0.2, 0.6, 0.7, 0.5), 1.5, true)
	
	# 3. Cardinal Crosshairs
	draw_line(center - Vector2(radar_radius, 0), center + Vector2(radar_radius, 0), Color(0.15, 0.45, 0.55, 0.25), 1.0)
	draw_line(center - Vector2(0, radar_radius), center + Vector2(0, radar_radius), Color(0.15, 0.45, 0.55, 0.25), 1.0)
	
	# 4. Rotating Radar Sweep Line with trailing sector
	var sweep_end = center + Vector2.from_angle(sweep_angle) * radar_radius
	draw_line(center, sweep_end, Color(0.2, 1.0, 0.7, 0.75), 1.5)
	
	# Draw sweep fade wedge (4 sample lines behind sweep)
	for i in range(1, 6):
		var trail_ang = sweep_angle - float(i) * 0.08
		var trail_end = center + Vector2.from_angle(trail_ang) * radar_radius
		var alpha = (6 - i) * 0.05
		draw_line(center, trail_end, Color(0.2, 1.0, 0.7, alpha), 1.0)
	
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	var p_pos = _get_entity_pos(player_ref)
	var p_heading = _get_player_heading()
	
	# 5. Extraction Zone / Objective Waypoints
	var extractions = get_tree().get_nodes_in_group("extraction_zone")
	if extractions.is_empty():
		# Try finding by name or class
		var ez = get_tree().root.find_child("ExtractionZone", true, false)
		if ez:
			extractions.append(ez)
	
	for evac in extractions:
		if is_instance_valid(evac):
			var evac_pos = _get_entity_pos(evac)
			var offset = evac_pos - p_pos
			var dist = offset.length()
			var evac_range = world_detection_radius if not is_3d else 50.0
			var radar_dist = (dist / evac_range) * radar_radius
			var is_clamped = radar_dist > radar_radius - 6.0
			radar_dist = min(radar_dist, radar_radius - 6.0)
			
			var blip_pos = center + offset.normalized() * radar_dist
			var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.5 + 0.5
			var evac_col = Color(1.0, 0.85, 0.15, 0.8 + pulse * 0.2)
			
			# Draw flashing diamond waypoint
			var d_size = 5.0 + pulse * 2.0
			var pts = PackedVector2Array([
				blip_pos + Vector2(0, -d_size),
				blip_pos + Vector2(d_size, 0),
				blip_pos + Vector2(0, d_size),
				blip_pos + Vector2(-d_size, 0)
			])
			draw_colored_polygon(pts, evac_col)
			if is_clamped:
				draw_arc(blip_pos, d_size + 2.0, 0, TAU, 12, Color(1, 0.9, 0.3, 0.7), 1.0)
	
	# 6. Objective Collectibles / Consoles
	var objectives = get_tree().get_nodes_in_group("objectives")
	for obj in objectives:
		if is_instance_valid(obj):
			var obj_pos = _get_entity_pos(obj)
			var offset = obj_pos - p_pos
			var dist = offset.length()
			var obj_range = world_detection_radius if not is_3d else 45.0
			if dist <= obj_range * 1.5:
				var radar_dist = min((dist / obj_range) * radar_radius, radar_radius - 5.0)
				var blip_pos = center + offset.normalized() * radar_dist
				draw_rect(Rect2(blip_pos - Vector2(3, 3), Vector2(6, 6)), Color(0.2, 0.9, 1.0, 0.85))
	
	# 7. Enemies (Regular & Elites / Bosses)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemy_range = world_detection_radius if not is_3d else 40.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var e_pos = _get_entity_pos(enemy)
		var offset = e_pos - p_pos
		var dist = offset.length()
		
		if dist > enemy_range:
			continue
		
		var radar_dist = (dist / enemy_range) * radar_radius
		var blip_pos = center + offset.normalized() * radar_dist
		
		var is_alpha = enemy.get("is_alpha_target") == true
		var is_boss = enemy.is_in_group("boss") or (enemy.get("max_health") != null and enemy.max_health > 400.0)
		var is_mutator = (enemy.get("mutation_affix") != null and enemy.mutation_affix != 0) or enemy.is_in_group("elite_mutator")
		var is_elite = is_boss or is_mutator or (enemy.get("zombie_type") != null and (enemy.zombie_type == 2 or enemy.zombie_type == 5))
		
		# Radar Jamming / Static Jitter
		if radar_static_intensity > 0.0:
			var jitter = Vector2(randf_range(-6.5, 6.5), randf_range(-6.5, 6.5)) * radar_static_intensity
			blip_pos += jitter
		
		if is_alpha:
			# High-priority Orange Skull / Star Target Marker
			var pulse = sin(Time.get_ticks_msec() * 0.016) * 0.5 + 0.5
			var size_a = 6.5 + pulse * 2.2
			draw_circle(blip_pos, size_a, Color(1.0, 0.45, 0.1, 1.0))
			draw_circle(blip_pos, size_a * 0.55, Color(1.0, 0.9, 0.25, 1.0))
			draw_arc(blip_pos, size_a + 3.0, 0, TAU, 16, Color(1.0, 0.5, 0.1, 0.8), 1.2)
		elif is_elite:
			# Pulsing elite diamond / circle marker
			var pulse = sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5
			var size_e = 5.0 + pulse * 1.8
			var col = Color(0.2, 0.95, 0.4, 1.0) if (enemy.get("mutation_affix") == 1) else (Color(0.9, 0.2, 0.2, 1.0) if enemy.get("mutation_affix") == 3 else Color(1.0, 0.55, 0.15, 1.0))
			draw_circle(blip_pos, size_e, col)
			draw_circle(blip_pos, size_e * 0.5, Color(1, 1, 0.4, 1.0))
		else:
			# Regular zombie dot
			var dot_alpha = 0.85 if radar_static_intensity <= 0.0 else (0.85 - randf() * 0.5 * radar_static_intensity)
			draw_circle(blip_pos, 2.4, Color(1.0, 0.25, 0.25, dot_alpha))
	
	# Radar Jamming: Atmospheric Fog Static scanlines
	if radar_static_intensity > 0.05:
		for s in range(6):
			var sy = randf_range(-radar_radius * 0.85, radar_radius * 0.85)
			var sx = sqrt(max(0.0, radar_radius * radar_radius - sy * sy))
			var line_col = Color(0.18, 0.95, 0.55, randf_range(0.15, 0.42) * radar_static_intensity)
			draw_line(center + Vector2(-sx, sy), center + Vector2(sx, sy), line_col, randf_range(1.0, 2.2))
	
	# 8. Player Center Marker (Green Chevron pointing in aim/facing direction)
	var chevron_size = 6.5
	var p1 = center + p_heading * chevron_size
	var p2 = center + p_heading.rotated(2.4) * (chevron_size * 0.8)
	var p3 = center
	var p4 = center + p_heading.rotated(-2.4) * (chevron_size * 0.8)
	var p_poly = PackedVector2Array([p1, p2, p3, p4])
	draw_colored_polygon(p_poly, Color(0.2, 1.0, 0.4, 1.0))
	draw_circle(center, 2.0, Color(1, 1, 1, 1))

func _get_entity_pos(node: Node) -> Vector2:
	if node is Node2D:
		return node.global_position
	elif node is Node3D:
		return Vector2(node.global_position.x, node.global_position.z)
	return Vector2.ZERO

func _get_player_heading() -> Vector2:
	if not player_ref or not is_instance_valid(player_ref):
		return Vector2.UP
	
	if player_ref is Node2D:
		return Vector2.from_angle(player_ref.global_rotation)
	elif player_ref is Node3D:
		var fwd = -player_ref.global_transform.basis.z
		return Vector2(fwd.x, fwd.z).normalized()
	return Vector2.UP
