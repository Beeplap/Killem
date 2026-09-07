class_name TacticalCrosshair
extends Control

var bloom: float = 0.0
@export var recovery_speed: float = 48.0
var is_locked_on: bool = false
var normal_color: Color = Color(0.2, 0.95, 0.85, 0.95)
var lock_color: Color = Color(1.0, 0.25, 0.25, 0.95)
var shadow_color: Color = Color(0.02, 0.04, 0.06, 0.85)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_process(true)

func add_bloom(amount: float) -> void:
	bloom = clampf(bloom + amount, 0.0, 24.0)

func _process(delta: float) -> void:
	# Hide in-game custom reticle if paused or OS cursor is visible
	if get_tree().paused or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		visible = false
		return
	
	visible = true
	# Keep crosshair pinned to current viewport mouse cursor
	global_position = get_viewport().get_mouse_position()
	
	# Smooth bloom recovery
	if bloom > 0.0:
		bloom = move_toward(bloom, 0.0, recovery_speed * delta)
	
	# Check if reticle is hovering near an enemy in screen space
	is_locked_on = false
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		if player.has_method("get_global_mouse_position"):
			var mouse_world = player.get_global_mouse_position()
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy is Node2D and enemy.global_position.distance_to(mouse_world) < 32.0:
					is_locked_on = true
					break
		else:
			var cam = get_viewport().get_camera_3d()
			if cam:
				var mouse_screen = get_viewport().get_mouse_position()
				var enemies = get_tree().get_nodes_in_group("enemies")
				for enemy in enemies:
					if is_instance_valid(enemy) and enemy is Node3D:
						if not cam.is_position_behind(enemy.global_position):
							var enemy_screen = cam.unproject_position(enemy.global_position)
							if enemy_screen.distance_to(mouse_screen) < 40.0:
								is_locked_on = true
								break
	
	queue_redraw()

func _draw() -> void:
	var col = lock_color if is_locked_on else normal_color
	var gap: float = 6.0 + bloom * 0.65
	var length: float = 7.0
	var thickness: float = 2.0
	var shadow_th: float = thickness + 1.8
	
	# 1. Dark high-contrast shadow layer underneath
	draw_circle(Vector2.ZERO, 3.2, shadow_color)
	draw_line(Vector2(0, -gap - length), Vector2(0, -gap), shadow_color, shadow_th)
	draw_line(Vector2(0, gap), Vector2(0, gap + length), shadow_color, shadow_th)
	draw_line(Vector2(-gap - length, 0), Vector2(-gap, 0), shadow_color, shadow_th)
	draw_line(Vector2(gap, 0), Vector2(gap + length, 0), shadow_color, shadow_th)
	
	# 2. Foreground high-contrast illuminated crosshair
	draw_circle(Vector2.ZERO, 2.0, col)
	draw_line(Vector2(0, -gap - length), Vector2(0, -gap), col, thickness)
	draw_line(Vector2(0, gap), Vector2(0, gap + length), col, thickness)
	draw_line(Vector2(-gap - length, 0), Vector2(-gap, 0), col, thickness)
	draw_line(Vector2(gap, 0), Vector2(gap + length, 0), col, thickness)
	
	# 3. Tactical Corner Brackets with shadow
	var bracket_dist: float = gap + 7.0
	var b_len: float = 4.0
	
	# Shadows
	draw_line(Vector2(-bracket_dist, -bracket_dist), Vector2(-bracket_dist + b_len, -bracket_dist), shadow_color, 2.6)
	draw_line(Vector2(-bracket_dist, -bracket_dist), Vector2(-bracket_dist, -bracket_dist + b_len), shadow_color, 2.6)
	draw_line(Vector2(bracket_dist, -bracket_dist), Vector2(bracket_dist - b_len, -bracket_dist), shadow_color, 2.6)
	draw_line(Vector2(bracket_dist, -bracket_dist), Vector2(bracket_dist, -bracket_dist + b_len), shadow_color, 2.6)
	draw_line(Vector2(-bracket_dist, bracket_dist), Vector2(-bracket_dist + b_len, bracket_dist), shadow_color, 2.6)
	draw_line(Vector2(-bracket_dist, bracket_dist), Vector2(-bracket_dist, bracket_dist - b_len), shadow_color, 2.6)
	draw_line(Vector2(bracket_dist, bracket_dist), Vector2(bracket_dist - b_len, bracket_dist), shadow_color, 2.6)
	draw_line(Vector2(bracket_dist, bracket_dist), Vector2(bracket_dist, bracket_dist - b_len), shadow_color, 2.6)
	
	# Bright outlines
	draw_line(Vector2(-bracket_dist, -bracket_dist), Vector2(-bracket_dist + b_len, -bracket_dist), col, 1.4)
	draw_line(Vector2(-bracket_dist, -bracket_dist), Vector2(-bracket_dist, -bracket_dist + b_len), col, 1.4)
	draw_line(Vector2(bracket_dist, -bracket_dist), Vector2(bracket_dist - b_len, -bracket_dist), col, 1.4)
	draw_line(Vector2(bracket_dist, -bracket_dist), Vector2(bracket_dist, -bracket_dist + b_len), col, 1.4)
	draw_line(Vector2(-bracket_dist, bracket_dist), Vector2(-bracket_dist + b_len, bracket_dist), col, 1.4)
	draw_line(Vector2(-bracket_dist, bracket_dist), Vector2(-bracket_dist, bracket_dist - b_len), col, 1.4)
	draw_line(Vector2(bracket_dist, bracket_dist), Vector2(bracket_dist - b_len, bracket_dist), col, 1.4)
	draw_line(Vector2(bracket_dist, bracket_dist), Vector2(bracket_dist, bracket_dist - b_len), col, 1.4)
