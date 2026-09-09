class_name LowHealthSensoryFeedback
extends CanvasLayer

## Low-Health Sensory Feedback & Muffled Combat Audio Controller
## Engages when Player HP < 25%:
## - Pulsing crimson vignette along screen edges synchronized to heartbeat tempo
## - Master bus low-pass audio muffling cut down to 800 Hz
## - Hollow rhythmic heartbeat audio pulsing
## - Smooth disengagement when restored above 25%

var is_critical: bool = false
var heartbeat_phase: float = 0.0
var lpf_effect: AudioEffectLowPassFilter = null
var lpf_index: int = -1

var vignette_rect: ColorRect = null
var heartbeat_player: AudioStreamPlayer = null

func _ready() -> void:
	layer = 15
	_setup_vignette()
	_setup_audio_filter()
	_setup_heartbeat_player()
	
	if Global.has_signal("health_changed"):
		Global.health_changed.connect(_on_health_changed)

func _setup_vignette() -> void:
	vignette_rect = ColorRect.new()
	vignette_rect.name = "CrimsonVignette"
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.anchors_preset = Control.PRESET_FULL_RECT
	vignette_rect.anchor_right = 1.0
	vignette_rect.anchor_bottom = 1.0
	vignette_rect.modulate = Color(1.0, 0.1, 0.1, 0.0)
	
	# Radial gradient vignette shader
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float vignette_power : hint_range(0.0, 5.0) = 2.2;
	uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.85;
	
	void fragment() {
		vec2 uv = UV - vec2(0.5);
		float dist = length(uv);
		float vig = smoothstep(0.25, 0.75, dist);
		COLOR = vec4(0.85, 0.04, 0.06, vig * vignette_intensity);
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	vignette_rect.material = mat
	add_child(vignette_rect)

func _setup_audio_filter() -> void:
	# Look for existing lowpass on Master bus or create one
	var bus_idx = 0
	var count = AudioServer.get_bus_effect_count(bus_idx)
	for i in range(count):
		var eff = AudioServer.get_bus_effect(bus_idx, i)
		if eff is AudioEffectLowPassFilter:
			lpf_effect = eff
			lpf_index = i
			break
	
	if lpf_effect == null:
		lpf_effect = AudioEffectLowPassFilter.new()
		lpf_effect.cutoff_hz = 20000.0
		lpf_effect.resonance = 0.5
		AudioServer.add_bus_effect(bus_idx, lpf_effect)
		lpf_index = AudioServer.get_bus_effect_count(bus_idx) - 1
		AudioServer.set_bus_effect_enabled(bus_idx, lpf_index, false)

func _setup_heartbeat_player() -> void:
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.bus = "Master"
	add_child(heartbeat_player)
	
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.12
	heartbeat_player.stream = gen

func play_heartbeat_thump(tempo_mult: float) -> void:
	if not heartbeat_player:
		return
	heartbeat_player.pitch_scale = clampf(0.85 + tempo_mult * 0.2, 0.8, 1.4)
	heartbeat_player.play()
	var pb: AudioStreamGeneratorPlayback = heartbeat_player.get_stream_playback()
	if pb:
		var frames = 1800
		for i in range(frames):
			var t = float(i) / 22050.0
			var decay = exp(-t * 22.0)
			# Deep hollow sub-bass thump (55 Hz)
			var s = sin(t * 55.0 * TAU) * decay * 0.75
			pb.push_frame(Vector2(s, s))

func _on_health_changed(current: float, max_val: float) -> void:
	var ratio = current / max_val if max_val > 0.0 else 1.0
	is_critical = (ratio < 0.25 and not Global.is_game_over)

func _process(delta: float) -> void:
	var hp_ratio = Global.player_health / Global.player_max_health if Global.player_max_health > 0.0 else 1.0
	is_critical = (hp_ratio < 0.25 and not Global.is_game_over)
	
	if is_critical:
		# Heartbeat tempo scales from 1.0 Hz (at 25% HP) up to 2.4 Hz (at 2% HP)
		var danger = clampf((0.25 - hp_ratio) / 0.25, 0.0, 1.0)
		var tempo = lerpf(1.1, 2.4, danger)
		
		var prev_phase = heartbeat_phase
		heartbeat_phase += delta * tempo
		
		# Thump on phase loop
		if int(heartbeat_phase) > int(prev_phase):
			play_heartbeat_thump(danger)
		
		var pulse = (sin(heartbeat_phase * TAU) * 0.5 + 0.5)
		var vig_alpha = lerpf(0.35, 0.95, danger) * (0.6 + pulse * 0.4)
		if vignette_rect:
			vignette_rect.modulate.a = lerpf(vignette_rect.modulate.a, vig_alpha, delta * 8.0)
		
		# Low-pass filter cut to 800 Hz
		if lpf_effect and lpf_index >= 0:
			AudioServer.set_bus_effect_enabled(0, lpf_index, true)
			var target_cutoff = lerpf(1200.0, 800.0, danger)
			lpf_effect.cutoff_hz = lerpf(lpf_effect.cutoff_hz, target_cutoff, delta * 6.0)
	else:
		# Smooth disengagement
		heartbeat_phase = 0.0
		if vignette_rect:
			vignette_rect.modulate.a = move_toward(vignette_rect.modulate.a, 0.0, delta * 3.5)
		
		if lpf_effect and lpf_index >= 0:
			lpf_effect.cutoff_hz = move_toward(lpf_effect.cutoff_hz, 20000.0, delta * 12000.0)
			if lpf_effect.cutoff_hz >= 19500.0:
				AudioServer.set_bus_effect_enabled(0, lpf_index, false)
