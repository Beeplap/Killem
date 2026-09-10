extends Node2D
class_name PingMarker

## Tactical Ping Marker
## Displays a synchronized tactical marker in the world for 6.0 seconds.
## Visual styles:
## - MOVE (Yellow Chevron): "MOVE HERE"
## - ENEMY (Crimson Crosshair): "FOCUS TARGET", follows tracked enemy node
## - SUPPLIES (Cyan Diamond): "SUPPLIES"

enum PingType { MOVE, ENEMY, SUPPLIES }

@export var ping_type: PingType = PingType.MOVE
@export var lifetime: float = 6.0

var time_alive: float = 0.0
var tracked_target: Node2D = null
var current_scale: float = 0.1
var target_scale: float = 1.0
var alpha_mult: float = 1.0

# Colors
const COLOR_MOVE: Color = Color(0.98, 0.85, 0.15, 1.0) # Tactical Amber/Yellow
const COLOR_ENEMY: Color = Color(1.0, 0.22, 0.2, 1.0) # Crimson Red
const COLOR_SUPPLIES: Color = Color(0.25, 0.8, 1.0, 1.0) # Tactical Cyan

func _ready() -> void:
	z_index = 40
	top_level = true
	queue_redraw()

func setup_ping(type: int, world_pos: Vector2, target: Node2D = null) -> void:
	ping_type = type as PingType
	global_position = world_pos
	tracked_target = target
	time_alive = 0.0
	current_scale = 0.1
	alpha_mult = 1.0
	
	# Play crisp tactical radio chirp on Foley bus
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound("radio_chatter", world_pos, AudioManager.BUS_FOLEY)
	else:
		Global.play_sound("radio_chatter")
	
	queue_redraw()

func _process(delta: float) -> void:
	time_alive += delta
	
	# Follow tracked target if still valid
	if tracked_target and is_instance_valid(tracked_target):
		global_position = tracked_target.global_position
	
	# Scale-in animation
	if current_scale < target_scale:
		current_scale = move_toward(current_scale, target_scale, delta * 8.0)
	
	# Fade-out in last 0.6 seconds
	var time_left = lifetime - time_alive
	if time_left <= 0.6:
		alpha_mult = clampf(time_left / 0.6, 0.0, 1.0)
	
	if time_alive >= lifetime:
		queue_free()
		return
	
	queue_redraw()

func _offset_points(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result = PackedVector2Array()
	for p in pts:
		result.append(p + offset)
	return result

func _draw() -> void:
	var base_col: Color
	var label_text: String
	
	match ping_type:
		PingType.MOVE:
			base_col = COLOR_MOVE
			label_text = "MOVE HERE"
		PingType.ENEMY:
			base_col = COLOR_ENEMY
			label_text = "FOCUS TARGET"
		PingType.SUPPLIES:
			base_col = COLOR_SUPPLIES
			label_text = "SUPPLIES"
	
	base_col.a *= alpha_mult
	var shadow_col = Color(0.04, 0.06, 0.08, 0.75 * alpha_mult)
	
	var pulse = sin(time_alive * 6.0)
	var float_y = sin(time_alive * 4.5) * 3.5
	var center = Vector2(0, -18 + float_y) * current_scale
	
	match ping_type:
		PingType.MOVE:
			# Downward Chevron 'v' shape
			var w = 12.0 * current_scale
			var h = 8.0 * current_scale
			var pts = PackedVector2Array([
				center + Vector2(-w, -h),
				center + Vector2(0, 0),
				center + Vector2(w, -h),
				center + Vector2(w, -h - 4.0 * current_scale),
				center + Vector2(0, -4.0 * current_scale),
				center + Vector2(-w, -h - 4.0 * current_scale)
			])
			# Drop shadow
			draw_colored_polygon(_offset_points(pts, Vector2(1.5, 2.0)), shadow_col)
			draw_colored_polygon(pts, base_col)
			
			# Secondary smaller chevron
			var pts2 = PackedVector2Array([
				center + Vector2(-w * 0.75, -h + 8.0 * current_scale),
				center + Vector2(0, 8.0 * current_scale),
				center + Vector2(w * 0.75, -h + 8.0 * current_scale),
				center + Vector2(w * 0.75, -h + 5.0 * current_scale),
				center + Vector2(0, 5.0 * current_scale),
				center + Vector2(-w * 0.75, -h + 5.0 * current_scale)
			])
			draw_colored_polygon(_offset_points(pts2, Vector2(1.5, 2.0)), shadow_col)
			draw_colored_polygon(pts2, base_col)
			
		PingType.ENEMY:
			# Tactical Pulsing Reticle / Crosshair
			var r = (14.0 + pulse * 2.0) * current_scale
			# Shadow circle
			draw_arc(center + Vector2(1.5, 2.0), r, 0, TAU, 32, shadow_col, 3.0 * current_scale)
			# Outer ring
			draw_arc(center, r, 0, TAU, 32, base_col, 2.5 * current_scale)
			
			# 4 Tick Marks
			var tick_len = 6.0 * current_scale
			var offset = r + 3.0 * current_scale
			draw_line(center + Vector2(-offset - tick_len, 0), center + Vector2(-offset, 0), base_col, 2.5 * current_scale)
			draw_line(center + Vector2(offset, 0), center + Vector2(offset + tick_len, 0), base_col, 2.5 * current_scale)
			draw_line(center + Vector2(0, -offset - tick_len), center + Vector2(0, -offset), base_col, 2.5 * current_scale)
			draw_line(center + Vector2(0, offset), center + Vector2(0, offset + tick_len), base_col, 2.5 * current_scale)
			
			# Center dot
			draw_circle(center, 2.5 * current_scale, base_col)
			
		PingType.SUPPLIES:
			# Rotated Diamond
			var d_size = (12.0 + pulse * 1.2) * current_scale
			var pts = PackedVector2Array([
				center + Vector2(0, -d_size),
				center + Vector2(d_size, 0),
				center + Vector2(0, d_size),
				center + Vector2(-d_size, 0)
			])
			draw_colored_polygon(_offset_points(pts, Vector2(1.5, 2.0)), shadow_col)
			draw_colored_polygon(pts, Color(base_col.r, base_col.g, base_col.b, 0.25 * alpha_mult))
			draw_polyline(pts, base_col, 2.5 * current_scale, true)
			# Inner supply dot
			draw_circle(center, 3.5 * current_scale, base_col)
	
	# Text Label with backing
	var font = ThemeDB.fallback_font
	if font:
		var font_size = int(11 * current_scale)
		if font_size >= 7:
			var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = center + Vector2(-text_size.x * 0.5, -20.0 * current_scale)
			
			# Dark badge background
			var badge_rect = Rect2(text_pos - Vector2(5, 2), text_size + Vector2(10, 4))
			draw_rect(badge_rect, Color(0.08, 0.1, 0.12, 0.85 * alpha_mult))
			draw_rect(badge_rect, Color(base_col.r, base_col.g, base_col.b, 0.6 * alpha_mult), false, 1.0)
			
			# Text string
			draw_string(font, text_pos + Vector2(0, text_size.y * 0.8), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, base_col)

