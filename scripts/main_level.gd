extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $ZombieSpawner

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# 1. Open Terrain Ground (Well-lit post-apocalyptic mud, dirt, and cracked asphalt)
	var map_size = Vector2(2800, 2800)
	var half_size = map_size * 0.5
	var ground_rect = Rect2(-half_size, map_size)
	
	# Base dirt ground
	draw_rect(ground_rect, Color(0.20, 0.19, 0.17))
	
	# Secondary cold dark asphalt road cutting diagonally across map
	var road_points = PackedVector2Array([
		Vector2(-half_size.x, -220),
		Vector2(half_size.x, 340),
		Vector2(half_size.x, 500),
		Vector2(-half_size.x, -60)
	])
	draw_colored_polygon(road_points, Color(0.14, 0.15, 0.17))
	
	# Cracked road markings
	for x in range(-1200, 1200, 120):
		var y = x * 0.23 + 60
		draw_line(Vector2(x, y), Vector2(x + 50, y + 12), Color(0.85, 0.75, 0.2, 0.45), 3.0)
	
	# 2. Broken Railway Tracks (Gravel ballast, wooden ties, steel rails, hazard stripes)
	var rail_start = Vector2(-1300, -550)
	var rail_dir = Vector2(1.0, 0.65).normalized()
	var rail_length = 2600.0
	var track_width = 38.0
	var perp = Vector2(-rail_dir.y, rail_dir.x)
	
	# Ballast gravel bed
	var ballast_poly = PackedVector2Array([
		rail_start - perp * 34.0,
		rail_start + rail_dir * rail_length - perp * 34.0,
		rail_start + rail_dir * rail_length + perp * 34.0,
		rail_start + perp * 34.0
	])
	draw_colored_polygon(ballast_poly, Color(0.28, 0.28, 0.30))
	
	# Wooden Ties (Sleepers)
	var tie_spacing = 24.0
	var tie_count = int(rail_length / tie_spacing)
	for i in range(tie_count):
		var tie_center = rail_start + rail_dir * (float(i) * tie_spacing)
		var p1 = tie_center - perp * 26.0
		var p2 = tie_center + perp * 26.0
		draw_line(p1, p2, Color(0.38, 0.26, 0.16), 7.0)
	
	# Dual Steel Rails
	var rail1_start = rail_start - perp * (track_width * 0.5)
	var rail1_end = rail1_start + rail_dir * rail_length
	var rail2_start = rail_start + perp * (track_width * 0.5)
	var rail2_end = rail2_start + rail_dir * rail_length
	
	draw_line(rail1_start, rail1_end, Color(0.55, 0.58, 0.65), 3.5)
	draw_line(rail2_start, rail2_end, Color(0.55, 0.58, 0.65), 3.5)
	
	# Steel Rail highlights
	draw_line(rail1_start, rail1_end, Color(0.8, 0.85, 0.95), 1.2)
	draw_line(rail2_start, rail2_end, Color(0.8, 0.85, 0.95), 1.2)
	
	# Yellow & Black Caution Hazard Platform on Railway
	var platform_pos = rail_start + rail_dir * 1100.0
	var plat_w = 70.0
	var plat_h = 100.0
	var plat_rect = Rect2(platform_pos - Vector2(plat_w * 0.5, plat_h * 0.5), Vector2(plat_w, plat_h))
	draw_rect(plat_rect, Color(0.24, 0.25, 0.28))
	draw_rect(plat_rect, Color(0.9, 0.8, 0.1), false, 4.0)
	
	# Hazard Diagonal Stripes across platform
	for s in range(-30, 90, 16):
		draw_line(Vector2(plat_rect.position.x, plat_rect.position.y + s), Vector2(plat_rect.position.x + plat_w, plat_rect.position.y + s + 20), Color(0.1, 0.1, 0.1), 3.5)
	
	# 3. Overgrown dry yellowish-green grass patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(120):
		var grass_pos = Vector2(rng.randf_range(-1200, 1200), rng.randf_range(-1200, 1200))
		var grass_col = Color(0.32, 0.36, 0.22, 0.8)
		for t in range(4):
			var tip = grass_pos + Vector2(rng.randf_range(-8, 8), rng.randf_range(-14, -6))
			draw_line(grass_pos, tip, grass_col, 1.8)
