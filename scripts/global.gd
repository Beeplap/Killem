extends Node

# Global state and signals for Outbreak Zombie Shooter
signal health_changed(current: float, max_val: float)
signal ammo_changed(weapon_name: String, current: int, max_val: int)
signal score_changed(score: int, kills: int)
signal wave_changed(wave: int)
signal wave_cleared(wave_num: int, cooldown_duration: float)
signal wave_countdown(seconds_left: int)
signal wave_started(wave_num: int)
signal player_died
signal player_fired
signal explosion_occurred
signal keycard_collected(color: String)
signal objective_completed(obj_id: String)
signal perk_unlocked(perk_name: String, description: String)
signal roll_cooldown_updated(current: float, max_val: float)
signal deployables_updated(wires: int, mines: int, turrets: int)
signal weapon_changed(new_weapon: WeaponType)
signal active_deployable_changed(deployable_type: int)
signal boss_spawned(boss_node: Node2D)
signal boss_defeated(boss_node: Node2D)
signal camera_trauma_requested(amount: float)

# Core State
var keycards_collected: Array[String] = []
var score: int = 0
var kills: int = 0
var current_wave: int = 1
var player_health: float = 100.0
var player_max_health: float = 100.0
var is_game_over: bool = false

# Weapons
enum WeaponType { PISTOL, SHOTGUN, ASSAULT_RIFLE, FLAMETHROWER, MINIGUN }

var current_weapon: WeaponType = WeaponType.PISTOL
var shotgun_ammo: int = 24
var shotgun_max_ammo: int = 64
var rifle_ammo: int = 90
var rifle_max_ammo: int = 240
var flamethrower_fuel: int = 150
var flamethrower_max_fuel: int = 300
var minigun_ammo: int = 300
var minigun_max_ammo: int = 600

# Perks
var perk_full_auto: bool = false
var perk_extended_mags: bool = false
var perk_armor_plating: bool = false

# Deployables inventory
var deployable_barbed_wire: int = 2
var deployable_claymores: int = 2
var deployable_turrets: int = 1
var active_deployable_type: int = 0

var hitstop_active: bool = false
var screenshake_multiplier: float = 1.0

# Mobile Twin-Stick Input Override State
var virtual_aim_active: bool = false
var virtual_aim_dir: Vector2 = Vector2.RIGHT
var mobile_controls_enabled: int = 0 # 0: Auto, 1: Forced On, 2: Forced Off

func _ready() -> void:
	reset_state()

func reset_state() -> void:
	score = 0
	kills = 0
	current_wave = 1
	player_health = 100.0
	player_max_health = 100.0
	shotgun_ammo = 24
	rifle_ammo = 90
	flamethrower_fuel = 150
	minigun_ammo = 300
	shotgun_max_ammo = 64
	rifle_max_ammo = 240
	flamethrower_max_fuel = 300
	minigun_max_ammo = 600
	current_weapon = WeaponType.PISTOL
	perk_full_auto = false
	perk_extended_mags = false
	perk_armor_plating = false
	deployable_barbed_wire = 2
	deployable_claymores = 2
	deployable_turrets = 1
	active_deployable_type = 0
	is_game_over = false
	Engine.time_scale = 1.0
	hitstop_active = false
	keycards_collected.clear()

func unlock_perk(perk_id: String) -> void:
	match perk_id:
		"full_auto":
			perk_full_auto = true
			perk_unlocked.emit("FULL AUTO RECEIVER", "Pistol modified with continuous rapid-fire trigger!")
		"extended_mags":
			perk_extended_mags = true
			shotgun_max_ammo = int(shotgun_max_ammo * 1.5)
			rifle_max_ammo = int(rifle_max_ammo * 1.5)
			flamethrower_max_fuel = int(flamethrower_max_fuel * 1.5)
			minigun_max_ammo = int(minigun_max_ammo * 1.5)
			shotgun_ammo = shotgun_max_ammo
			rifle_ammo = rifle_max_ammo
			flamethrower_fuel = flamethrower_max_fuel
			minigun_ammo = minigun_max_ammo
			emit_current_ammo()
			perk_unlocked.emit("EXTENDED MAGAZINES", "+50% maximum ammo capacity for all firearms!")
		"armor_plating":
			perk_armor_plating = true
			player_max_health += 50.0
			player_health = min(player_max_health, player_health + 50.0)
			health_changed.emit(player_health, player_max_health)
			perk_unlocked.emit("BALLISTIC ARMOR PLATING", "+50 Maximum Health and instant vitality surge!")
	play_sound("perk")

