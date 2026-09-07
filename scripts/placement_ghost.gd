class_name PlacementGhost
extends Node2D

## Holographic Ground Placement Projection for Tactical Deployables
## Renders a projected hologram / ghost circle indicating valid placement distance and orientation before [E] deployment.

@export var max_deploy_distance: float = 110.0

var active_type: int = 0
var current_stock: int = 0
var target_angle: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	z_index = 5
	top_level = true

func update_ghost(player_pos: Vector2, mouse_pos: Vector2, deploy_type: int, stock: int) -> void:
	active_type = deploy_type
	current_stock = stock
	
	var to_mouse = mouse_pos - player_pos
	target_angle = to_mouse.angle()
	global_position = player_pos + to_mouse.limit_length(max_deploy_distance)
	rotation = target_angle
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		_pulse += delta * 4.0
		queue_redraw()

func _draw() -> void:
	var base_col = Color(0.2, 0.95, 0.55, 0.75) if current_stock > 0 else Color(0.95, 0.25, 0.25, 0.55)
	var glow_col = base_col
	glow_col.a = 0.15 + sin(_pulse) * 0.08
	
	# 1. Outer holographic boundary ring
	draw_circle(Vector2.ZERO, 22.0, glow_col)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, base_col, 2.0)
	
	# 2. Four corner tactical ticks
	for i in range(4):
		var tick_ang = i * (PI * 0.5) + (_pulse * 0.2)
		var p1 = Vector2(cos(tick_ang), sin(tick_ang)) * 22.0
		var p2 = Vector2(cos(tick_ang), sin(tick_ang)) * 27.0
		draw_line(p1, p2, base_col, 1.5)
	
	# 3. Heading arrow
	var arrow_tip = Vector2(28.0, 0.0)
	var arrow_left = Vector2(18.0, -6.0)
	var arrow_right = Vector2(18.0, 6.0)
	draw_line(Vector2(8.0, 0.0), arrow_tip, base_col, 2.0)
	draw_line(arrow_left, arrow_tip, base_col, 2.0)
	draw_line(arrow_right, arrow_tip, base_col, 2.0)
	
	# 4. Item-specific holographic preview icon
	match active_type:
		0: # Barbed Wire
			draw_line(Vector2(-14, -8), Vector2(14, 8), base_col, 2.5)
			draw_line(Vector2(-14, 8), Vector2(14, -8), base_col, 2.5)
			draw_line(Vector2(-16, 0), Vector2(16, 0), base_col, 3.0)
		1: # Claymore Mine
			draw_rect(Rect2(-8, -12, 16, 24), base_col, false, 2.0)
			# Directional blast cone arc
			draw_arc(Vector2.ZERO, 36.0, -0.45, 0.45, 12, base_col, 1.5)
			draw_line(Vector2.ZERO, Vector2(cos(-0.45), sin(-0.45)) * 36.0, base_col, 1.0)
			draw_line(Vector2.ZERO, Vector2(cos(0.45), sin(0.45)) * 36.0, base_col, 1.0)
		2: # Sentry Turret
			draw_circle(Vector2.ZERO, 9.0, base_col)
			draw_line(Vector2(0, -3), Vector2(20, -3), base_col, 2.5)
			draw_line(Vector2(0, 3), Vector2(20, 3), base_col, 2.5)
			draw_line(Vector2(-6, -8), Vector2(0, 0), base_col, 2.0)
			draw_line(Vector2(-6, 8), Vector2(0, 0), base_col, 2.0)
