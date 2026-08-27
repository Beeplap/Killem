extends Node

# Global state and signals for Outbreak Zombie Shooter
signal health_changed(current: float, max_val: float)
signal ammo_changed(weapon_name: String, current: int, max_val: int)
signal score_changed(score: int, kills: int)
signal wave_changed(wave: int)
signal player_died

var score: int = 0
var kills: int = 0
var current_wave: int = 1
var player_health: float = 100.0
var player_max_health: float = 100.0
var is_game_over: bool = false

# Weapons
enum WeaponType { PISTOL, SHOTGUN, ASSAULT_RIFLE }

var current_weapon: WeaponType = WeaponType.PISTOL
var shotgun_ammo: int = 24
var shotgun_max_ammo: int = 64
var rifle_ammo: int = 90
var rifle_max_ammo: int = 240

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
	current_weapon = WeaponType.PISTOL
	is_game_over = false

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
	shotgun_ammo = min(shotgun_max_ammo, shotgun_ammo + 12)
	rifle_ammo = min(rifle_max_ammo, rifle_ammo + 45)
	emit_current_ammo()

func has_ammo(type: WeaponType) -> bool:
	match type:
		WeaponType.PISTOL:
			return true
		WeaponType.SHOTGUN:
			return shotgun_ammo > 0
		WeaponType.ASSAULT_RIFLE:
			return rifle_ammo > 0
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
	return false

func emit_current_ammo() -> void:
	match current_weapon:
		WeaponType.PISTOL:
			ammo_changed.emit("9MM PISTOL", 999, 999)
		WeaponType.SHOTGUN:
			ammo_changed.emit("12G SHOTGUN", shotgun_ammo, shotgun_max_ammo)
		WeaponType.ASSAULT_RIFLE:
			ammo_changed.emit("ASSAULT RIFLE", rifle_ammo, rifle_max_ammo)

func set_weapon(type: WeaponType) -> void:
	current_weapon = type
	emit_current_ammo()

func play_sound(sound_name: String) -> void:
	# Simple audio effects synthesizer using procedural audio or audio bus
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
		"hit":
			duration = 0.08
			freq = 120.0
		"pickup":
			duration = 0.15
			freq = 660.0
		"explode":
			duration = 0.35
			freq = 80.0
		"zombie_groan":
			duration = 0.30
			freq = 110.0
	
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
		
		if sound_name == "explode" or sound_name == "hit":
			# Noise with decay
			val = (randf() * 2.0 - 1.0) * decay
		else:
			# Square / Sine wave with noise kick
			var phase = sin(t * freq * TAU)
			val = (phase * 0.7 + (randf() * 0.3)) * decay
		
		# Convert -1.0..1.0 to 8-bit unsigned (0..255)
		var byte_val = int(clamp((val + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
	
	stream.data = data
	player.stream = stream
	player.volume_db = -8.0
	player.finished.connect(player.queue_free)
	player.play()
