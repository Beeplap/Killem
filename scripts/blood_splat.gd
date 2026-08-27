extends Node2D

var splat_color: Color
var points: PackedVector2Array = []

func _ready() -> void:
	z_index = -1 # Render underneath entities
	splat_color = Color(randf_range(0.4, 0.6), 0.05, 0.05, randf_range(0.75, 0.95))
	
	# Generate organic splatter shape
	var count = randi_range(6, 10)
	var base_radius = randf_range(14.0, 26.0)
	for i in range(count):
		var angle = float(i) / float(count) * TAU
		var r = base_radius * randf_range(0.6, 1.5)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	
	queue_redraw()

func _draw() -> void:
	if points.size() > 2:
		draw_colored_polygon(points, splat_color)
		# A few outlying blood droplets
		for i in range(4):
			var droplet_pos = Vector2(randf_range(-35, 35), randf_range(-35, 35))
			draw_circle(droplet_pos, randf_range(2.0, 5.0), splat_color)
