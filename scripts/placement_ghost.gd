class_name PlacementGhost
extends Node2D

## Holographic Ground Placement Projection for Tactical Deployables & Throwables
## Renders rotated blueprint hologram (Green: Valid, Red: Blocked/Out of stock),
## trajectory arcs, and placement previews. Hidden by default unless armed.

@export var max_deploy_distance: float = 110.0
@export var max_throw_distance: float = 260.0

var active_slot: int = 0 # 0: Grenade, 1: Barbwire, 2: Turret
var current_stock: int = 0
var is_armed: bool = false
var is_valid: bool = true
var is_valid_placement: bool:
	get: return is_valid
var is_turret_limit_reached: bool = false

var blueprint_rotation: float = 0.0
var player_world_pos: Vector2 = Vector2.ZERO
var _pulse: float = 0.0

func _ready() -> void:
	z_index = 8
	top_level = true
	visible = false

func set_armed(armed: bool) -> void:
	is_armed = armed
	visible = armed
	queue_redraw()

func rotate_blueprint(delta_angle: float) -> void:
	blueprint_rotation = fposmod(blueprint_rotation + delta_angle, TAU)
	rotation = blueprint_rotation
	queue_redraw()

func update_ghost(p_pos: Vector2, mouse_pos: Vector2, slot: int, stock: int, turret_capped: bool = false) -> void:
	if not is_armed:
		visible = false
		return
	
	visible = true
	player_world_pos = p_pos
	active_slot = slot
	current_stock = stock
	is_turret_limit_reached = turret_capped
	
	var to_mouse = mouse_pos - p_pos
	if active_slot == 0:
		# Grenade throwable
		global_position = p_pos + to_mouse.limit_length(max_throw_distance)
		rotation = 0.0
		is_valid = (stock > 0)
	else:
		# Ground deployable with mouse-wheel rotation
		global_position = p_pos + to_mouse.limit_length(max_deploy_distance)
		rotation = blueprint_rotation
		
		# Collision obstacle check
		var clear = _check_clearance(global_position, rotation, active_slot)
		var capped = (active_slot == 2 and is_turret_limit_reached)
		is_valid = clear and (stock > 0) and not capped
	
	queue_redraw()

func _check_clearance(pos: Vector2, rot: float, slot: int) -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return true
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 4 # Obstacles / Walls / Props
	query.transform = Transform2D(rot, pos)
	
	if slot == 1:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(70.0, 26.0)
		query.shape = rect
	else:
		var circle = CircleShape2D.new()
		circle.radius = 20.0
		query.shape = circle
	
	var results = space_state.intersect_shape(query, 1)
	return results.is_empty()

func _process(delta: float) -> void:
	if visible and is_armed:
		_pulse += delta * 4.5
		queue_redraw()

func _draw() -> void:
	if not is_armed:
		return
	
	var base_col = Color(0.2, 0.95, 0.55, 0.85) if is_valid else Color(0.95, 0.25, 0.25, 0.85)
	var fill_col = base_col
	fill_col.a = 0.20 + sin(_pulse) * 0.08
	
	match active_slot:
		0:
			# 1. Grenade trajectory arc from player to target
			var p_local = to_local(player_world_pos)
			var steps = 14
			for i in range(steps):
				if i % 2 == 0:
					var pt1 = p_local.lerp(Vector2.ZERO, float(i) / float(steps))
					var pt2 = p_local.lerp(Vector2.ZERO, float(i + 1) / float(steps))
					draw_line(pt1, pt2, Color(base_col.r, base_col.g, base_col.b, 0.5), 1.8)
			
			# Target landing circle & blast radius preview
			draw_circle(Vector2.ZERO, 16.0, fill_col)
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, base_col, 2.0)
			draw_arc(Vector2.ZERO, 130.0, 0.0, TAU, 48, Color(base_col.r, base_col.g, base_col.b, 0.15), 1.0)
			
			# Crosshair ticks
			draw_line(Vector2(-22, 0), Vector2(-16, 0), base_col, 1.5)
			draw_line(Vector2(16, 0), Vector2(22, 0), base_col, 1.5)
			draw_line(Vector2(0, -22), Vector2(0, -16), base_col, 1.5)
			draw_line(Vector2(0, 16), Vector2(0, 22), base_col, 1.5)
		
		1:
			# 2. Barbwire Blueprint (scaled +35% to 72x28)
			var rect = Rect2(-36, -14, 72, 28)
			draw_rect(rect, fill_col, true)
			draw_rect(rect, base_col, false, 2.0)
			
			# Wire coils pattern
			draw_line(Vector2(-36, 0), Vector2(36, 0), base_col, 2.0)
			draw_line(Vector2(-36, -8), Vector2(36, 8), base_col, 1.5)
			draw_line(Vector2(-36, 8), Vector2(36, -8), base_col, 1.5)
			
			# Rotation orientation notch
			draw_line(Vector2(0, -14), Vector2(0, -24), base_col, 2.0)
			draw_circle(Vector2(0, -24), 3.5, base_col)
		
		2:
			# 3. Turret Blueprint
			draw_circle(Vector2.ZERO, 20.0, fill_col)
			draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, base_col, 2.0)
			
			# Tripod legs
			draw_line(Vector2.ZERO, Vector2(-14, -14), base_col, 2.0)
			draw_line(Vector2.ZERO, Vector2(-14, 14), base_col, 2.0)
			draw_line(Vector2.ZERO, Vector2(16, 0), base_col, 2.5)
			
			# Twin gun barrels pointing along +X
			draw_line(Vector2(6, -4), Vector2(28, -4), base_col, 2.5)
			draw_line(Vector2(6, 4), Vector2(28, 4), base_col, 2.5)
			
			# Effective range perimeter preview
			draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.12), 1.0)