func trigger_hitstop(duration: float = 0.04, scale_factor: float = 0.05) -> void:
	if is_game_over or hitstop_active:
		return
	hitstop_active = true
	Engine.time_scale = scale_factor
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstop_active = false

func add_kill(points: int = 100) -> void:
	kills += 1
	score += points
	score_changed.emit(score, kills)

func take_player_damage(amount: float) -> void:
	if is_game_over:
		return
	player_health = max(0.0, player_health - amount)
	health_changed.emit(player_health, player_max_health)
	if player_health <= 0.0:
		is_game_over = true
		player_died.emit()

func heal_player(amount: float) -> void:
	if is_game_over:
		return
	player_health = min(player_max_health, player_health + amount)
	health_changed.emit(player_health, player_max_health)

func add_ammo_crate() -> void:
	shotgun_ammo = min(shotgun_max_ammo, shotgun_ammo + 16)
	rifle_ammo = min(rifle_max_ammo, rifle_ammo + 60)
	flamethrower_fuel = min(flamethrower_max_fuel, flamethrower_fuel + 80)
	minigun_ammo = min(minigun_max_ammo, minigun_ammo + 120)
	emit_current_ammo()

func has_ammo(type: WeaponType) -> bool:
	match type:
		WeaponType.PISTOL:
			return true
		WeaponType.SHOTGUN:
			return shotgun_ammo > 0
		WeaponType.ASSAULT_RIFLE:
			return rifle_ammo > 0
		WeaponType.FLAMETHROWER:
			return flamethrower_fuel > 0
		WeaponType.MINIGUN:
			return minigun_ammo > 0
	return false

func consume_ammo(type: WeaponType) -> bool:
	match type:
		WeaponType.PISTOL:
			return true
		WeaponType.SHOTGUN:
			if shotgun_ammo > 0:
				shotgun_ammo -= 1
				emit_current_ammo()
				return true
			return false
		WeaponType.ASSAULT_RIFLE:
			if rifle_ammo > 0:
				rifle_ammo -= 1
				emit_current_ammo()
				return true
			return false
		WeaponType.FLAMETHROWER:
			if flamethrower_fuel > 0:
				flamethrower_fuel -= 1
				emit_current_ammo()
				return true
			return false
		WeaponType.MINIGUN:
			if minigun_ammo > 0:
				minigun_ammo -= 1
				emit_current_ammo()
				return true
			return false
	return false

func emit_current_ammo() -> void:
	match current_weapon:
		WeaponType.PISTOL:
			ammo_changed.emit("9MM PISTOL", 999, 999)
		WeaponType.SHOTGUN:
			ammo_changed.emit("12G SHOTGUN", shotgun_ammo, shotgun_max_ammo)
		WeaponType.ASSAULT_RIFLE:
			ammo_changed.emit("ASSAULT RIFLE", rifle_ammo, rifle_max_ammo)
		WeaponType.FLAMETHROWER:
			ammo_changed.emit("FLAMETHROWER", flamethrower_fuel, flamethrower_max_fuel)
		WeaponType.MINIGUN:
			ammo_changed.emit("ROTARY MINIGUN", minigun_ammo, minigun_max_ammo)

func set_weapon(type: WeaponType) -> void:
	current_weapon = type
	emit_current_ammo()
	weapon_changed.emit(current_weapon)

func set_active_deployable(type: int) -> void:
	active_deployable_type = posmod(type, 3)
	active_deployable_changed.emit(active_deployable_type)

