extends Node

# Audio Bus Names
const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"
const BUS_WEAPONS = "Weapons"
const BUS_ZOMBIES = "Zombies"
const BUS_FOLEY = "Foley"
const BUS_PICKUPS = "Pickups_UI"

# Pooling configuration
const POOL_SIZE_3D = 24
const POOL_SIZE_2D = 16
const POOL_SIZE_UI = 8

var _pool_3d: Array[AudioStreamPlayer3D] = []
var _idx_3d: int = 0

var _pool_2d: Array[AudioStreamPlayer2D] = []
var _idx_2d: int = 0

var _pool_ui: Array[AudioStreamPlayer] = []
var _idx_ui: int = 0

# Sound Resources Cache (sound_name -> AudioStreamRandomizer)
var _sound_cache: Dictionary = {}

# Sound to Bus mapping
const SOUND_BUS_MAP = {
	# Weapons
	"pistol": BUS_WEAPONS,
	"shotgun": BUS_WEAPONS,
	"shotgun_pump": BUS_WEAPONS,
	"rifle": BUS_WEAPONS,
	"flame": BUS_WEAPONS,
	"flame_start": BUS_WEAPONS,
	"flame_loop": BUS_WEAPONS,
	"minigun_spin": BUS_WEAPONS,
	"minigun_fire": BUS_WEAPONS,
	"dry_fire": BUS_WEAPONS,
	"empty_click": BUS_WEAPONS,
	"casing_1": BUS_FOLEY,
	"casing_2": BUS_FOLEY,
	"casing_3": BUS_FOLEY,
	"casing_ping": BUS_FOLEY,
	"reload_mag_out": BUS_WEAPONS,
	"reload_mag_in": BUS_WEAPONS,
	"reload_bolt_rack": BUS_WEAPONS,
	
	# Foley & Movement
	"footstep_sole": BUS_FOLEY,
	"gear_rustle": BUS_FOLEY,
	"boot_skid": BUS_FOLEY,
	"footstep_concrete": BUS_FOLEY,
	"footstep_gravel": BUS_FOLEY,
	"footstep_metal": BUS_FOLEY,
	"roll": BUS_FOLEY,
	
	# Zombies & Mutants
	"flesh_impact": BUS_ZOMBIES,
	"armor_deflect": BUS_ZOMBIES,
	"bone_deflect": BUS_ZOMBIES,
	"kill_bone_crack": BUS_ZOMBIES,
	"kill_guttural_exhale": BUS_ZOMBIES,
	"kill_body_thud": BUS_ZOMBIES,
	"zombie_idle": BUS_ZOMBIES,
	"zombie_aggro": BUS_ZOMBIES,
	"zombie_hurt": BUS_ZOMBIES,
	"zombie_death": BUS_ZOMBIES,
	"zombie_groan": BUS_ZOMBIES,
	"dog_bark": BUS_ZOMBIES,
	"dog_skitter": BUS_ZOMBIES,
	"dog_whoosh": BUS_ZOMBIES,
	"mutant_step": BUS_ZOMBIES,
	"mutant_roar": BUS_ZOMBIES,
	"stomp_crash": BUS_ZOMBIES,
	"boss_roar": BUS_ZOMBIES,
	"boss_slam": BUS_ZOMBIES,
	"boss_cleave": BUS_ZOMBIES,
	"boss_alarm": BUS_ZOMBIES,
	"rock_impact": BUS_ZOMBIES,
	"screamer": BUS_ZOMBIES,
	"radiation_tick": BUS_ZOMBIES,
	
	# Pickups & UI
	"pickup": BUS_PICKUPS,
	"pickup_ammo": BUS_PICKUPS,
	"pickup_health": BUS_PICKUPS,
	"scrap_pickup": BUS_PICKUPS,
	"keycard_chirp": BUS_PICKUPS,
	"perk": BUS_PICKUPS,
	"wave_clear": BUS_PICKUPS,
	"wave_start": BUS_PICKUPS,
	"hit": BUS_PICKUPS,
	
	# Environment & SFX
	"explode": BUS_SFX,
	"gate_slam": BUS_SFX,
	"electric_zap": BUS_SFX,
	"aircraft_flyby": BUS_SFX,
	"radio_chatter": BUS_PICKUPS,
	"klaxon": BUS_SFX
}

# Ducking & Bus variables
var _duck_tween: Tween
var _sfx_bus_idx: int = -1
var _zombies_bus_idx: int = -1
var _zombies_lpf: AudioEffectLowPassFilter = null
var _lpf_update_timer: float = 0.0

