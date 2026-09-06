class_name ProceduralTextures
extends RefCounted

static var _ground_texture: ImageTexture = null
static var _wall_texture: ImageTexture = null
static var _rail_texture: ImageTexture = null
static var _shadow_texture: ImageTexture = null
static var _casing_texture: ImageTexture = null

static func get_ground_texture() -> ImageTexture:
	if _ground_texture != null:
		return _ground_texture
	
	var width: int = 512
	var height: int = 512
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	# Simplex noise for base terrain variation (frequency 0.05)
	var base_noise: FastNoiseLite = FastNoiseLite.new()
	base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	base_noise.frequency = 0.05
	base_noise.seed = 42
	
	# High-frequency gravel noise for fine stones and ballast grit
	var gravel_noise: FastNoiseLite = FastNoiseLite.new()
	gravel_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	gravel_noise.frequency = 0.32
	gravel_noise.seed = 99
	
	var col_dark: Color = Color("#22252a")
	var col_light: Color = Color("#353a42")
	var col_pebble: Color = Color("#16181c")
	
	for y in range(height):
		for x in range(width):
			var n_base: float = (base_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var n_gravel: float = gravel_noise.get_noise_2d(float(x), float(y))
			
			var c: Color = col_dark.lerp(col_light, n_base)
			
			# Gravel grain & ballast stones
			if n_gravel > 0.42:
				c = c.lerp(Color(0.42, 0.46, 0.52), (n_gravel - 0.42) * 1.5)
			elif n_gravel < -0.38:
				c = c.lerp(col_pebble, (-n_gravel - 0.38) * 1.6)
			else:
				var grit: float = n_gravel * 0.04
				c += Color(grit, grit, grit, 0.0)
			
			img.set_pixel(x, y, c)
	
	_ground_texture = ImageTexture.create_from_image(img)
	return _ground_texture

static func get_concrete_wall_texture() -> ImageTexture:
	if _wall_texture != null:
		return _wall_texture
	
	var width: int = 256
	var height: int = 256
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var streak_noise: FastNoiseLite = FastNoiseLite.new()
	streak_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	streak_noise.frequency = 0.08
	streak_noise.seed = 123
	
	var grunge_noise: FastNoiseLite = FastNoiseLite.new()
	grunge_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	grunge_noise.frequency = 0.16
	grunge_noise.seed = 456
	
	var col_base: Color = Color("#4a515c")
	var col_dark: Color = Color("#2d3137")
	var col_light: Color = Color("#646d79")
	
	for y in range(height):
		for x in range(width):
			# Directional vertical streaks (weathering drainage)
			var n_streak: float = streak_noise.get_noise_2d(float(x) * 2.2, float(y) * 0.12)
			var n_grunge: float = grunge_noise.get_noise_2d(float(x), float(y))
			
			var factor: float = (n_streak * 0.65) + (n_grunge * 0.35)
			var c: Color = col_base
			if factor < 0.0:
				c = col_base.lerp(col_dark, clampf(-factor * 1.2, 0.0, 1.0))
			else:
				c = col_base.lerp(col_light, clampf(factor * 1.2, 0.0, 1.0))
			
			# Distressed grunge near edges
			var edge_dist: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
			if edge_dist < 10:
				var edge_fade: float = float(edge_dist) / 10.0
				c = c.lerp(col_dark, (1.0 - edge_fade) * 0.6)
			
			img.set_pixel(x, y, c)
	
	_wall_texture = ImageTexture.create_from_image(img)
	return _wall_texture

static func get_metal_rail_texture() -> ImageTexture:
	if _rail_texture != null:
		return _rail_texture
	
	var width: int = 256
	var height: int = 64
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var rust_noise: FastNoiseLite = FastNoiseLite.new()
	rust_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	rust_noise.frequency = 0.14
	rust_noise.seed = 777
	
	var col_steel: Color = Color("#555d69")
	var col_highlight: Color = Color("#9ba5b4")
	var col_shadow: Color = Color("#282d34")
	var col_rust: Color = Color("#8b4513") # Rust mottling
	
	for y in range(height):
		var is_highlight: bool = (y >= 4 and y <= 9)
		var is_dark_crevice: bool = (y >= 54 and y <= 62)
		
		for x in range(width):
			var n_rust: float = rust_noise.get_noise_2d(float(x), float(y))
			var c: Color = col_steel
			
			if is_highlight:
				c = col_highlight
			elif is_dark_crevice:
				c = col_shadow
			
			# Rust mottling (#8b4513 specs)
			if n_rust > 0.28 and not is_highlight:
				var rust_intensity: float = clampf((n_rust - 0.28) * 2.4, 0.0, 0.88)
				c = c.lerp(col_rust, rust_intensity)
			
			img.set_pixel(x, y, c)
	
	_rail_texture = ImageTexture.create_from_image(img)
	return _rail_texture

static func get_shadow_texture() -> ImageTexture:
	if _shadow_texture != null:
		return _shadow_texture
	
	var width: int = 48
	var height: int = 24
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var cx: float = float(width) * 0.5
	var cy: float = float(height) * 0.5
	var rx: float = cx
	var ry: float = cy
	
	for y in range(height):
		for x in range(width):
			var dx: float = (float(x) + 0.5 - cx) / rx
			var dy: float = (float(y) + 0.5 - cy) / ry
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq < 1.0:
				var alpha: float = exp(-dist_sq * 2.5) * 0.85
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	
	_shadow_texture = ImageTexture.create_from_image(img)
	return _shadow_texture

static func get_casing_texture() -> ImageTexture:
	if _casing_texture != null:
		return _casing_texture
	
	var width: int = 6
	var height: int = 3
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var col_brass: Color = Color(0.92, 0.78, 0.28, 1.0)
	var col_rim: Color = Color(0.65, 0.52, 0.15, 1.0)
	var col_shine: Color = Color(1.0, 0.96, 0.68, 1.0)
	
	for y in range(height):
		for x in range(width):
			if x == 0:
				img.set_pixel(x, y, col_rim)
			elif y == 0:
				img.set_pixel(x, y, col_shine)
			else:
				img.set_pixel(x, y, col_brass)
	
	_casing_texture = ImageTexture.create_from_image(img)
	return _casing_texture

static func add_drop_shadow(parent: Node2D, offset: Vector2 = Vector2(0, 12), scale_factor: Vector2 = Vector2(0.85, 0.45)) -> Sprite2D:
	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "DropShadow"
	shadow.texture = get_shadow_texture()
	shadow.position = offset
	shadow.scale = scale_factor
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.45)
	shadow.show_behind_parent = true
	shadow.z_as_relative = true
	shadow.z_index = -1
	parent.add_child(shadow)
	parent.move_child(shadow, 0)
	return shadow