func grant_supply_drop() -> void:
	heal_player(50.0)
	shotgun_ammo = min(shotgun_max_ammo, shotgun_ammo + 32)
	rifle_ammo = min(rifle_max_ammo, rifle_ammo + 120)
	flamethrower_fuel = min(flamethrower_max_fuel, flamethrower_fuel + 150)
	minigun_ammo = min(minigun_max_ammo, minigun_ammo + 250)
	deployable_barbed_wire += 2
	deployable_claymores += 2
	deployable_turrets += 1
	emit_current_ammo()
	deployables_updated.emit(deployable_barbed_wire, deployable_claymores, deployable_turrets)
	play_sound("perk")

func play_sound(sound_name: String, pos = null) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sound"):
		audio_mgr.play_sound(sound_name, pos)
		return
	
	# Fallback audio effects synthesizer
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.bus = &"Master"
	
	# Generate quick synthesized sound wave
	var sample_rate: int = 22050
	var duration: float = 0.12
	var freq: float = 440.0
	
	match sound_name:
		"pistol":
			duration = 0.09
			freq = 280.0
		"shotgun":
			duration = 0.22
			freq = 150.0
		"rifle":
			duration = 0.07
			freq = 380.0
		"flame":
			duration = 0.14
			freq = 85.0
		"minigun_spin":
			duration = 0.25
			freq = 520.0
		"minigun_fire":
			duration = 0.05
			freq = 175.0
		"hit":
			duration = 0.08
			freq = 120.0
		"pickup", "pickup_ammo", "pickup_health":
			duration = 0.15
			freq = 660.0
		"keycard_chirp":
			duration = 0.22
			freq = 1400.0
		"explode":
			duration = 0.35
			freq = 80.0
		"mutant_step":
			duration = 0.25
			freq = 55.0
		"mutant_roar":
			duration = 0.75
			freq = 75.0
		"stomp_crash":
			duration = 0.55
			freq = 50.0
		"zombie_groan":
			duration = 0.30
			freq = 110.0
		"screamer":
			duration = 0.45
			freq = 880.0
		"electric_zap":
			duration = 0.20
			freq = 950.0
		"roll":
			duration = 0.16
			freq = 210.0
		"perk":
			duration = 0.42
			freq = 784.0
		"wave_clear":
			duration = 0.36
			freq = 587.33
		"wave_start":
			duration = 0.40
			freq = 110.0
		"boss_roar":
			duration = 0.85
			freq = 65.0
		"boss_slam":
			duration = 0.60
			freq = 50.0
		"boss_cleave":
			duration = 0.28
			freq = 240.0
		"boss_alarm":
			duration = 0.50
			freq = 620.0
		"rock_impact":
			duration = 0.38
			freq = 75.0
		"gate_slam":
			duration = 0.48
			freq = 95.0
		"radiation_tick":
			duration = 0.10
			freq = 1200.0
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	var frames: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(frames)
	
	for i in range(frames):
		var t = float(i) / float(sample_rate)
		var decay = 1.0 - (float(i) / float(frames))
		var val: float = 0.0
		
		if sound_name in ["explode", "hit", "boss_slam", "rock_impact", "gate_slam"]:
			# Heavy noise with punch
			var shock = (1.0 - t * 30.0) if t < 0.03 else 0.0
			val = tanh(shock * 1.5 + (randf() * 2.0 - 1.0) * decay * 1.2)
		elif sound_name in ["boss_roar", "mutant_roar", "zombie_groan"]:
			var low_rumble = (randf() * 2.0 - 1.0) * 0.7
			var pulse = 0.8 if fmod(t * 28.0, 1.0) < 0.2 else -0.2
			val = tanh((low_rumble + pulse) * decay * 1.4)
		else:
			# Broadband noise impulse with fast mechanical decay (zero cartoon sine waves)
			val = (randf() * 2.0 - 1.0) * pow(decay, 2.2) * 0.8
		
		# Convert -1.0..1.0 to 8-bit unsigned (0..255)
		var byte_val = int(clamp((val + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
	
	stream.data = data
	player.stream = stream
	player.volume_db = -8.0
	player.finished.connect(player.queue_free)
	player.play()

func collect_keycard(color: String) -> void:
	if not color in keycards_collected:
		keycards_collected.append(color)
	keycard_collected.emit(color)
	play_sound("keycard_chirp")

func has_keycard(color: String) -> bool:
	return color in keycards_collected