# Polyphony clamping for death audio
var _active_death_count: int = 0
const MAX_DEATH_POLYPHONY: int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus_indices()
	_initialize_pools()
	_preload_all_sounds()
	print("[AUDIO MANAGER] Modular Tactical Audio Architecture initialized (Pools: 24x 3D, 16x 2D, 8x UI).")

func _setup_bus_indices() -> void:
	_sfx_bus_idx = AudioServer.get_bus_index(BUS_SFX)
	_zombies_bus_idx = AudioServer.get_bus_index(BUS_ZOMBIES)
	if _zombies_bus_idx >= 0:
		var effect_count = AudioServer.get_bus_effect_count(_zombies_bus_idx)
		for i in range(effect_count):
			var eff = AudioServer.get_bus_effect(_zombies_bus_idx, i)
			if eff is AudioEffectLowPassFilter:
				_zombies_lpf = eff
				break

func _process(delta: float) -> void:
	if _zombies_lpf == null:
		return
	
	_lpf_update_timer -= delta
	if _lpf_update_timer > 0.0:
		return
	_lpf_update_timer = 0.05
	
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		_zombies_lpf.cutoff_hz = 18000.0
		return
	
	var p_pos: Vector2 = player.global_position if "global_position" in player else Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		_zombies_lpf.cutoff_hz = 18000.0
		return
	
	var min_dist_sq: float = INF
	for enemy in enemies:
		if is_instance_valid(enemy) and "global_position" in enemy:
			var d_sq = p_pos.distance_squared_to(enemy.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				if min_dist_sq < 2500.0:
					break
	
	var min_dist = sqrt(min_dist_sq) if min_dist_sq != INF else 1000.0
	var target_cutoff: float
	if min_dist >= 300.0:
		target_cutoff = 2800.0
	else:
		var t = clampf(min_dist / 300.0, 0.0, 1.0)
		target_cutoff = lerpf(18000.0, 2800.0, t)
	
	_zombies_lpf.cutoff_hz = lerpf(_zombies_lpf.cutoff_hz, target_cutoff, 0.35)

func _initialize_pools() -> void:
	# 3D Positional Pool
	for i in range(POOL_SIZE_3D):
		var p3d = AudioStreamPlayer3D.new()
		p3d.name = "PoolPlayer3D_%d" % i
		p3d.bus = BUS_SFX
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3d.unit_size = 8.0
		p3d.max_distance = 45.0
		add_child(p3d)
		_pool_3d.append(p3d)
	
	# 2D Positional Pool
	for i in range(POOL_SIZE_2D):
		var p2d = AudioStreamPlayer2D.new()
		p2d.name = "PoolPlayer2D_%d" % i
		p2d.bus = BUS_SFX
		p2d.max_distance = 1200.0
		add_child(p2d)
		_pool_2d.append(p2d)
	
	# UI / Non-Positional Pool
	for i in range(POOL_SIZE_UI):
		var p = AudioStreamPlayer.new()
		p.name = "PoolPlayerUI_%d" % i
		p.bus = BUS_PICKUPS
		add_child(p)
		_pool_ui.append(p)

func _preload_all_sounds() -> void:
	var sound_file_map = {
		"pistol": "res://assets/audio/weapons/pistol.wav",
		"shotgun": "res://assets/audio/weapons/shotgun.wav",
		"shotgun_pump": "res://assets/audio/weapons/shotgun_pump.wav",
		"rifle": "res://assets/audio/weapons/rifle.wav",
		"flame": "res://assets/audio/weapons/flame_loop.wav",
		"flame_start": "res://assets/audio/weapons/flame_start.wav",
		"flame_loop": "res://assets/audio/weapons/flame_loop.wav",
		"minigun_spin": "res://assets/audio/weapons/minigun_spin.wav",
		"minigun_fire": "res://assets/audio/weapons/minigun_fire.wav",
		"dry_fire": "res://assets/audio/weapons/dry_fire.wav",
		"empty_click": "res://assets/audio/weapons/dry_fire.wav",
		"casing_1": "res://assets/audio/weapons/casing_1.wav",
		"casing_2": "res://assets/audio/weapons/casing_2.wav",
		"casing_3": "res://assets/audio/weapons/casing_3.wav",
		"reload_mag_out": "res://assets/audio/weapons/reload_mag_out.wav",
		"reload_mag_in": "res://assets/audio/weapons/reload_mag_in.wav",
		"reload_bolt_rack": "res://assets/audio/weapons/reload_bolt_rack.wav",
		"footstep_sole": "res://assets/audio/foley/footstep_sole.wav",
		"gear_rustle": "res://assets/audio/foley/gear_rustle.wav",
		"boot_skid": "res://assets/audio/foley/boot_skid.wav",
		"footstep_concrete": "res://assets/audio/foley/footstep_concrete.wav",
		"footstep_gravel": "res://assets/audio/foley/footstep_gravel.wav",
		"footstep_metal": "res://assets/audio/foley/footstep_metal.wav",
		"flesh_impact": "res://assets/audio/zombies/flesh_impact.wav",
		"armor_deflect": "res://assets/audio/zombies/armor_deflect.wav",
		"bone_deflect": "res://assets/audio/zombies/bone_deflect.wav",
		"kill_bone_crack": "res://assets/audio/zombies/kill_bone_crack.wav",
		"kill_guttural_exhale": "res://assets/audio/zombies/kill_guttural_exhale.wav",
		"kill_body_thud": "res://assets/audio/zombies/kill_body_thud.wav",
		"zombie_idle": "res://assets/audio/zombies/zombie_idle.wav",
		"zombie_groan": "res://assets/audio/zombies/zombie_idle.wav",
		"zombie_aggro": "res://assets/audio/zombies/zombie_aggro.wav",
		"zombie_hurt": "res://assets/audio/zombies/zombie_hurt.wav",
		"zombie_death": "res://assets/audio/zombies/zombie_death.wav",
		"dog_bark": "res://assets/audio/zombies/dog_bark.wav",
		"dog_skitter": "res://assets/audio/zombies/dog_skitter.wav",
		"dog_whoosh": "res://assets/audio/zombies/dog_whoosh.wav",
		"mutant_step": "res://assets/audio/zombies/mutant_step.wav",
		"mutant_roar": "res://assets/audio/zombies/mutant_roar.wav",
		"boss_roar": "res://assets/audio/zombies/mutant_roar.wav",
		"boss_slam": "res://assets/audio/zombies/stomp_crash.wav",
		"stomp_crash": "res://assets/audio/zombies/stomp_crash.wav",
		"rock_impact": "res://assets/audio/zombies/stomp_crash.wav",
		"boss_cleave": "res://assets/audio/zombies/dog_whoosh.wav",
		"screamer": "res://assets/audio/zombies/zombie_aggro.wav",
		"radiation_tick": "res://assets/audio/pickups/keycard_chirp.wav",
		"pickup": "res://assets/audio/pickups/pickup_ammo.wav",
		"pickup_ammo": "res://assets/audio/pickups/pickup_ammo.wav",
		"pickup_health": "res://assets/audio/pickups/pickup_health.wav",
		"keycard_chirp": "res://assets/audio/pickups/keycard_chirp.wav",
		"hit": "res://assets/audio/pickups/hit.ogg",
		"perk": "res://assets/audio/pickups/keycard_chirp.wav",
		"wave_clear": "res://assets/audio/weapons/shotgun_pump.wav",
		"wave_start": "res://assets/audio/zombies/mutant_roar.wav",
		"explode": "res://assets/audio/environment/explosion.wav",
		"gate_slam": "res://assets/audio/environment/gate_slam.ogg"
	}
	
	for s_name in sound_file_map.keys():
		var path = sound_file_map[s_name]
		var base_stream: AudioStream = null
		if ResourceLoader.exists(path):
			base_stream = load(path)
		else:
			var alt_path = path.replace(".wav", ".ogg") if path.ends_with(".wav") else path.replace(".ogg", ".wav")
			if ResourceLoader.exists(alt_path):
				base_stream = load(alt_path)
		
		# Fallback to procedural synthesis if asset not on disk
		if base_stream == null:
			base_stream = _synthesize_procedural_stream(s_name)
		
		# Wrap with AudioStreamRandomizer for anti-repetition pitch/volume modulation
		if base_stream != null:
			var randomizer = AudioStreamRandomizer.new()
			randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
			randomizer.random_pitch = 1.08 # ±8% pitch variance (0.92 - 1.08)
			randomizer.random_volume_offset_db = 1.2 # ±1.2 dB variance
			randomizer.add_stream(0, base_stream)
			_sound_cache[s_name] = randomizer

func _get_or_create_sound(sound_name: String) -> AudioStream:
	if _sound_cache.has(sound_name):
		return _sound_cache[sound_name]
	
	# Try loading directly (.ogg or .wav)
	for ext in [".ogg", ".wav"]:
		var path = "res://assets/audio/%s%s" % [sound_name, ext]
		if ResourceLoader.exists(path):
			var stream = load(path)
			var rand = AudioStreamRandomizer.new()
			rand.random_pitch = 1.08
			rand.random_volume_offset_db = 1.2
			rand.add_stream(0, stream)
			_sound_cache[sound_name] = rand
			return rand
	
	# Procedural fallback
	var proc_stream = _synthesize_procedural_stream(sound_name)
	var rand = AudioStreamRandomizer.new()
	rand.random_pitch = 1.08
	rand.random_volume_offset_db = 1.2
	rand.add_stream(0, proc_stream)
	_sound_cache[sound_name] = rand
	return rand

func play_sound(sound_name: String, pos = null, bus_override: String = "") -> Node:
	if sound_name == "zombie_death":
		play_zombie_death(pos)
		return null
	elif sound_name == "zombie_hurt":
		play_bullet_impact(false, pos, false)
		return null
	
	var stream = _get_or_create_sound(sound_name)
	if stream == null:
		return null
	
	var bus = bus_override if bus_override != "" else _get_bus_for_sound(sound_name)
	
	# Weapons bus triggers sidechain ducking
	if bus == BUS_WEAPONS:
		trigger_weapons_ducking()
	
	if pos is Vector3:
		# 3D Positional Audio
		var player3d = _pool_3d[_idx_3d]
		_idx_3d = (_idx_3d + 1) % POOL_SIZE_3D
		player3d.volume_db = 0.0
		player3d.bus = bus
		player3d.stream = stream
		player3d.global_position = pos
		player3d.play()
		return player3d
	elif pos is Vector2:
		# 2D Positional Audio
		var player2d = _pool_2d[_idx_2d]
		_idx_2d = (_idx_2d + 1) % POOL_SIZE_2D
		player2d.volume_db = 0.0
		player2d.bus = bus
		player2d.stream = stream
		player2d.global_position = pos
		player2d.play()
		return player2d
	else:
		# Non-positional UI / HUD Audio
		var player_ui = _pool_ui[_idx_ui]
		_idx_ui = (_idx_ui + 1) % POOL_SIZE_UI
		player_ui.volume_db = 0.0
		player_ui.bus = bus
		player_ui.stream = stream
		player_ui.play()
		return player_ui

func play_sound_3d(sound_name: String, pos: Vector3, bus_override: String = "") -> AudioStreamPlayer3D:
	return play_sound(sound_name, pos, bus_override) as AudioStreamPlayer3D

func play_sound_2d(sound_name: String, pos: Vector2, bus_override: String = "") -> AudioStreamPlayer2D:
	return play_sound(sound_name, pos, bus_override) as AudioStreamPlayer2D

func play_sound_ui(sound_name: String, bus_override: String = "") -> AudioStreamPlayer:
	return play_sound(sound_name, null, bus_override) as AudioStreamPlayer

func duck_sfx_for_weapon(duck_db: float = -2.5, restore_time: float = 0.16) -> void:
	trigger_weapons_ducking(duck_db, restore_time)

func trigger_weapons_ducking(duck_db: float = -2.5, restore_time: float = 0.16) -> void:
	if _sfx_bus_idx < 0:
		return
	
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	
	AudioServer.set_bus_volume_db(_sfx_bus_idx, duck_db)
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(val: float): AudioServer.set_bus_volume_db(_sfx_bus_idx, val),
		duck_db,
		0.0,
		restore_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func play_weapon_shot(weapon_name: String, pos = null) -> void:
	play_sound(weapon_name, pos, BUS_WEAPONS)
	
	# Subtle shell casing ping (only occasional for single-shot pistol/rifle)
	if weapon_name in ["pistol", "rifle"] and randf() < 0.35:
		var casing_variant = "casing_%d" % (randi() % 3 + 1)
		get_tree().create_timer(randf_range(0.28, 0.40)).timeout.connect(func():
			play_sound(casing_variant, pos, BUS_FOLEY)
		)
	
	# Shotgun mechanical pump-action rack after 0.30s
	if weapon_name == "shotgun":
		get_tree().create_timer(0.30).timeout.connect(func():
			play_sound("shotgun_pump", pos, BUS_WEAPONS)
		)

func play_weapon_foley(cue_name: String, pos = null) -> void:
	play_sound(cue_name, pos, BUS_WEAPONS)

func play_footstep(surface_type: String, pos = null) -> void:
	var sound_name = "footstep_sole"
	match surface_type.to_lower():
		"gravel", "ballast", "dirt", "grass":
			sound_name = "footstep_gravel"
		"metal", "tracks", "railway":
			sound_name = "footstep_metal"
		_:
			sound_name = "footstep_sole"
	
	# Layer A: Sole Impact (punchy low-mid thud with sharp decay)
	var p_sole = play_sound(sound_name, pos, BUS_FOLEY)
	if p_sole:
		p_sole.volume_db = -4.0
	
	# Layer B: Gear Rustle (-14 dB relative to impact -> -18.0 dB)
	var p_gear = play_sound("gear_rustle", pos, BUS_FOLEY)
	if p_gear:
		p_gear.volume_db = -18.0

func play_boot_skid(pos = null) -> void:
	var p = play_sound("boot_skid", pos, BUS_FOLEY)
	if p:
		p.volume_db = -5.0

func play_bullet_impact(is_armor: bool, pos = null, is_crit: bool = false) -> void:
	if is_armor:
		var p = play_sound("armor_deflect", pos, BUS_ZOMBIES)
		if p:
			p.volume_db = -2.0
	else:
		var p = play_sound("flesh_impact", pos, BUS_ZOMBIES)
		if p:
			p.volume_db = 0.0 if is_crit else -2.5

func play_zombie_death(pos = null) -> void:
	if _active_death_count >= MAX_DEATH_POLYPHONY:
		# Polyphony clamped: Only play immediate bone crack transient, skip delayed body drop
		play_sound("kill_bone_crack", pos, BUS_ZOMBIES)
		return
	
	_active_death_count += 1
	# 1. Structural bone-fracture crack
	var p_crack = play_sound("kill_bone_crack", pos, BUS_ZOMBIES)
	if p_crack:
		p_crack.volume_db = -1.0
	
	# 2. Guttural exhale
	var p_exhale = play_sound("kill_guttural_exhale", pos, BUS_ZOMBIES)
	if p_exhale:
		p_exhale.volume_db = -4.0
	
	# 3. Ragdoll terrain thud delayed 0.22s after kill shot
	var tree = get_tree()
	if tree:
		tree.create_timer(0.22, false, false, false).timeout.connect(func():
			play_sound("kill_body_thud", pos, BUS_ZOMBIES)
			_active_death_count = max(0, _active_death_count - 1)
		)
	else:
		_active_death_count = max(0, _active_death_count - 1)

func stop_all() -> void:
	for p in _pool_3d:
		p.stop()
	for p in _pool_2d:
		p.stop()
	for p in _pool_ui:
		p.stop()

func play_zombie_vocalization(sound_type: String, pos = null) -> void:
	play_sound(sound_type, pos, BUS_ZOMBIES)

func play_pickup(pickup_type: String, pos = null) -> void:
	play_sound(pickup_type, pos, BUS_PICKUPS)

func play_ui(cue_name: String) -> void:
	play_sound(cue_name, null, BUS_PICKUPS)

func _get_bus_for_sound(sound_name: String) -> String:
	if SOUND_BUS_MAP.has(sound_name):
		return SOUND_BUS_MAP[sound_name]
	return BUS_SFX

func _synthesize_procedural_stream(sound_name: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.14
	
	match sound_name:
		"pistol":
			duration = 0.16
		"shotgun":
			duration = 0.35
		"shotgun_pump":
			duration = 0.24
		"rifle":
			duration = 0.22
		"flame", "flame_loop", "flame_start":
			duration = 0.35
		"minigun_spin":
			duration = 0.28
		"minigun_fire":
			duration = 0.055
		"dry_fire", "empty_click":
			duration = 0.05
		"reload_mag_out":
			duration = 0.22
		"reload_mag_in":
			duration = 0.25
		"reload_bolt_rack":
			duration = 0.38
		"casing_1", "casing_2", "casing_3", "casing_ping":
			duration = 0.14
		"aircraft_flyby":
			duration = 2.0
		"footstep_sole", "footstep_concrete":
			duration = 0.06
		"footstep_gravel", "footstep_metal":
			duration = 0.07
		"gear_rustle":
			duration = 0.08
		"boot_skid":
			duration = 0.14
		"flesh_impact":
			duration = 0.09
		"armor_deflect", "bone_deflect":
			duration = 0.07
		"kill_bone_crack":
			duration = 0.12
		"kill_guttural_exhale":
			duration = 0.20
		"kill_body_thud":
			duration = 0.18
		"zombie_idle", "zombie_groan":
			duration = 0.45
		"zombie_aggro":
			duration = 0.35
		"zombie_hurt", "hit":
			duration = 0.12
		"zombie_death":
			duration = 0.40
		"dog_bark":
			duration = 0.15
		"dog_skitter":
			duration = 0.06
		"dog_whoosh", "roll":
			duration = 0.20
		"mutant_step":
			duration = 0.30
		"mutant_roar", "boss_roar":
			duration = 0.70
		"stomp_crash", "boss_slam":
			duration = 0.45
		"pickup_ammo", "pickup":
			duration = 0.18
		"pickup_health":
			duration = 0.22
		"keycard_chirp":
			duration = 0.16
		"explode":
			duration = 0.50
		"gate_slam":
			duration = 0.40
		"klaxon":
			duration = 0.75
		"radio_chatter":
			duration = 0.55
		_:
			duration = 0.15
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	var frames: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(frames * 2) # 2 bytes per 16-bit sample
	
	var last_noise: float = 0.0
	
	for i in range(frames):
		var t = float(i) / float(sample_rate)
		var decay = 1.0 - (float(i) / float(frames))
		var val: float = 0.0
		
		match sound_name:
			"rifle":
				# PUBG-Style AK: Piercing Supersonic Transient + 80Hz Chest Thump + Receiver Cycle Tail
				var crack = (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 1.8
				var punch_80hz = sin(TAU * (82.0 - t * 45.0) * t) * exp(-t * 22.0) * 1.5
				var bolt = (sin(TAU * 850.0 * t) + (randf() * 0.8 - 0.4)) * exp(-(t - 0.035) * 45.0) * 0.5 if t >= 0.035 else 0.0
				val = tanh(crack + punch_80hz + bolt) * 0.95
			
			"pistol":
				# Crisp 9mm Supersonic Snap + Mid Punch + Slide Rack Rattle
				var crack = (randf() * 2.0 - 1.0) * exp(-t * 130.0) * 1.5
				var punch = sin(TAU * (115.0 - t * 120.0) * t) * exp(-t * 36.0) * 1.2
				var slide = sin(TAU * 1600.0 * t) * exp(-(t - 0.03) * 55.0) * 0.4 if t >= 0.03 else 0.0
				val = tanh(crack + punch + slide) * 0.92
			
			"shotgun":
				# 12-Gauge Massive Blast Wave + Sub-Bass Pressure + Chamber Ring
				var blast = (randf() * 2.0 - 1.0) * exp(-t * 32.0) * 1.9
				var sub_boom = sin(TAU * (58.0 - t * 65.0) * t) * exp(-t * 14.0) * 1.7
				var chamber = sin(TAU * 380.0 * t) * exp(-t * 20.0) * 0.4
				val = tanh(blast + sub_boom + chamber) * 0.95
			
			"minigun_fire":
				# Rapid-Fire Impulses + 95Hz Punch + Chamber Lock
				var crack = (randf() * 2.0 - 1.0) * exp(-t * 180.0) * 2.0
				var thump = sin(TAU * 95.0 * t) * exp(-t * 48.0) * 1.3
				var cycle = sin(TAU * 2100.0 * t) * exp(-t * 110.0) * 0.5
				val = tanh(crack + thump + cycle) * 0.92
			
			"dry_fire", "empty_click":
				# Cold Authentic Metallic Double-Click on Empty Chamber
				var pin = sin(TAU * 2600.0 * t) * exp(-t * 180.0) * 1.3
				var sear = sin(TAU * 3400.0 * (t - 0.016)) * exp(-(t - 0.016) * 220.0) * 0.9 if t >= 0.016 else 0.0
				var snap = (randf() * 2.0 - 1.0) * exp(-t * 250.0) * 0.8
				val = (pin + sear + snap) * 0.75
			
			"reload_mag_out":
				# Latch release ping + mag slide scrape
				var latch = sin(TAU * 1750.0 * t) * exp(-t * 120.0) * 0.9
				var slide = (randf() * 2.0 - 1.0) * exp(-(t - 0.03) * 45.0) * 0.4 if t >= 0.03 else 0.0
				val = latch + slide
			
			"reload_mag_in":
				# Firm insertion slap + latch lock
				var slap = (randf() * 2.0 - 1.0) * exp(-t * 85.0) * 0.8
				var lock = (sin(TAU * 520.0 * (t - 0.04)) + (randf() * 0.6 - 0.3)) * exp(-(t - 0.04) * 60.0) * 1.1 if t >= 0.04 else 0.0
				val = slap + lock
			
			"reload_bolt_rack":
				# Pull charging handle + heavy spring slam into battery
				var pull = sin(TAU * 650.0 * t) * exp(-t * 28.0) * 0.6
				var slam = ((randf() * 2.0 - 1.0) * 1.4 + sin(TAU * 440.0 * (t - 0.16)) * 0.9) * exp(-(t - 0.16) * 55.0) if t >= 0.16 else 0.0
				val = pull + slam
			
			"shotgun_pump":
				# Forend slide back + chamber lock forward
				var back = sin(TAU * 1350.0 * t) * exp(-t * 65.0) * 0.7
				var fwd = (sin(TAU * 950.0 * (t - 0.11)) + (randf() * 0.6 - 0.3)) * exp(-(t - 0.11) * 75.0) * 1.0 if t >= 0.11 else 0.0
				val = back + fwd
			
			"casing_1", "casing_2", "casing_3", "casing_ping":
				var ping = sin(TAU * 3150.0 * t) * exp(-t * 45.0) * 0.6
				var bounce = sin(TAU * 3450.0 * (t - 0.045)) * exp(-(t - 0.045) * 55.0) * 0.35 if t >= 0.045 else 0.0
				val = ping + bounce
			
			"aircraft_flyby":
				# Heavy twin-engine military cargo plane Doppler rumble
				var freq_d = lerpf(86.0, 48.0, t / duration)
				var drone = sin(TAU * freq_d * t) * 0.55 + sin(TAU * (freq_d * 2.0) * t) * 0.25
				var wind = (randf() * 2.0 - 1.0) * 0.25
				var env = sin(t / duration * PI)
				val = (drone + wind) * env * 0.9
			
			"footstep_sole", "footstep_concrete":
				# 60ms: Band-pass filtered brown noise (centered around 180Hz) with steep decay (exp(-45t)) + 10ms transient pink noise burst
				var brown = sin(TAU * 180.0 * t) * exp(-t * 45.0) * 1.5
				var transient = (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.7 if t < 0.010 else 0.0
				var mid_body = sin(TAU * 120.0 * t) * exp(-t * 60.0) * 0.5
				val = tanh(brown + transient + mid_body) * 0.85
			
			"footstep_gravel":
				var low_thud = sin(TAU * 160.0 * t) * exp(-t * 45.0) * 1.2
				var grit = (randf() * 2.0 - 1.0) * (1.0 if fmod(t * 180.0, 1.0) < 0.25 else 0.15) * exp(-t * 40.0) * 0.7
				val = tanh(low_thud + grit) * 0.85
			
			"footstep_metal":
				var low_thud = sin(TAU * 220.0 * t) * exp(-t * 50.0) * 1.1
				var ping = sin(TAU * 1250.0 * t) * exp(-t * 65.0) * 0.4
				val = tanh(low_thud + ping) * 0.85
			
			"gear_rustle":
				# 80ms: High-pass filtered white noise (>3500Hz) with gentle exponential decay, low amplitude
				var n_curr = randf() * 2.0 - 1.0
				var hp_noise = n_curr - last_noise
				last_noise = n_curr
				var rattle = sin(TAU * 4100.0 * t) * 0.25
				val = (hp_noise * 0.6 + rattle) * exp(-t * 30.0) * 0.35
			
			"boot_skid":
				# 140ms: Multi-frequency noise scuff with slight modulation
				var mod = sin(TAU * 32.0 * t) * 0.35 + 0.65
				var noise_scuff = (randf() * 2.0 - 1.0) * exp(-t * 16.0) * mod * 0.9
				var friction = sin(TAU * (280.0 - t * 60.0) * t) * exp(-t * 20.0) * 0.4
				val = tanh(noise_scuff + friction) * 0.85
			
			"flesh_impact":
				# 90ms: 80Hz sine thump + 40ms distorted white noise spike through 1200Hz LPF
				var thump = sin(TAU * (82.0 - t * 35.0) * t) * exp(-t * 26.0) * 1.4
				var spike = tanh((randf() * 2.0 - 1.0) * 2.2) * exp(-t * 55.0) * 1.1 if t < 0.040 else 0.0
				var cavitation = sin(TAU * 360.0 * t) * exp(-t * 40.0) * 0.5
				val = tanh(thump + spike + cavitation) * 0.95
			
			"armor_deflect", "bone_deflect":
				# 70ms: High pitch 2400Hz resonant ping + fast metallic noise burst
				var ping1 = sin(TAU * 2400.0 * t) * exp(-t * 50.0) * 1.2
				var ping2 = sin(TAU * 5100.0 * t) * exp(-t * 90.0) * 0.5
				var metal_burst = (randf() * 2.0 - 1.0) * exp(-t * 150.0) * 1.0 if t < 0.020 else 0.0
				val = tanh(ping1 + ping2 + metal_burst) * 0.92
			
			"kill_bone_crack":
				# 120ms: High-pass noise burst (>2200Hz) + sub-bass pitch drop (120Hz down to 35Hz over 80ms)
				var f_sub = maxf(35.0, 120.0 - t * (85.0 / 0.080))
				var sub_bass = sin(TAU * f_sub * t) * exp(-t * 20.0) * 1.5
				var n_curr = randf() * 2.0 - 1.0
				var hp_crack = (n_curr - last_noise) * exp(-t * 55.0) * 1.4
				last_noise = n_curr
				var snap = sin(TAU * 2800.0 * t) * exp(-t * 85.0) * 0.7 if t < 0.030 else 0.0
				val = tanh(sub_bass + hp_crack + snap) * 0.95
			
			"kill_guttural_exhale":
				# 200ms: Formant-like filtered low noise (around 300-500Hz) fading out
				var formant1 = sin(TAU * 320.0 * t) * 0.6
				var formant2 = sin(TAU * 460.0 * t) * 0.45
				var throat = (randf() * 2.0 - 1.0) * (sin(TAU * 24.0 * t) * 0.35 + 0.65) * 0.6
				var env = sin(clampf(t / 0.20, 0.0, 1.0) * PI) * exp(-t * 6.5)
				val = tanh((formant1 + formant2 + throat) * env * 1.4) * 0.85
			
			"kill_body_thud":
				# 180ms: Low-frequency punch (55Hz–95Hz sine sweep with fast decay)
				var f_thud = lerpf(95.0, 55.0, clampf(t / 0.12, 0.0, 1.0))
				var thud = sin(TAU * f_thud * t) * exp(-t * 24.0) * 1.6
				var ground = (randf() * 2.0 - 1.0) * exp(-t * 50.0) * 0.5 if t < 0.035 else 0.0
				val = tanh(thud + ground) * 0.92
			
			"explode", "stomp_crash", "boss_slam", "gate_slam":
				var noise = (randf() * 2.0 - 1.0) * pow(decay, 1.5)
				var shock = (1.0 - t * 30.0) if t < 0.03 else 0.0
				val = tanh(shock * 1.6 + noise * 1.3) * 0.95
			
			"zombie_idle", "zombie_groan", "mutant_roar", "boss_roar":
				var pulse = 1.0 if fmod(t * 24.0, 1.0) < 0.16 else -0.2
				var rasp = (randf() * 2.0 - 1.0) * 0.5
				val = tanh((pulse + rasp) * sin(float(i) / float(frames) * PI) * 1.5) * 0.85
			
			"klaxon":
				# Low-frequency dual-tone military alert klaxon
				var tone1 = sin(TAU * 135.0 * t)
				var tone2 = sin(TAU * 180.0 * t) * 0.75
				var warble = (sin(TAU * 5.0 * t) * 0.5 + 0.5)
				val = tanh((tone1 + tone2) * (0.4 + warble * 0.8) * exp(-t * 1.5)) * 0.95
			
			"radio_chatter":
				# Radio squelch burst + military comms static chirp
				var squelch = (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 1.4
				var chirp = sin(TAU * (920.0 + sin(t * 35.0) * 220.0) * t) * exp(-t * 12.0) * 0.5
				var stat = (randf() * 2.0 - 1.0) * 0.28 * decay
				val = tanh(squelch + chirp + stat) * 0.88
			
			_:
				var noise = (randf() * 2.0 - 1.0) * exp(-t * 35.0) * 0.6
				val = noise
		
		var sample_16 = int(clampf(val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_16)
	
	stream.data = data
	return stream
