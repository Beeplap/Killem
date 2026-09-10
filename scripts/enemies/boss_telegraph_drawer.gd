extends Node2D
class_name BossTelegraphDrawer

@onready var boss: GoliathBoss = get_parent() as GoliathBoss

func _draw() -> void:
	if boss == null or boss.active_telegraph_type == GoliathBoss.TelegraphType.NONE:
		return
	
	var progress = clampf(boss.telegraph_timer / maxf(0.001, boss.telegraph_duration), 0.0, 1.0)
	var pulse = sin(Time.get_ticks_msec() * 0.016) * 0.5 + 0.5
	var fill_color = Color(1.0, 0.12, 0.15, 0.25 + pulse * 0.15)
	var border_color = Color(1.0, 0.2, 0.25, 0.85 + pulse * 0.15)
	var progress_fill = Color(1.0, 0.15, 0.15, 0.45)
	
	match boss.active_telegraph_type:
		GoliathBoss.TelegraphType.CONE_180:
			draw_cone_180(boss.telegraph_angle, boss.telegraph_range, progress, fill_color, border_color, progress_fill)
		GoliathBoss.TelegraphType.LINEAR_LANE:
			draw_linear_lane(boss.telegraph_angle, boss.telegraph_range, boss.telegraph_width, progress, fill_color, border_color)
		GoliathBoss.TelegraphType.CIRCLE:
			draw_circle_telegraph(boss.telegraph_range, progress, fill_color, border_color, progress_fill)

func draw_cone_180(center_angle: float, radius: float, progress: float, fill_col: Color, border_col: Color, prog_col: Color) -> void:
	var start_angle = center_angle - (PI / 2.0)
	var end_angle = center_angle + (PI / 2.0)
	var segments = 32
	
	# Full warning sector
	var points: PackedVector2Array = [Vector2.ZERO]
	for i in range(segments + 1):
		var theta = start_angle + (float(i) / segments) * PI
		points.append(Vector2(cos(theta), sin(theta)) * radius)
	draw_colored_polygon(points, fill_col)
	
	# Inner expanding progress sector
	var prog_r = radius * progress
	var prog_points: PackedVector2Array = [Vector2.ZERO]
	for i in range(segments + 1):
		var theta = start_angle + (float(i) / segments) * PI
		prog_points.append(Vector2(cos(theta), sin(theta)) * prog_r)
	draw_colored_polygon(prog_points, prog_col)
	
	# High-contrast outline
	var outline_pts: PackedVector2Array = []
	for i in range(segments + 1):
		var theta = start_angle + (float(i) / segments) * PI
		outline_pts.append(Vector2(cos(theta), sin(theta)) * radius)
	outline_pts.append(Vector2.ZERO)
	outline_pts.insert(0, Vector2.ZERO)
	draw_polyline(outline_pts, border_col, 3.0)

func draw_linear_lane(angle: float, length: float, width: float, progress: float, fill_col: Color, border_col: Color) -> void:
	var forward = Vector2.from_angle(angle)
	var perp = Vector2(-forward.y, forward.x) * (width * 0.5)
	
	var p1 = perp
	var p2 = forward * length + perp
	var p3 = forward * length - perp
	var p4 = -perp
	
	draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), fill_col)
	
	# Expanding progress lane
	var prog_len = length * progress
	var pr2 = forward * prog_len + perp
	var pr3 = forward * prog_len - perp
	draw_colored_polygon(PackedVector2Array([p1, pr2, pr3, p4]), Color(1.0, 0.15, 0.15, 0.4))
	
	# Outline
	draw_line(p1, p2, border_col, 3.0)
	draw_line(p2, p3, border_col, 3.0)
	draw_line(p3, p4, border_col, 3.0)
	draw_line(p4, p1, border_col, 3.0)
	
	# Animated advancing chevrons
	var phase_offset = fmod(Time.get_ticks_msec() * 0.003, 1.0)
	for i in range(5):
		var frac = fmod(float(i) / 5.0 + phase_offset, 1.0)
		var center_pt = forward * (length * frac)
		var c1 = center_pt - forward * 15.0 + perp * 0.75
		var c2 = center_pt
		var c3 = center_pt - forward * 15.0 - perp * 0.75
		draw_polyline(PackedVector2Array([c1, c2, c3]), border_col, 2.5)

func draw_circle_telegraph(radius: float, progress: float, fill_col: Color, border_col: Color, prog_col: Color) -> void:
	draw_circle(Vector2.ZERO, radius, fill_col)
	draw_circle(Vector2.ZERO, radius * progress, prog_col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_col, 3.0)
