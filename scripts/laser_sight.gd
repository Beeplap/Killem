extends Node2D
class_name TacticalLaserSight

# Tactical Laser Sight & Dynamic Crosshair Targeting Beam
# Projects a weapon-mounted targeting beam tapering from muzzle to collision point.
# Displays intense red dot marker with subtle pulsing glow at hit points.
# Scatters beam angle dynamically based on continuous weapon recoil.

@export var max_range: float = 900.0
@export var beam_color_muzzle: Color = Color(1.0, 0.15, 0.15, 0.85)
@export var beam_color_tip: Color = Color(1.0, 0.1, 0.1, 0.35)
@export var dot_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var dot_glow_color: Color = Color(1.0, 0.1, 0.1, 0.35)

var raycast: RayCast2D = null
var current_scatter: float = 0.0
var target_scatter: float = 0.0
var hit_point_local: Vector2 = Vector2.ZERO
var is_colliding: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	z_index = 2
	_setup_raycast()

func _setup_raycast() -> void:
	raycast = RayCast2D.new()
	raycast.name = "LaserRayCast"
	raycast.enabled = true
	raycast.target_position = Vector2(max_range, 0)
	raycast.collision_mask = 6 # Environment (4) + Enemies (2)
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	add_child(raycast)

func _process(delta: float) -> void:
	pulse_time += delta * 12.0
	
	# Smoothly recover scatter toward zero
	current_scatter = move_toward(current_scatter, target_scatter, 4.0 * delta)
	target_scatter = move_toward(target_scatter, 0.0, 3.5 * delta)
	
	# Check parent / player firing for recoil scatter
	var player = get_parent()
	if player and player.has_signal("player_fired"):
		# If player has active recoil spread
		var spread = player.get("current_spread")
		if spread != null:
			target_scatter = spread
	
	_update_beam()
	queue_redraw()

func add_recoil_scatter(amount: float) -> void:
	target_scatter = min(target_scatter + amount, deg_to_rad(12.0))
	current_scatter = target_scatter

func _update_beam() -> void:
	if not raycast:
		return
	
	# Apply dynamic recoil scatter angle
	var scatter_angle = randf_range(-current_scatter, current_scatter) if current_scatter > 0.001 else 0.0
	var beam_dir = Vector2.RIGHT.rotated(scatter_angle)
	raycast.target_position = beam_dir * max_range
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		is_colliding = true
		hit_point_local = to_local(raycast.get_collision_point())
	else:
		is_colliding = false
		hit_point_local = raycast.target_position

func _draw() -> void:
	# 1. Laser Beam (thin core line + subtle wider line)
	# Gradient from muzzle to hit point
	var steps = 16
	var step_vec = hit_point_local / float(steps)
	for i in range(steps):
		var p_start = step_vec * float(i)
		var p_end = step_vec * float(i + 1)
		var t = float(i) / float(steps)
		var seg_color = beam_color_muzzle.lerp(beam_color_tip, t)
		
		# Core bright beam
		draw_line(p_start, p_end, seg_color, 1.4, true)
		# Outer glow beam
		draw_line(p_start, p_end, Color(seg_color.r, seg_color.g, seg_color.b, seg_color.a * 0.3), 3.0, true)
	
	# 2. Collision Dot Marker with pulsing glow
	if is_colliding:
		var pulse = (sin(pulse_time) * 0.5 + 0.5)
		var dot_rad = 2.4 + (current_scatter * 8.0)
		var glow_rad = dot_rad * (2.2 + pulse * 0.8)
		
		# Outer diffuse glow
		var glow_col = Color(dot_glow_color.r, dot_glow_color.g, dot_glow_color.b, dot_glow_color.a * (0.6 + pulse * 0.4))
		draw_circle(hit_point_local, glow_rad, glow_col)
		
		# Mid ring
		draw_arc(hit_point_local, dot_rad * 1.4, 0, TAU, 16, Color(1.0, 0.4, 0.3, 0.75), 1.0)
		
		# Core intense point
		draw_circle(hit_point_local, dot_rad, dot_color)
		draw_circle(hit_point_local, dot_rad * 0.4, Color(1.0, 1.0, 1.0, 0.9))
