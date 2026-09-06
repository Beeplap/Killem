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
	"footstep_concrete": BUS_FOLEY,
	"footstep_gravel": BUS_FOLEY,
	"footstep_metal": BUS_FOLEY,
	"roll": BUS_FOLEY,
	
	# Zombies & Mutants
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
	"keycard_chirp": BUS_PICKUPS,
	"perk": BUS_PICKUPS,
	"wave_clear": BUS_PICKUPS,
	"wave_start": BUS_PICKUPS,
	"hit": BUS_PICKUPS,
	
	# Environment & SFX
	"explode": BUS_SFX,
	"gate_slam": BUS_SFX,
	"electric_zap": BUS_SFX
}

# Ducking variables
var _duck_tween: Tween
var _sfx_bus_idx: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus_indices()
	_initialize_pools()
	_preload_all_sounds()
	print("[AUDIO MANAGER] Modular Tactical Audio Architecture initialized (Pools: 24x 3D, 16x 2D, 8x UI).")

func _setup_bus_indices() -> void:
	_sfx_bus_idx = AudioServer.get_bus_index(BUS_SFX)

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
		"footstep_concrete": "res://assets/audio/foley/footstep_concrete.wav",
		"footstep_gravel": "res://assets/audio/foley/footstep_gravel.wav",
		"footstep_metal": "res://assets/audio/foley/footstep_metal.wav",
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
		"explode": "res://assets/audio/environment/explosion.wav",
		"gate_slam": "res://assets/audio/environment/explosion.wav"
	}
	
	for s_name in sound_file_map.keys():
		var path = sound_file_map[s_name]
		var base_stream: AudioStream = null
		if ResourceLoader.exists(path):
			base_stream = load(path)
		
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
	
	# Try loading directly
	var path = "res://assets/audio/%s.wav" % sound_name
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
		player3d.bus = bus
		player3d.stream = stream
		player3d.global_position = pos
		player3d.play()
		return player3d
	elif pos is Vector2:
		# 2D Positional Audio
		var player2d = _pool_2d[_idx_2d]
		_idx_2d = (_idx_2d + 1) % POOL_SIZE_2D
		player2d.bus = bus
		player2d.stream = stream
		player2d.global_position = pos
		player2d.play()
		return player2d
	else:
		# Non-positional UI / HUD Audio
		var player_ui = _pool_ui[_idx_ui]
		_idx_ui = (_idx_ui + 1) % POOL_SIZE_UI
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
	
	# Eject shell casing ping after 0.25s
	if weapon_name in ["pistol", "shotgun", "rifle", "minigun"]:
		var casing_variant = "casing_%d" % (randi() % 3 + 1)
		get_tree().create_timer(0.25).timeout.connect(func():
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
	var sound_name = "footstep_concrete"
	match surface_type.to_lower():
		"gravel", "ballast", "dirt":
			sound_name = "footstep_gravel"
		"metal", "tracks", "railway":
			sound_name = "footstep_metal"
		_:
			sound_name = "footstep_concrete"
	play_sound(sound_name, pos, BUS_FOLEY)

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
	var duration: float = 0.12
	var freq: float = 440.0
	
	match sound_name:
		"pistol":
			duration = 0.15
			freq = 280.0
		"shotgun":
			duration = 0.30
			freq = 55.0
		"shotgun_pump":
			duration = 0.20
			freq = 950.0
		"rifle":
			duration = 0.12
			freq = 380.0
		"flame", "flame_loop":
			duration = 0.35
			freq = 90.0
		"minigun_spin":
			duration = 0.30
			freq = 600.0
		"minigun_fire":
			duration = 0.06
			freq = 180.0
		"dry_fire", "empty_click":
			duration = 0.04
			freq = 1900.0
		"footstep_concrete":
			duration = 0.09
			freq = 110.0
		"footstep_gravel":
			duration = 0.12
			freq = 400.0
		"footstep_metal":
			duration = 0.16
			freq = 650.0
		"zombie_idle", "zombie_groan":
			duration = 0.45
			freq = 85.0
		"zombie_aggro":
			duration = 0.35
			freq = 160.0
		"zombie_hurt", "hit":
			duration = 0.12
			freq = 140.0
		"zombie_death":
			duration = 0.40
			freq = 100.0
		"dog_bark":
			duration = 0.15
			freq = 420.0
		"dog_skitter":
			duration = 0.06
			freq = 800.0
		"dog_whoosh", "roll":
			duration = 0.20
			freq = 200.0
		"mutant_step":
			duration = 0.30
			freq = 42.0
		"mutant_roar", "boss_roar":
			duration = 0.70
			freq = 58.0
		"stomp_crash", "boss_slam":
			duration = 0.45
			freq = 38.0
		"pickup_ammo", "pickup":
			duration = 0.20
			freq = 1800.0
		"pickup_health":
			duration = 0.22
			freq = 650.0
		"keycard_chirp":
			duration = 0.16
			freq = 1200.0
		"explode":
			duration = 0.45
			freq = 48.0
		"gate_slam":
			duration = 0.40
			freq = 95.0
		_:
			duration = 0.15
			freq = 440.0
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	var frames: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(frames * 2) # 2 bytes per 16-bit sample
	
	for i in range(frames):
		var t = float(i) / float(sample_rate)
		var decay = 1.0 - (float(i) / float(frames))
		var val: float = 0.0
		
		if sound_name in ["explode", "hit", "stomp_crash", "boss_slam", "gate_slam", "zombie_hurt"]:
			var sub = sin(t * freq * TAU) * 0.7
			var noise = (randf() * 2.0 - 1.0) * 0.6
			val = (sub + noise) * pow(decay, 1.8)
		elif sound_name in ["pistol", "rifle", "shotgun", "minigun_fire"]:
			var crack = (randf() * 2.0 - 1.0) * exp(-t * 35.0) * 0.8
			var body = sin(t * freq * TAU) * exp(-t * 22.0) * 0.7
			val = crack + body
		elif sound_name in ["zombie_idle", "zombie_groan", "mutant_roar", "boss_roar"]:
			var r1 = sin(t * freq * TAU) * 0.6
			var r2 = sin(t * freq * 1.8 * TAU) * 0.3
			var rasp = (randf() * 2.0 - 1.0) * 0.2
			val = (r1 + r2 + rasp) * sin(float(i) / float(frames) * PI)
		elif sound_name in ["pickup_ammo", "keycard_chirp", "pickup"]:
			val = sin(t * freq * TAU) * exp(-t * 20.0) * 0.6
		else:
			val = sin(t * freq * TAU) * decay * 0.7
		
		var sample_16 = int(clampf(val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_16)
	
	stream.data = data
	return stream
