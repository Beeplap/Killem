extends Control
class_name TacticalHitmarker

## Screen-Space Tactical Hitmarker & Punchy Audio Feedback
## Flashes animated diagonal 'X' ticks at screen center / crosshair on zombie hit.
## Normal (White), Critical (Crimson Red + micro-freeze), Fatal (Deep Amber + outward bloom).

enum HitType { NORMAL, CRITICAL, FATAL }

var current_hit_type: HitType = HitType.NORMAL
var active_timer: float = 0.0
var total_duration: float = 0.12
var current_scale: float = 1.0
var current_alpha: float = 0.0
var current_color: Color = Color.WHITE

# Audio feedback player
var audio_player: AudioStreamPlayer = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_audio()
	if Global.has_signal("enemy_hit"):
		Global.enemy_hit.connect(_on_enemy_hit)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Pickups_UI" if AudioServer.get_bus_index("Pickups_UI") >= 0 else "Master"
	add_child(audio_player)
	
	# Generate procedural punchy tactical 'thwip/crunch' hit confirmed sound
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.08
	audio_player.stream = gen

func play_hit_audio(pitch_scale_mult: float = 1.0) -> void:
	# Check if AudioManager has dedicated hit sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_sound"):
		audio_mgr.play_ui_sound("hit")
	elif Global.has_method("play_sound"):
		Global.play_sound("hit")
	
	if audio_player and audio_player.stream is AudioStreamGenerator:
		audio_player.pitch_scale = randf_range(0.95, 1.05) * pitch_scale_mult
		audio_player.play()
		var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback()
		if playback:
			var frames = 800
			for i in range(frames):
				var t = float(i) / 22050.0
				var decay = exp(-t * 85.0)
				# Snappy click + punchy low crunch
				var sample = (sin(t * 1200.0 * TAU) * 0.4 + (randf() * 2.0 - 1.0) * 0.6) * decay
				playback.push_frame(Vector2(sample, sample))

func _on_enemy_hit(_enemy: Node2D, _amount: float, is_crit: bool, is_fatal: bool, _hit_dir: Vector2) -> void:
	if is_fatal:
		flash_hit(HitType.FATAL)
	elif is_crit:
		flash_hit(HitType.CRITICAL)
	else:
		flash_hit(HitType.NORMAL)

func flash_hit(type: HitType) -> void:
	current_hit_type = type
	
	match type:
		HitType.NORMAL:
			total_duration = 0.12
			active_timer = total_duration
			current_color = Color(1.0, 1.0, 1.0, 1.0)
			current_scale = 1.25
			play_hit_audio(1.0)
		HitType.CRITICAL:
			total_duration = 0.16
			active_timer = total_duration
			current_color = Color(1.0, 0.15, 0.22, 1.0)
			current_scale = 1.45
			play_hit_audio(1.2)
			# Critical Hit micro-freeze: Engine.time_scale = 0.05 for 0.03s
			_trigger_crit_microfreeze()
		HitType.FATAL:
			total_duration = 0.20
			active_timer = total_duration
			current_color = Color(1.0, 0.72, 0.18, 1.0)
			current_scale = 1.1
			play_hit_audio(0.85)
	
	current_alpha = 1.0
	queue_redraw()

func _trigger_crit_microfreeze() -> void:
	Engine.time_scale = 0.05
	var tree = get_tree()
	if tree:
		tree.create_timer(0.03, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
		)

func _process(delta: float) -> void:
	# Pin to mouse cursor / crosshair position in screen space
	global_position = get_viewport().get_mouse_position()
	
	if active_timer > 0.0:
		active_timer -= delta
		var progress = 1.0 - (active_timer / total_duration)
		
		match current_hit_type:
			HitType.NORMAL:
				current_scale = lerpf(1.25, 1.0, progress)
				current_alpha = 1.0 - progress * 0.5
			HitType.CRITICAL:
				current_scale = lerpf(1.45, 1.1, progress)
				current_alpha = 1.0 - progress * 0.4
			HitType.FATAL:
				# Deep amber ticks that expand outward and fade over 0.2s
				current_scale = lerpf(1.1, 1.8, progress)
				current_alpha = 1.0 - progress
		
		if active_timer <= 0.0:
			current_alpha = 0.0
		
		queue_redraw()

func _draw() -> void:
	if current_alpha <= 0.01:
		return
	
	var col = current_color
	col.a = current_alpha
	var shadow_col = Color(0.02, 0.03, 0.05, current_alpha * 0.85)
	
	var gap: float = 6.0 * current_scale
	var tick_len: float = 7.0 * current_scale
	var thickness: float = 2.0
	
	# Four diagonal pips forming 'X'
	var dirs = [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1)
	]
	
	for d in dirs:
		var p1 = d * gap
		var p2 = d * (gap + tick_len)
		# Shadow
		draw_line(p1, p2, shadow_col, thickness + 1.6)
		# Foreground tick
		draw_line(p1, p2, col, thickness)
